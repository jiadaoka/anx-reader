import 'dart:async';
import 'dart:math';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/scene_task.dart';
import 'package:anx_reader/dao/scene_workflow.dart';
import 'package:anx_reader/enums/scene_illustration.dart';
import 'package:anx_reader/enums/scene_task_status.dart';
import 'package:anx_reader/enums/scene_task_type.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:anx_reader/providers/scene_illustrations.dart';
import 'package:anx_reader/service/scene_image/character_resolver.dart';
import 'package:anx_reader/service/scene_image/comfyui_client.dart';
import 'package:anx_reader/service/scene_image/image_store.dart';
import 'package:anx_reader/service/scene_image/prompt_engine.dart';
import 'package:anx_reader/service/scene_image/scene_context.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sceneTaskStoreProvider =
    Provider<SceneTaskStore>((ref) => SceneTaskStore.instance);

/// 任务内存态 + 落库 + 执行。跨书保存在同一张表里，界面按 bookId 过滤。
///
/// 提示词任务串行执行（AI 服务同一时间只允许一条请求）；生图任务提交给
/// ComfyUI 后各自轮询，它的队列负责排序。
class SceneTaskStore extends ChangeNotifier {
  SceneTaskStore._();

  static final SceneTaskStore instance = SceneTaskStore._();

  final Map<String, SceneTask> _tasks = {};
  final List<String> _promptQueue = [];
  final Map<String, CancelToken> _imageTokens = {};
  final Map<String, ComfyUiClient> _imageClients = {};
  final Map<String, String> _comfyPromptIds = {};
  final StreamController<SceneTask> _taskCompletedController =
      StreamController<SceneTask>.broadcast();
  final Random _random = Random();

  bool _loaded = false;
  bool _runningPrompt = false;

  bool get isLoaded => _loaded;

