import 'package:anx_reader/enums/scene_task_status.dart';
import 'package:anx_reader/enums/scene_task_type.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:flutter/material.dart';

String sceneTaskClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String sceneTaskDateTime(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '$month-$day ${sceneTaskClock(time)}';
}

String sceneTaskSourceText(BuildContext context, SceneTask task) {
  final l10n = L10n.of(context);
  final chapter = task.chapter.trim().isEmpty
      ? l10n.sceneTaskNoChapter
      : task.chapter.trim();
  final progress = (task.progress * 100).round();
  return l10n.sceneTaskChapterProgress(chapter, progress);
}

String sceneTaskStatusText(BuildContext context, SceneTaskStatus status) {
  final l10n = L10n.of(context);
  switch (status) {
    case SceneTaskStatus.queued:
      return l10n.sceneTaskStatusQueued;
    case SceneTaskStatus.running:
      return l10n.sceneTaskStatusRunning;
    case SceneTaskStatus.completed:
      return l10n.sceneTaskStatusCompleted;
    case SceneTaskStatus.failed:
      return l10n.sceneTaskStatusFailed;
    case SceneTaskStatus.cancelled:
      return l10n.sceneTaskStatusCancelled;
  }
}

Color sceneTaskStatusColor(BuildContext context, SceneTaskStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case SceneTaskStatus.queued:
    case SceneTaskStatus.running:
      return scheme.primary;
    case SceneTaskStatus.completed:
      return scheme.primary;
    case SceneTaskStatus.failed:
      return scheme.error;
    case SceneTaskStatus.cancelled:
      return scheme.onSurfaceVariant;
  }
}

String? sceneTaskQueuedText(BuildContext context, SceneTask task) {
  if (!task.status.isActive) return null;
  final l10n = L10n.of(context);
  if (task.isImageTask) {
    final ahead = task.queueAhead;
    if (task.status == SceneTaskStatus.queued) {
      return ahead != null
          ? '${l10n.sceneTaskStatusQueued} · '
              '${l10n.sceneTaskQueueAhead(ahead)}'
          : l10n.sceneTaskImageQueued;
    }
    return ahead != null && ahead > 0
        ? l10n.sceneTaskQueueAhead(ahead)
        : l10n.sceneTaskStatusRunning;
  }
  return task.status == SceneTaskStatus.queued
      ? l10n.sceneTaskStatusQueued
      : l10n.sceneTaskStatusRunning;
}

extension SceneTaskHistoryView on SceneTask {
  List<SceneTaskHistoryEntry> get promptVersions {
    if (!isPromptTask) return const [];
    return history.where((e) => e.prompt.trim().isNotEmpty).toList();
  }

  List<SceneTaskHistoryEntry> get imageResults {
    if (!isImageTask) return const [];
    return history.where((e) => e.imagePath.isNotEmpty).toList();
  }

  bool get isPromptType => type == SceneTaskType.prompt;
}
