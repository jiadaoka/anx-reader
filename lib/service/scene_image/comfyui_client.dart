import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

enum SceneImageFailureCode {
  notConfigured,
  invalidWorkflow,
  unreachable,
  http,
  promptRejected,
  executionFailed,
  timeout,
  cancelled,
  writeFailed,
  unknown,
}

class SceneImageFailure implements Exception {
  SceneImageFailure(this.code, this.detail);

  final SceneImageFailureCode code;

  /// 原始技术细节，用于失败卡片与日志；界面另外给一句人话。
  final String detail;

  @override
  String toString() => '[$code] $detail';
}

class ComfyImageRef {
  const ComfyImageRef({
    required this.filename,
    required this.subfolder,
    required this.type,
  });

  final String filename;
  final String subfolder;
  final String type;
}

class SceneImageBytes {
  const SceneImageBytes({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// ComfyUI HTTP 接口的最小封装：提交、排队位置、取 history、下载图、取消。
class ComfyUiClient {
  ComfyUiClient({required String server, CancelToken? cancelToken})
      : _baseUrl = _normalizeBaseUrl(server),
        _cancelToken = cancelToken ?? CancelToken() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (status) => status != null && status < 500,
    ));
  }

  final String _baseUrl;
  final CancelToken _cancelToken;
  late final Dio _dio;

  static final Random _random = Random();

  String get baseUrl => _baseUrl;

  String get _clientId =>
      'jiaanx-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-'
      '${_random.nextInt(0xFFFF).toRadixString(16)}';

  static String _normalizeBaseUrl(String server) {
    var value = server.trim();
    if (value.isEmpty) {
      throw SceneImageFailure(
        SceneImageFailureCode.notConfigured,
        '还没有填写 ComfyUI 地址',
      );
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<void> testConnection() async {
    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/system_stats',
        cancelToken: _cancelToken,
      );
      if (response.statusCode == 200) return;
      throw SceneImageFailure(
        SceneImageFailureCode.http,
        'HTTP ${response.statusCode}',
      );
    } on SceneImageFailure {
      rethrow;
    } on DioException catch (e) {
      throw _wrapDio(e);
    }
  }

