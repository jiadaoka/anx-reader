import 'dart:convert';

import 'package:anx_reader/enums/scene_orientation.dart';

/// ComfyUI「Save (API Format)」导出的工作流预设。
///
/// 动态值写在 JSON 字符串里，出图时替换；不在保存时解析或校验。
class SceneWorkflow {
  int? id;
  String name;
  String workflowJson;
  int portraitWidth;
  int portraitHeight;
  int landscapeWidth;
  int landscapeHeight;
  SceneOrientation orientation;
  bool isActive;
  DateTime createTime;
  DateTime updateTime;

  SceneWorkflow({
    this.id,
    required this.name,
    this.workflowJson = '',
    this.portraitWidth = defaultPortraitWidth,
    this.portraitHeight = defaultPortraitHeight,
    this.landscapeWidth = defaultLandscapeWidth,
    this.landscapeHeight = defaultLandscapeHeight,
    this.orientation = SceneOrientation.auto,
    this.isActive = false,
    DateTime? createTime,
    DateTime? updateTime,
  })  : createTime = createTime ?? DateTime.now(),
        updateTime = updateTime ?? DateTime.now();

  static const int defaultPortraitWidth = 832;
  static const int defaultPortraitHeight = 1216;
  static const int defaultLandscapeWidth = 1216;
  static const int defaultLandscapeHeight = 832;

  static const String promptPlaceholder = '%prompt%';
  static const String negativePlaceholder = '%negative_prompt%';
  static const String seedPlaceholder = '%seed%';
  static const String widthPlaceholder = '%width%';
  static const String heightPlaceholder = '%height%';

  static const List<String> placeholders = [
    promptPlaceholder,
    negativePlaceholder,
    seedPlaceholder,
    widthPlaceholder,
    heightPlaceholder,
  ];

  /// 方向为自动时，按提示词引擎给的 [sizeHint] 选一格；拿不准按竖屏。
  ({int width, int height}) resolutionFor(String? sizeHint) {
    final useLandscape = switch (orientation) {
      SceneOrientation.portrait => false,
      SceneOrientation.landscape => true,
      SceneOrientation.auto => sizeHint == 'landscape',
    };
    return useLandscape
        ? (width: landscapeWidth, height: landscapeHeight)
        : (width: portraitWidth, height: portraitHeight);
  }

  /// 把占位符替换成这一次的值，返回可直接提交给 ComfyUI 的 JSON 文本。
  ///
  /// [workflowJson] 不是 JSON 对象时抛 [FormatException]；出图前调用，
  /// 保存时不做这项校验。工作流里没出现的占位符保持原值。
  String buildPayload({
    required String prompt,
    String negative = '',
    required int seed,
    required int width,
    required int height,
  }) {
    final decoded = jsonDecode(workflowJson);
    if (decoded is! Map) {
      throw const FormatException('工作流 JSON 的顶层不是一个对象');
    }
    final values = <String, Object?>{
      promptPlaceholder: prompt,
      negativePlaceholder: negative,
      seedPlaceholder: seed,
      widthPlaceholder: width,
      heightPlaceholder: height,
    };
    final replaced = _replacePlaceholders(decoded, values);
    return jsonEncode(replaced);
  }

  Map<String, Object?> toRow() => {
        'name': name,
        'workflow_json': workflowJson,
        'portrait_width': portraitWidth,
        'portrait_height': portraitHeight,
        'landscape_width': landscapeWidth,
        'landscape_height': landscapeHeight,
        'orientation': orientation.code,
        'is_active': isActive ? 1 : 0,
        'create_time': createTime.toIso8601String(),
        'update_time': updateTime.toIso8601String(),
      };

  /// 任务快照：提交时定下这一套，之后编辑或切换工作流都不改写已提交的任务。
  Map<String, Object?> toSnapshot() => {
        'name': name,
        'workflowJson': workflowJson,
        'portraitWidth': portraitWidth,
        'portraitHeight': portraitHeight,
        'landscapeWidth': landscapeWidth,
        'landscapeHeight': landscapeHeight,
        'orientation': orientation.code,
      };

  factory SceneWorkflow.fromSnapshot(Map<String, dynamic> json) {
    return SceneWorkflow(
      name: json['name'] as String? ?? '',
      workflowJson: json['workflowJson'] as String? ?? '',
      portraitWidth:
          (json['portraitWidth'] as num?)?.toInt() ?? defaultPortraitWidth,
      portraitHeight:
          (json['portraitHeight'] as num?)?.toInt() ?? defaultPortraitHeight,
      landscapeWidth:
          (json['landscapeWidth'] as num?)?.toInt() ?? defaultLandscapeWidth,
      landscapeHeight:
          (json['landscapeHeight'] as num?)?.toInt() ?? defaultLandscapeHeight,
      orientation:
          SceneOrientation.fromCode(json['orientation'] as String? ?? ''),
    );
  }

  factory SceneWorkflow.fromRow(Map<String, dynamic> row) {
    return SceneWorkflow(
      id: (row['id'] as num?)?.toInt(),
      name: row['name'] as String? ?? '',
      workflowJson: row['workflow_json'] as String? ?? '',
      portraitWidth:
          (row['portrait_width'] as num?)?.toInt() ?? defaultPortraitWidth,
      portraitHeight:
          (row['portrait_height'] as num?)?.toInt() ?? defaultPortraitHeight,
      landscapeWidth:
          (row['landscape_width'] as num?)?.toInt() ?? defaultLandscapeWidth,
      landscapeHeight:
          (row['landscape_height'] as num?)?.toInt() ?? defaultLandscapeHeight,
      orientation:
          SceneOrientation.fromCode(row['orientation'] as String? ?? ''),
      isActive: (row['is_active'] as int? ?? 0) == 1,
      createTime:
          DateTime.tryParse(row['create_time'] as String? ?? '') ??
              DateTime.now(),
      updateTime:
          DateTime.tryParse(row['update_time'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

Object? _replacePlaceholders(Object? node, Map<String, Object?> values) {
  if (node is Map) {
    return node.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), _replacePlaceholders(value, values)),
    );
  }
  if (node is List) {
    return node
        .map<Object?>((value) => _replacePlaceholders(value, values))
        .toList(growable: false);
  }
  if (node is String) {
    final exact = values[node];
    if (exact != null) return exact;
    var result = node;
    values.forEach((placeholder, value) {
      if (value != null && result.contains(placeholder)) {
        result = result.replaceAll(placeholder, value.toString());
      }
    });
    return result;
  }
  return node;
}
