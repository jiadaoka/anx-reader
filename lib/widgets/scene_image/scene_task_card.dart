import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/scene_task_status.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_illustration.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:anx_reader/page/book_player/image_viewer.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/providers/scene_illustrations.dart';
import 'package:anx_reader/providers/scene_tasks.dart';
import 'package:anx_reader/providers/scene_workflows.dart';
import 'package:anx_reader/service/scene_image/image_store.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/scene_image/scene_image_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SceneTaskCard extends ConsumerStatefulWidget {
  const SceneTaskCard({super.key, required this.task});

  final SceneTask task;

  @override
  ConsumerState<SceneTaskCard> createState() => _SceneTaskCardState();
}

class _SceneTaskCardState extends ConsumerState<SceneTaskCard> {
  bool _expanded = false;
  int _historyIndex = 0;

  SceneTask get _task => widget.task;

  @override
  void initState() {
    super.initState();
    SceneIllustrationStore.instance.addListener(_onIllustrationsChanged);
  }

  @override
  void dispose() {
    SceneIllustrationStore.instance.removeListener(_onIllustrationsChanged);
    super.dispose();
  }

  void _onIllustrationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = ref.read(sceneTaskStoreProvider);
    final activeWorkflow = ref.watch(activeSceneWorkflowProvider).valueOrNull;

    final versions = _task.promptVersions;
    final results = _task.imageResults;
    final history = _task.isImageTask ? results : versions;
    final index = history.isEmpty
        ? 0
        : _historyIndex.clamp(0, history.length - 1).toInt();
    final entry = history.isEmpty ? null : history[index];

    final displayPrompt = (entry != null && entry.prompt.trim().isNotEmpty)
        ? entry.prompt
        : _task.prompt;
    final imagePath =
        (entry != null && entry.imagePath.isNotEmpty) ? entry.imagePath : _task.imagePath;
    final width = entry?.width ?? _task.width;
    final height = entry?.height ?? _task.height;
    final seed = entry?.seed ?? _task.seed;
    final workflowName = entry?.workflowName ?? _task.workflowName;
    final queuedText = sceneTaskQueuedText(context, _task);
    final canGenerate = _task.isPromptTask &&
        _task.status == SceneTaskStatus.completed &&
        _task.prompt.trim().isNotEmpty &&
        Prefs().sceneComfyServer.trim().isNotEmpty &&
        activeWorkflow != null;