  /// 提交工作流，返回 ComfyUI 的 prompt_id。
  Future<String> submitPrompt(String payloadJson) async {
    final Object? payload;
    try {
      payload = jsonDecode(payloadJson);
    } on FormatException catch (e) {
      throw SceneImageFailure(
        SceneImageFailureCode.invalidWorkflow,
        '工作流 JSON 无法解析：${e.message}',
      );
    }
    if (payload is! Map) {
      throw SceneImageFailure(
        SceneImageFailureCode.invalidWorkflow,
        '工作流 JSON 的顶层不是一个对象',
      );
    }

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/prompt',
        data: {
          'prompt': payload,
          'client_id': _clientId,
        },
        cancelToken: _cancelToken,
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        final promptId = data['prompt_id']?.toString() ?? '';
        if (promptId.isNotEmpty) return promptId;
      }
      throw SceneImageFailure(
        SceneImageFailureCode.promptRejected,
        _describePromptRejection(data, response.statusCode),
      );
    } on SceneImageFailure {
      rethrow;
    } on DioException catch (e) {
      throw _wrapDio(e);
    }
  }

  /// 排队位置：前面还有几个任务。执行中为 0，查不到为 null。
  Future<int?> queuePosition(String promptId) async {
    try {
      final queue = await _fetchQueue();
      if (queue == null) return null;
      if (queue.runningIds.contains(promptId)) return 0;
      final index = queue.pendingIds.indexOf(promptId);
      if (index < 0) return null;
      return queue.runningIds.length + index;
    } on SceneImageFailure {
      rethrow;
    } on DioException catch (e) {
      throw _wrapDio(e);
    }
  }

  /// 轮询 history 直到拿到图片。每 5 秒回传一次排队位置。
  Future<ComfyImageRef> waitForImage(
    String promptId, {
    Duration timeout = const Duration(minutes: 5),
    void Function(int? position)? onQueuePosition,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var lastPositionCheck = DateTime.fromMillisecondsSinceEpoch(0);

    while (DateTime.now().isBefore(deadline)) {
      _throwIfCancelled();

      if (onQueuePosition != null &&
          DateTime.now().difference(lastPositionCheck) >
              const Duration(seconds: 5)) {
        lastPositionCheck = DateTime.now();
        try {
          onQueuePosition(await queuePosition(promptId));
        } on SceneImageFailure {
          // 排队位置是锦上添花，查不到不影响出图。
        }
      }

      final entry = await _fetchHistoryEntry(promptId);
      if (entry != null) {
        final failure = _executionFailure(entry);
        if (failure != null) throw failure;

        final image = _firstOutputImage(entry);
        if (image != null) return image;

        final status = entry['status'];
        if (status is Map && status['completed'] == true) {
          throw SceneImageFailure(
            SceneImageFailureCode.executionFailed,
            'ComfyUI 执行完成，但输出里没有图片',
          );
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    throw SceneImageFailure(
      SceneImageFailureCode.timeout,
      '等待 ComfyUI 出图超时（${timeout.inMinutes} 分钟）',
    );
  }

  Future<SceneImageBytes> downloadImage(ComfyImageRef ref) async {
    try {
      final response = await _dio.get<List<int>>(
        '$_baseUrl/view',
        queryParameters: {
          'filename': ref.filename,
          'subfolder': ref.subfolder,
          'type': ref.type,
        },
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _cancelToken,
      );
      final bytes = response.data;
      if (response.statusCode != 200 || bytes == null || bytes.isEmpty) {
        throw SceneImageFailure(
          SceneImageFailureCode.http,
          '取图失败：HTTP ${response.statusCode}',
        );
      }
      final contentType = response.headers.value('content-type') ?? 'image/png';
      return SceneImageBytes(
        bytes: Uint8List.fromList(bytes),
        mimeType: contentType.split(';').first.trim(),
      );
    } on SceneImageFailure {
      rethrow;
    } on DioException catch (e) {
      throw _wrapDio(e);
    }
  }

  /// 排队中从队列删除，执行中发中断；已经结束的任务不做任何事。
  Future<void> cancelPrompt(String promptId) async {
    final queue = await _fetchQueue();
    if (queue == null) return;
    if (queue.runningIds.contains(promptId)) {
      await _dio.post<dynamic>(
        '$_baseUrl/interrupt',
        data: {'prompt_id': promptId},
        cancelToken: _cancelToken,
      );
      return;
    }
    if (queue.pendingIds.contains(promptId)) {
      await _dio.post<dynamic>(
        '$_baseUrl/queue',
        data: {
          'delete': [promptId],
        },
        cancelToken: _cancelToken,
      );
    }
  }

  void cancelLocal() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel('cancelled by user');
  }

  Future<_QueueSnapshot?> _fetchQueue() async {
    final response = await _dio.get<dynamic>(
      '$_baseUrl/queue',
      cancelToken: _cancelToken,
    );
    final data = response.data;
    if (data is! Map) return null;
    return _QueueSnapshot(
      runningIds: _queueIds(data['queue_running']),
      pendingIds: _queueIds(data['queue_pending']),
    );
  }

  List<String> _queueIds(Object? raw) {
    if (raw is! List) return const [];
    final ids = <String>[];
    for (final item in raw) {
      if (item is List && item.length > 1) {
        final id = item[1]?.toString() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  Future<Map<String, dynamic>?> _fetchHistoryEntry(String promptId) async {
    final response = await _dio.get<dynamic>(
      '$_baseUrl/history/$promptId',
      cancelToken: _cancelToken,
    );
    final data = response.data;
    if (data is! Map) return null;
    final entry = data[promptId];
    if (entry is! Map) return null;
    return Map<String, dynamic>.from(entry);
  }

  SceneImageFailure? _executionFailure(Map<String, dynamic> entry) {
    final status = entry['status'];
    if (status is! Map) return null;
    final statusStr = status['status_str']?.toString() ?? '';
    if (statusStr != 'error') return null;

    final messages = status['messages'];
    if (messages is List) {
      for (final message in messages) {
        if (message is! List || message.length < 2) continue;
        if (message[0] != 'execution_error') continue;
        final payload = message[1];
        if (payload is! Map) continue;
        final nodeId = payload['node_id']?.toString() ?? '';
        final nodeType = payload['node_type']?.toString() ?? '';
        final exceptionMessage =
            payload['exception_message']?.toString().trim() ?? '';
        final parts = <String>[];
        if (nodeId.isNotEmpty) {
          parts.add('节点 $nodeId${nodeType.isEmpty ? '' : '（$nodeType）'}');
        }
        if (exceptionMessage.isNotEmpty) parts.add(exceptionMessage);
        return SceneImageFailure(
          SceneImageFailureCode.executionFailed,
          parts.isEmpty ? 'ComfyUI 执行失败' : parts.join('：'),
        );
      }
    }
    return SceneImageFailure(
      SceneImageFailureCode.executionFailed,
      'ComfyUI 执行失败',
    );
  }

  ComfyImageRef? _firstOutputImage(Map<String, dynamic> entry) {
    final outputs = entry['outputs'];
    if (outputs is! Map) return null;
    for (final nodeOutput in outputs.values) {
      if (nodeOutput is! Map) continue;
      final images = nodeOutput['images'];
      if (images is! List) continue;
      for (final image in images) {
        if (image is! Map) continue;
        final filename = image['filename']?.toString() ?? '';
        if (filename.isEmpty) continue;
        return ComfyImageRef(
          filename: filename,
          subfolder: image['subfolder']?.toString() ?? '',
          type: image['type']?.toString() ?? 'output',
        );
      }
    }
    return null;
  }

  String _describePromptRejection(Object? data, int? statusCode) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final message = error['message'] ?? error['details'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      } else if (error != null && error.toString().trim().isNotEmpty) {
        return error.toString();
      }

      final nodeErrors = data['node_errors'];
      if (nodeErrors is Map && nodeErrors.isNotEmpty) {
        final parts = <String>[];
        nodeErrors.forEach((nodeId, value) {
          if (value is! Map) return;
          final classType = value['class_type']?.toString() ?? '';
          final errors = value['errors'];
          final details = <String>[];
          if (errors is List) {
            for (final item in errors) {
              if (item is Map) {
                details.add(
                  (item['message'] ?? item['details'] ?? item).toString(),
                );
              } else {
                details.add(item.toString());
              }
            }
          }
          parts.add(
            '节点 $nodeId${classType.isEmpty ? '' : '（$classType）'}'
            '${details.isEmpty ? '' : '：${details.join('；')}'}',
          );
        });
        if (parts.isNotEmpty) return parts.join('\n');
      }
    }
    return 'ComfyUI 拒绝了这次提交（HTTP $statusCode）';
  }

  void _throwIfCancelled() {
    if (_cancelToken.isCancelled) {
      throw SceneImageFailure(
        SceneImageFailureCode.cancelled,
        '任务已取消',
      );
    }
  }

  SceneImageFailure _wrapDio(DioException e) {
    if (CancelToken.isCancel(e)) {
      return SceneImageFailure(SceneImageFailureCode.cancelled, '任务已取消');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return SceneImageFailure(
        SceneImageFailureCode.unreachable,
        '连不上 ComfyUI：${e.message ?? e.type.name}',
      );
    }
    final status = e.response?.statusCode;
    if (status != null) {
      final body = e.response?.data?.toString() ?? '';
      final brief = body.length > 300 ? '${body.substring(0, 300)}…' : body;
      return SceneImageFailure(
        SceneImageFailureCode.http,
        'ComfyUI 返回 HTTP $status${brief.isEmpty ? '' : '：$brief'}',
      );
    }
    return SceneImageFailure(
      SceneImageFailureCode.unknown,
      e.message ?? e.toString(),
    );
  }
}

class _QueueSnapshot {
  const _QueueSnapshot({required this.runningIds, required this.pendingIds});

  final List<String> runningIds;
  final List<String> pendingIds;
}