  /// 提示词或生图完成时发一条事件，阅读页据此弹「画好了 · 查看」。
  Stream<SceneTask> get taskCompleted => _taskCompletedController.stream;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final tasks = await sceneTaskDao.selectAll();
      for (final task in tasks) {
        if (task.status == SceneTaskStatus.queued ||
            task.status == SceneTaskStatus.running) {
          // 重启后接不上原来的请求，留着转圈是假象。
          task.status = SceneTaskStatus.failed;
          task.failureReason = '上次执行没有完成（应用已重启），请重试';
          task.updateTime = DateTime.now();
          await sceneTaskDao.save(task);
        }
        _tasks[task.id] = task;
      }
    } catch (e) {
      AnxLog.warning('SceneImage: load tasks failed: $e');
    }
    notifyListeners();
  }

  List<SceneTask> tasksForBook(int bookId) {
    final tasks = _tasks.values.where((t) => t.bookId == bookId).toList();
    tasks.sort((a, b) => b.createTime.compareTo(a.createTime));
    return tasks;
  }

  SceneTask? taskById(String id) => _tasks[id];

  bool hasUnfinishedTasks(int bookId) => _tasks.values.any(
        (t) => t.bookId == bookId && t.status.isActive,
      );

  SceneTaskHistoryEntry? historyEntry(String taskId, String entryId) {
    final task = _tasks[taskId];
    if (task == null) return null;
    for (final entry in task.history) {
      if (entry.id == entryId) return entry;
    }
    return null;
  }

  Future<SceneTask> createPromptTask({
    required int bookId,
    required String bookTitle,
    required String excerpt,
    required String chapter,
    required String cfi,
    required double progress,
    required String supplement,
    required String contextBefore,
    required String contextAfter,
    required String sourceSectionHref,
    required int sourceSectionIndex,
    required int sourceParagraphIndex,
    required String sourceParagraphText,
  }) async {
    await ensureLoaded();

    final context = trimSceneContext(
      excerpt: excerpt,
      before: contextBefore,
      after: contextAfter,
    );
    final contextComplete = context.complete &&
        contextBefore.trim().isNotEmpty &&
        contextAfter.trim().isNotEmpty;
    final task = SceneTask(
      id: newSceneTaskId(),
      bookId: bookId,
      bookTitle: bookTitle,
      type: SceneTaskType.prompt,
      excerpt: excerpt,
      chapter: chapter,
      cfi: cfi,
      progress: progress,
      supplement: supplement.trim(),
      contextBefore: context.before,
      contextAfter: context.after,
      contextComplete: contextComplete,
      sourceSectionHref: sourceSectionHref,
      sourceSectionIndex: sourceSectionIndex,
      sourceParagraphIndex: sourceParagraphIndex,
      sourceParagraphText: sourceParagraphText,
    );

    _tasks[task.id] = task;
    await _persist(task);
    Prefs().setSceneTaskUnread(bookId, true);
    notifyListeners();

    _promptQueue.add(task.id);
    unawaited(_pumpPromptQueue());
    return task;
  }

  Future<void> retryTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.isPromptTask) {
      if (task.status.isActive) return;
      task.status = SceneTaskStatus.queued;
      task.failureReason = '';
      task.updateTime = DateTime.now();
      await _persist(task);
      notifyListeners();
      _promptQueue.add(task.id);
      unawaited(_pumpPromptQueue());
      return;
    }

    if (task.status.isActive) return;
    task.status = SceneTaskStatus.queued;
    task.failureReason = '';
    task.queueAhead = null;
    task.updateTime = DateTime.now();
    await _persist(task);
    notifyListeners();
    unawaited(_runImageTask(task));
  }

  Future<void> editPrompt(String taskId, String newPrompt) async {
    final task = _tasks[taskId];
    if (task == null || !task.isPromptTask) return;
    final text = newPrompt.trim();
    if (text.isEmpty || text == task.prompt) return;
    task.prompt = text;
    task.negative = '';
    task.status = SceneTaskStatus.completed;
    task.failureReason = '';
    task.addHistory(SceneTaskHistoryEntry(
      id: newSceneTaskId(),
      status: SceneTaskStatus.completed,
      prompt: text,
      createTime: DateTime.now(),
    ));
    task.updateTime = DateTime.now();
    await _persist(task);
    notifyListeners();
  }

  /// 从提示词任务发起生图。同一提示词已有生图任务时复用它，结果进历史。
  ///
  /// 没配地址或没有工作流时返回 null，由界面给出可读原因。
  Future<SceneTask?> startImageTask(String promptTaskId) async {
    final promptTask = _tasks[promptTaskId];
    if (promptTask == null || !promptTask.isPromptTask) return null;
    if (promptTask.prompt.trim().isEmpty) return null;
    if (Prefs().sceneComfyServer.trim().isEmpty) return null;

    final workflow = await sceneWorkflowDao.selectActive();
    if (workflow == null) return null;

    SceneTask? task;
    for (final candidate in _tasks.values) {
      if (candidate.isImageTask &&
          candidate.promptTaskId == promptTask.id &&
          candidate.prompt == promptTask.prompt) {
        task = candidate;
        break;
      }
    }

    if (task == null) {
      task = SceneTask(
        id: newSceneTaskId(),
        bookId: promptTask.bookId,
        bookTitle: promptTask.bookTitle,
        type: SceneTaskType.image,
        excerpt: promptTask.excerpt,
        chapter: promptTask.chapter,
        cfi: promptTask.cfi,
        progress: promptTask.progress,
        prompt: promptTask.prompt,
        negative: promptTask.negative,
        supplement: promptTask.supplement,
        contextBefore: promptTask.contextBefore,
        contextAfter: promptTask.contextAfter,
        contextComplete: promptTask.contextComplete,
        sourceSectionHref: promptTask.sourceSectionHref,
        sourceSectionIndex: promptTask.sourceSectionIndex,
        sourceParagraphIndex: promptTask.sourceParagraphIndex,
        sourceParagraphText: promptTask.sourceParagraphText,
        sizeHint: promptTask.sizeHint,
        promptTaskId: promptTask.id,
        characterRefs: List<SceneTaskCharacterRef>.from(
          promptTask.characterRefs,
        ),
      );
      _tasks[task.id] = task;
    }

    task.workflowId = workflow.id;
    task.workflowName = workflow.name;
    task.workflowSnapshot = workflow;
    task.status = SceneTaskStatus.queued;
    task.failureReason = '';
    task.queueAhead = null;
    task.updateTime = DateTime.now();

    await _persist(task);
    Prefs().setSceneTaskUnread(task.bookId, true);
    notifyListeners();
    unawaited(_runImageTask(task));
    return task;
  }

  Future<void> cancelTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || !task.status.isActive) return;

    if (task.isPromptTask) {
      _promptQueue.remove(taskId);
    } else {
      final client = _imageClients[taskId];
      final comfyPromptId = _comfyPromptIds[taskId];
      if (client != null && comfyPromptId != null) {
        try {
          await client.cancelPrompt(comfyPromptId);
        } catch (e) {
          AnxLog.warning('SceneImage: cancel prompt failed: $e');
        }
      }
      _imageTokens.remove(taskId)?.cancel('cancelled');
    }

    task.status = SceneTaskStatus.cancelled;
    task.failureReason = '';
    task.queueAhead = null;
    task.updateTime = DateTime.now();
    await _persist(task);
    notifyListeners();
  }

  /// 只清失败与已取消；完成的任务留着看图。
  Future<void> cleanupFinished(int bookId) async {
    final finishedTasks = _tasks.values
        .where(
          (t) =>
              t.bookId == bookId &&
              (t.status == SceneTaskStatus.failed ||
                  t.status == SceneTaskStatus.cancelled),
        )
        .toList(growable: false);
    for (final task in finishedTasks) {
      for (final entry in task.history) {
        if (entry.imagePath.isNotEmpty) {
          await deleteSceneImage(entry.imagePath);
        }
      }
      if (task.imagePath.isNotEmpty) {
        await deleteSceneImage(task.imagePath);
      }
      _tasks.remove(task.id);
    }
    await sceneTaskDao.deleteFinishedByBook(bookId);
    notifyListeners();
  }

  void markBookRead(int bookId) {
    if (Prefs().sceneTaskUnread(bookId)) {
      Prefs().setSceneTaskUnread(bookId, false);
    }
  }

  Future<void> _pumpPromptQueue() async {
    if (_runningPrompt) return;
    _runningPrompt = true;
    try {
      while (_promptQueue.isNotEmpty) {
        final id = _promptQueue.removeAt(0);
        final task = _tasks[id];
        if (task == null || task.status != SceneTaskStatus.queued) continue;
        await _runPromptTask(task);
      }
    } finally {
      _runningPrompt = false;
    }
  }

  Future<void> _runPromptTask(SceneTask task) async {
    task.status = SceneTaskStatus.running;
    task.failureReason = '';
    task.updateTime = DateTime.now();
    await _persist(task);
    notifyListeners();

    try {
      final refs = await resolveSceneCharacters(
        bookId: task.bookId,
        excerpt: task.excerpt,
        contextBefore: task.contextBefore,
        contextAfter: task.contextAfter,
      );
      task.characterRefs = refs;

      final result = await generateScenePrompt(
        excerpt: task.excerpt,
        supplement: task.supplement,
        contextBefore: task.contextBefore,
        contextAfter: task.contextAfter,
        contextComplete: task.contextComplete,
        refs: refs,
      );

      if (task.status == SceneTaskStatus.cancelled) {
        await _persist(task);
        notifyListeners();
        return;
      }

      task.prompt = result.prompt;
      task.negative = result.negative;
      task.sizeHint = result.sizeHint;
      task.status = SceneTaskStatus.completed;
      task.addHistory(SceneTaskHistoryEntry(
        id: newSceneTaskId(),
        status: SceneTaskStatus.completed,
        prompt: result.prompt,
        negative: result.negative,
        createTime: DateTime.now(),
      ));
      _taskCompletedController.add(task);
    } on ScenePromptException catch (e) {
      if (task.status != SceneTaskStatus.cancelled) {
        task.status = SceneTaskStatus.failed;
        task.failureReason = e.message;
      }
    } catch (e) {
      if (task.status != SceneTaskStatus.cancelled) {
        task.status = SceneTaskStatus.failed;
        task.failureReason = '生成提示词失败：$e';
      }
    }

    task.updateTime = DateTime.now();
    await _persist(task);
    notifyListeners();
  }

  Future<void> _runImageTask(SceneTask task) async {
    if (task.status == SceneTaskStatus.cancelled) return;

    final snapshot = task.workflowSnapshot;
    final server = Prefs().sceneComfyServer.trim();
    if (snapshot == null || server.isEmpty) {
      task.status = SceneTaskStatus.failed;
      task.failureReason = snapshot == null
          ? '还没有可用的工作流，请到 设置 → 剧情配图 里新建一套'
          : '还没有填写 ComfyUI 地址，请到 设置 → 剧情配图 里填写';
      task.updateTime = DateTime.now();
      await _persist(task);
      notifyListeners();
      return;
    }

    final size = snapshot.resolutionFor(task.sizeHint);
    final seed = _random.nextInt(0x7FFFFFFF);
    task.width = size.width;
    task.height = size.height;
    task.seed = seed;
    task.status = SceneTaskStatus.running;
    task.failureReason = '';
    task.queueAhead = null;
    task.updateTime = DateTime.now();
    await _persist(task);
    notifyListeners();

    if (task.status == SceneTaskStatus.cancelled) return;

    final token = CancelToken();
    _imageTokens[task.id] = token;

    try {
      final client = ComfyUiClient(server: server, cancelToken: token);
      _imageClients[task.id] = client;
      final payload = snapshot.buildPayload(
        prompt: task.prompt,
        negative: task.negative,
        seed: seed,
        width: size.width,
        height: size.height,
      );
      final comfyPromptId = await client.submitPrompt(payload);
      _comfyPromptIds[task.id] = comfyPromptId;

      if (task.status == SceneTaskStatus.cancelled) {
        try {
          await client.cancelPrompt(comfyPromptId);
        } catch (_) {
          // 服务端已经结束或已断开，本地状态仍然是已取消。
        }
        return;
      }

      final imageRef = await client.waitForImage(
        comfyPromptId,
        onQueuePosition: (position) {
          task.queueAhead = position;
          notifyListeners();
        },
      );
      final image = await client.downloadImage(imageRef);

      if (task.status == SceneTaskStatus.cancelled) {
        return;
      }

      final relativePath = await saveSceneImage(
        bookId: task.bookId,
        taskId: task.id,
        bytes: image.bytes,
        mimeType: image.mimeType,
      );
      task.imagePath = relativePath;
      task.status = SceneTaskStatus.completed;
      task.failureReason = '';
      task.queueAhead = null;
      final entry = SceneTaskHistoryEntry(
        id: newSceneTaskId(),
        status: SceneTaskStatus.completed,
        prompt: task.prompt,
        negative: task.negative,
        imagePath: relativePath,
        width: size.width,
        height: size.height,
        seed: seed,
        workflowName: snapshot.name,
        createTime: DateTime.now(),
      );
      task.addHistory(entry);
      Prefs().setSceneTaskUnread(task.bookId, true);
      await _autoInsertIllustration(task, entry);
      _taskCompletedController.add(task);
    } on SceneImageFailure catch (e) {
      if (task.status != SceneTaskStatus.cancelled) {
        task.status = SceneTaskStatus.failed;
        task.failureReason = _readableFailure(e);
      }
    } on FormatException catch (e) {
      if (task.status != SceneTaskStatus.cancelled) {
        task.status = SceneTaskStatus.failed;
        task.failureReason = '工作流 JSON 有问题：${e.message}';
      }
    } catch (e) {
      if (task.status != SceneTaskStatus.cancelled) {
        task.status = SceneTaskStatus.failed;
        task.failureReason = '出图失败：$e';
      }
    } finally {
      _imageTokens.remove(task.id);
      _imageClients.remove(task.id);
      _comfyPromptIds.remove(task.id);
      task.queueAhead = null;
      task.updateTime = DateTime.now();
      await _persist(task);
      notifyListeners();
    }
  }

  String _readableFailure(SceneImageFailure failure) {
    switch (failure.code) {
      case SceneImageFailureCode.notConfigured:
        return '还没有配置 ComfyUI 地址';
      case SceneImageFailureCode.invalidWorkflow:
        return '工作流 JSON 有问题：${failure.detail}';
      case SceneImageFailureCode.unreachable:
        return failure.detail;
      case SceneImageFailureCode.http:
        return failure.detail;
      case SceneImageFailureCode.promptRejected:
        return 'ComfyUI 拒绝了这次提交：${failure.detail}';
      case SceneImageFailureCode.executionFailed:
        return failure.detail;
      case SceneImageFailureCode.timeout:
        return failure.detail;
      case SceneImageFailureCode.cancelled:
        return '已取消';
      case SceneImageFailureCode.writeFailed:
        return '图片保存失败：${failure.detail}';
      case SceneImageFailureCode.unknown:
        return '出图失败：${failure.detail}';
    }
  }

  /// 生图成功时按来源段落到正文；只处理这一次成功，不扫描历史任务。
  Future<void> _autoInsertIllustration(
    SceneTask task,
    SceneTaskHistoryEntry entry,
  ) async {
    if (!Prefs().sceneImageEnabled || !Prefs().sceneAutoInsertEnabled) return;
    if (task.sourceSectionHref.isEmpty || task.sourceParagraphText.isEmpty) {
      return;
    }
    try {
      await SceneIllustrationStore.instance.insertFromTask(
        task: task,
        entry: entry,
        mode: SceneIllustrationMode.auto,
      );
    } catch (e) {
      AnxLog.warning('SceneImage: auto insert illustration failed: $e');
    }
  }

  Future<void> _persist(SceneTask task) async {
    try {
      await sceneTaskDao.save(task);
    } catch (e) {
      AnxLog.warning('SceneImage: save task ${task.id} failed: $e');
    }
  }
}
