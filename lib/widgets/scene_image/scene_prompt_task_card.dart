import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/scene_task_status.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:anx_reader/providers/scene_tasks.dart';
import 'package:anx_reader/providers/scene_workflows.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/scene_image/scene_image_common.dart';
import 'package:anx_reader/widgets/scene_image/scene_task_card_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 提示词任务卡：主体只有提示词，明细收进信息块。
class ScenePromptTaskCard extends ConsumerStatefulWidget {
  const ScenePromptTaskCard({super.key, required this.task});

  final SceneTask task;

  @override
  ConsumerState<ScenePromptTaskCard> createState() =>
      _ScenePromptTaskCardState();
}

class _ScenePromptTaskCardState extends ConsumerState<ScenePromptTaskCard> {
  bool _expanded = false;
  int _historyIndex = 0;

  SceneTask get _task => widget.task;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final versions = _task.promptVersions;
    final index = versions.isEmpty
        ? 0
        : _historyIndex.clamp(0, versions.length - 1).toInt();
    final entry = versions.isEmpty ? null : versions[index];
    final active = _task.status.isActive;
    final completed = _task.status == SceneTaskStatus.completed;
    final store = ref.read(sceneTaskStoreProvider);
    final activeWorkflow = ref.watch(activeSceneWorkflowProvider).valueOrNull;
    final canGenerate = completed &&
        _task.prompt.trim().isNotEmpty &&
        Prefs().sceneComfyServer.trim().isNotEmpty &&
        activeWorkflow != null;

    final mainChildren = <Widget>[];
    if (active) {
      mainChildren.add(const SceneTaskPromptSkeleton());
      mainChildren.add(const SizedBox(height: 8));
      mainChildren.add(
        SceneTaskBusyRow(
          text: sceneTaskQueuedText(context, _task) ??
              l10n.sceneTaskStatusRunning,
        ),
      );
    } else {
      if (_task.status == SceneTaskStatus.failed) {
        mainChildren.add(
          SceneTaskErrorRow(
            message: _task.failureReason.trim().isEmpty
                ? l10n.sceneTaskStatusFailed
                : _task.failureReason,
          ),
        );
      } else if (_task.status == SceneTaskStatus.cancelled) {
        mainChildren.add(
          Text(
            l10n.sceneTaskStatusCancelled,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      }

      final promptText = entry?.prompt ?? _task.prompt;
      final showPrompt = versions.isNotEmpty ||
          promptText.trim().isNotEmpty ||
          completed;
      if (showPrompt) {
        if (mainChildren.isNotEmpty) mainChildren.add(const SizedBox(height: 8));
        mainChildren.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              promptText.trim().isEmpty
                  ? l10n.sceneTaskPromptEmpty
                  : promptText,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        );
      }

      if (versions.isNotEmpty) {
        mainChildren.add(
          SceneTaskVersionRow(
            index: index + 1,
            total: versions.length,
            time: sceneTaskClock(versions[index].createTime),
            onPrevious: index < versions.length - 1
                ? () => setState(() => _historyIndex = index + 1)
                : null,
            onNext:
                index > 0 ? () => setState(() => _historyIndex = index - 1) : null,
          ),
        );
      }
    }

    return SceneTaskCardFrame(
      isImageTask: false,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mainChildren,
      ),
      info: _info(context),
      footer: _footer(context, store: store, canGenerate: canGenerate),
    );
  }

  Widget _info(BuildContext context) {
    final l10n = L10n.of(context);
    final sections = <Widget>[
      SceneTaskInfoSection(
        title: l10n.sceneTaskBasicInfoLabel,
        children: [
          SceneTaskInfoRow(
            label: l10n.sceneTaskTaskIdLabel,
            value: _task.id,
            mono: true,
          ),
          if (_task.supplement.trim().isNotEmpty)
            SceneTaskInfoRow(
              label: l10n.sceneTaskSupplementLabel,
              value: _task.supplement,
            ),
          SceneTaskInfoRow(
            label: l10n.sceneTaskSourceLabel,
            value: sceneTaskSourceText(context, _task),
          ),
          SceneTaskInfoRow(
            label: l10n.sceneTaskCreateTimeLabel,
            value: sceneTaskDateTime(_task.createTime),
          ),
        ],
      ),
    ];

    final contextRows = <Widget>[
      if (_task.excerpt.trim().isNotEmpty)
        SceneTaskInfoRow(
          label: l10n.sceneTaskExcerptLabel,
          value: _task.excerpt,
          maxLines: 5,
        ),
      if (_task.contextBefore.trim().isNotEmpty)
        SceneTaskInfoRow(
          label: l10n.sceneTaskContextBefore,
          value: _task.contextBefore,
        ),
      if (_task.contextAfter.trim().isNotEmpty)
        SceneTaskInfoRow(
          label: l10n.sceneTaskContextAfter,
          value: _task.contextAfter,
        ),
    ];
    if (contextRows.isNotEmpty) {
      sections.add(
        SceneTaskInfoSection(
          title: l10n.sceneTaskContextLabel,
          children: contextRows,
        ),
      );
    }

    if (_task.characterRefs.isNotEmpty) {
      sections.add(
        SceneTaskInfoSection(
          title: l10n.sceneTaskRefsLabel,
          children: [
            for (final ref in _task.characterRefs)
              SceneTaskRefRow(name: ref.name, keywords: ref.keywords),
          ],
        ),
      );
    }

    return SceneTaskInfoBlock(sections: sections);
  }

  Widget _footer(
    BuildContext context, {
    required SceneTaskStore store,
    required bool canGenerate,
  }) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_task.status == SceneTaskStatus.completed && !canGenerate)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.sceneTaskImageNotReady,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: _task.status.isActive
                  ? null
                  : () => store.retryTask(_task.id),
              child: Text(l10n.sceneTaskRetry),
            ),
            TextButton(
              onPressed: _task.status.isActive
                  ? null
                  : () => _openPromptEditor(context, store),
              child: Text(l10n.sceneTaskEdit),
            ),
            TextButton(
              onPressed: canGenerate
                  ? () async {
                      final created = await store.startImageTask(_task.id);
                      if (created == null && context.mounted) {
                        AnxToast.show(L10n.of(context).sceneTaskImageNotReady);
                      }
                    }
                  : null,
              child: Text(l10n.sceneTaskGenerateImage),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPromptEditor(
    BuildContext context,
    SceneTaskStore store,
  ) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController(text: _task.prompt);
    final result = await showDialog<({String prompt, bool generate})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final canSave = controller.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(l10n.sceneTaskEditTitle),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canSave ? l10n.sceneTaskEditHint : l10n.sceneTaskEditEmpty,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.sceneImageCancel),
              ),
              TextButton(
                onPressed: canSave
                    ? () => Navigator.pop(
                          dialogContext,
                          (prompt: controller.text, generate: false),
                        )
                    : null,
                child: Text(l10n.sceneTaskSave),
              ),
              FilledButton(
                onPressed: canSave
                    ? () => Navigator.pop(
                          dialogContext,
                          (prompt: controller.text, generate: true),
                        )
                    : null,
                child: Text(l10n.sceneTaskSaveAndGenerate),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (result == null) return;

    await store.editPrompt(_task.id, result.prompt);
    if (!result.generate) return;
    final created = await store.startImageTask(_task.id);
    if (created == null && context.mounted) {
      AnxToast.show(L10n.of(context).sceneTaskImageNotReady);
    }
  }
}