    final illustrationStore = ref.read(sceneIllustrationStoreProvider);
    final illustration = illustrationStore.forTaskAnchor(_task);
    final hasSourceAnchor = _task.sourceSectionHref.isNotEmpty &&
        _task.sourceParagraphText.isNotEmpty;
    final showingThisEntry = illustrationStore.isShowing(_task, entry);
    final insertDisabledReason = _insertDisabledReason(
      l10n,
      entry,
      illustration,
      hasSourceAnchor,
    );
    final canInsertIntoBody =
        !showingThisEntry && insertDisabledReason == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _task.isImageTask
                              ? scheme.primaryContainer
                              : scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _task.isImageTask
                              ? l10n.sceneTaskImageKind
                              : l10n.sceneTaskPromptKind,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sceneTaskClock(_task.createTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded
                              ? l10n.sceneTaskCollapse
                              : l10n.sceneTaskCredentials,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _task.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_task.supplement.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.sceneTaskSupplementLabel}：${_task.supplement}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_task.isPromptTask) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        displayPrompt.trim().isEmpty
                            ? l10n.sceneTaskPromptEmpty
                            : displayPrompt,
                        maxLines: _expanded ? 12 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (_task.isImageTask) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _imagePreview(context, imagePath, theme),
                    ),
                    if (imagePath.isNotEmpty && width != null && height != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$workflowName · '
                          '${l10n.sceneWorkflowSizeValue(width, height)}'
                          '${seed == null ? '' : ' · seed $seed'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                  if (queuedText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            queuedText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_task.status == SceneTaskStatus.failed &&
                      _task.failureReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 15, color: scheme.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _task.failureReason,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_task.status == SceneTaskStatus.cancelled) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.sceneTaskStatusCancelled,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (history.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.sceneTaskPrevious,
                    onPressed: index < history.length - 1
                        ? () => setState(() => _historyIndex = index + 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _task.isPromptTask
                        ? l10n.sceneTaskHistoryPrompt(
                            index + 1,
                            history.length,
                          )
                        : l10n.sceneTaskHistoryImage(
                            index + 1,
                            history.length,
                          ),
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.sceneTaskNext,
                    onPressed: index > 0
                        ? () => setState(() => _historyIndex = index - 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const Spacer(),
                  if (entry != null)
                    Text(
                      sceneTaskClock(entry.createTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: _credentials(
                context,
                displayPrompt: displayPrompt,
                workflowName: workflowName,
                width: width,
                height: height,
                seed: seed,
                time: entry?.createTime ?? _task.createTime,
              ),
            ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
          if (_task.isPromptTask &&
              _task.status == SceneTaskStatus.completed &&
              !canGenerate)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                l10n.sceneTaskImageNotReady,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sceneTaskSourceText(context, _task),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ..._actions(
                  context,
                  store: store,
                  canGenerate: canGenerate,
                  imagePath: imagePath,
                ),
              ],
            ),
          ),
          if (_task.isImageTask)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: canInsertIntoBody
                        ? () => _insertIntoBody(entry)
                        : null,
                    child: Text(
                      showingThisEntry
                          ? l10n.sceneIllustrationInserted
                          : l10n.sceneIllustrationInsert,
                    ),
                  ),
                ],
              ),
            ),
          if (_task.isImageTask && insertDisabledReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                insertDisabledReason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePreview(BuildContext context, String imagePath, ThemeData theme) {
    final placeholder = Container(
      height: 150,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Icon(
        Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
    if (imagePath.isEmpty) return placeholder;
    return Image.file(
      File(sceneImageFullPath(imagePath)),
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  String? _insertDisabledReason(
    L10n l10n,
    SceneTaskHistoryEntry? entry,
    SceneIllustration? record,
    bool hasSourceAnchor,
  ) {
    if (!_task.isImageTask) return null;
    if (!Prefs().sceneImageEnabled) return l10n.sceneIllustrationSwitchedOff;
    if (!hasSourceAnchor) return l10n.sceneIllustrationNoAnchor;
    if (entry == null ||
        entry.status != SceneTaskStatus.completed ||
        entry.imagePath.isEmpty) {
      return l10n.sceneIllustrationNoImage;
    }
    if (record != null && !record.isValid) {
      return l10n.sceneIllustrationInvalidCannotInsert;
    }
    return null;
  }

  String _illustrationStatusText(L10n l10n) {
    final record = SceneIllustrationStore.instance.forTaskAnchor(_task);
    if (record == null) return l10n.sceneIllustrationNotInserted;
    if (!record.isValid) return l10n.sceneIllustrationAnchorInvalid;
    if (record.taskId != _task.id) {
      return l10n.sceneIllustrationNotInserted;
    }
    final results = _task.imageResults;
    final version = results.indexWhere((e) => e.id == record.entryId);
    return l10n.sceneIllustrationInBody(version < 0 ? 1 : version + 1);
  }

  Future<void> _insertIntoBody(SceneTaskHistoryEntry? entry) async {
    if (entry == null) return;
    final player = epubPlayerKey.currentState;
    if (player == null) return;
    await player.insertIllustration(_task, entry);
  }

  Widget _credentials(
    BuildContext context, {
    required String displayPrompt,
    required String workflowName,
    required int? width,
    required int? height,
    required int? seed,
    required DateTime time,
  }) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(l10n.sceneTaskPromptLabel, displayPrompt, mono: true),
          if (_task.supplement.trim().isNotEmpty)
            _kv(l10n.sceneTaskSupplementLabel, _task.supplement),
          if (_task.isImageTask) ...[
            _kv(l10n.sceneTaskWorkflowLabel, workflowName),
            if (width != null && height != null)
              _kv(
                l10n.sceneTaskFrameLabel,
                l10n.sceneWorkflowSizeValue(width, height),
              ),
            if (seed != null) _kv(l10n.sceneTaskSeedLabel, '$seed'),
          ],
          _kv(
            l10n.sceneTaskSourceLabel,
            _task.isImageTask
                ? '${sceneTaskSourceText(context, _task)} · '
                    '${_illustrationStatusText(l10n)}'
                : sceneTaskSourceText(context, _task),
          ),
          _kv(l10n.sceneTaskTimeLabel, sceneTaskDateTime(time)),
          const SizedBox(height: 4),
          Text(
            l10n.sceneTaskContextLabel,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          _kv(
            l10n.sceneTaskContextBefore,
            _task.contextBefore.trim().isEmpty
                ? l10n.sceneTaskContextMissing
                : _task.contextBefore,
            maxLines: 6,
          ),
          _kv(
            l10n.sceneTaskContextAfter,
            _task.contextAfter.trim().isEmpty
                ? l10n.sceneTaskContextMissing
                : _task.contextAfter,
            maxLines: 6,
          ),
          if (!_task.contextComplete)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.sceneTaskContextMissing,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            l10n.sceneTaskRefsLabel,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          if (_task.characterRefs.isEmpty)
            Text(
              l10n.sceneTaskRefEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (final ref in _task.characterRefs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${ref.name}', style: theme.textTheme.bodySmall),
                    if (ref.keywords.isNotEmpty)
                      Text(
                        '${l10n.sceneTaskRefKeywords}：${ref.keywords.join('、')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (ref.promptText.trim().isNotEmpty)
                      Text(
                        '${l10n.sceneTaskRefPrompt}：${ref.promptText}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (ref.fragments.isNotEmpty)
                      Text(
                        '${l10n.sceneTaskRefFragments}：${ref.fragments.join(' / ')}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    bool mono = false,
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              maxLines: mono ? 6 : maxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: mono ? 'monospace' : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context, {
    required SceneTaskStore store,
    required bool canGenerate,
    required String imagePath,
  }) {
    final l10n = L10n.of(context);
    final actions = <Widget>[];

    if (_task.isPromptTask) {
      actions.add(TextButton(
        onPressed: _task.status.isActive
            ? null
            : () => store.retryTask(_task.id),
        child: Text(l10n.sceneTaskRetry),
      ));
      actions.add(TextButton(
        onPressed: _task.status.isActive
            ? null
            : () => _openPromptEditor(context, store),
        child: Text(l10n.sceneTaskEdit),
      ));
      actions.add(TextButton(
        onPressed: canGenerate
            ? () async {
                final created = await store.startImageTask(_task.id);
                if (created == null && context.mounted) {
                  AnxToast.show(L10n.of(context).sceneTaskImageNotReady);
                }
              }
            : null,
        child: Text(l10n.sceneTaskGenerateImage),
      ));
    } else {
      actions.add(TextButton(
        onPressed: _task.status.isActive
            ? null
            : () => store.retryTask(_task.id),
        child: Text(l10n.sceneTaskRetry),
      ));
      actions.add(TextButton(
        onPressed: imagePath.isEmpty
            ? null
            : () => _openViewer(context, imagePath),
        child: Text(l10n.sceneTaskViewImage),
      ));
      if (_task.status.isActive) {
        actions.add(TextButton(
          onPressed: () => store.cancelTask(_task.id),
          child: Text(l10n.sceneTaskCancel),
        ));
      }
    }

    return actions;
  }

  Future<void> _openViewer(BuildContext context, String imagePath) async {
    final dataUrl = await sceneImageDataUrl(imagePath);
    if (!context.mounted) return;
    if (dataUrl == null) {
      AnxToast.show(L10n.of(context).sceneImageErrorUnknown);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewer(
          image: dataUrl,
          bookName: _task.bookTitle,
        ),
      ),
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
