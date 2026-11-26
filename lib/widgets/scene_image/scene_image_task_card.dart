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
import 'package:anx_reader/service/scene_image/image_store.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/scene_image/scene_image_common.dart';
import 'package:anx_reader/widgets/scene_image/scene_task_card_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 生图任务卡：主体只有成图与关联任务，明细收进信息块。
class SceneImageTaskCard extends ConsumerStatefulWidget {
  const SceneImageTaskCard({super.key, required this.task});

  final SceneTask task;

  @override
  ConsumerState<SceneImageTaskCard> createState() => _SceneImageTaskCardState();
}

class _SceneImageTaskCardState extends ConsumerState<SceneImageTaskCard> {
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
    final results = _task.imageResults;
    final index = results.isEmpty
        ? 0
        : _historyIndex.clamp(0, results.length - 1).toInt();
    final entry = results.isEmpty ? null : results[index];
    final displayPrompt = (entry != null && entry.prompt.trim().isNotEmpty)
        ? entry.prompt
        : _task.prompt;
    final imagePath = (entry != null && entry.imagePath.isNotEmpty)
        ? entry.imagePath
        : _task.imagePath;
    final width = entry?.width ?? _task.width;
    final height = entry?.height ?? _task.height;
    final seed = entry?.seed ?? _task.seed;
    final workflowName = entry?.workflowName ?? _task.workflowName;
    final queuedText = sceneTaskQueuedText(context, _task);
    final store = ref.read(sceneTaskStoreProvider);
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
    final canInsertIntoBody = !showingThisEntry && insertDisabledReason == null;
    final relatedTaskId = _task.promptTaskId?.trim() ?? '';

    final mainChildren = <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _imagePreview(context, imagePath, theme),
      ),
    ];
    if (relatedTaskId.isNotEmpty) {
      mainChildren.add(const SizedBox(height: 8));
      mainChildren.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.sceneTaskRelatedTaskLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                relatedTaskId,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (queuedText != null) {
      mainChildren.add(const SizedBox(height: 8));
      mainChildren.add(SceneTaskBusyRow(text: queuedText));
    }
    if (_task.status == SceneTaskStatus.failed) {
      mainChildren.add(const SizedBox(height: 8));
      mainChildren.add(
        SceneTaskErrorRow(
          message: _task.failureReason.trim().isEmpty
              ? l10n.sceneTaskStatusFailed
              : _task.failureReason,
        ),
      );
    } else if (_task.status == SceneTaskStatus.cancelled) {
      mainChildren.add(const SizedBox(height: 6));
      mainChildren.add(
        Text(
          l10n.sceneTaskStatusCancelled,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (results.isNotEmpty) {
      if (relatedTaskId.isEmpty && queuedText == null) {
        mainChildren.add(const SizedBox(height: 4));
      }
      mainChildren.add(
        SceneTaskVersionRow(
          index: index + 1,
          total: results.length,
          onPrevious: index < results.length - 1
              ? () => setState(() => _historyIndex = index + 1)
              : null,
          onNext: index > 0
              ? () => setState(() => _historyIndex = index - 1)
              : null,
        ),
      );
    }

    return SceneTaskCardFrame(
      isImageTask: true,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mainChildren,
      ),
      info: _info(
        context,
        displayPrompt: displayPrompt,
        workflowName: workflowName,
        width: width,
        height: height,
        seed: seed,
        relatedTaskId: relatedTaskId,
        illustration: illustration,
      ),
      footer: _footer(
        context,
        store: store,
        entry: entry,
        imagePath: imagePath,
        showingThisEntry: showingThisEntry,
        canInsertIntoBody: canInsertIntoBody,
        insertDisabledReason: insertDisabledReason,
      ),
    );
  }

  Widget _info(
    BuildContext context, {
    required String displayPrompt,
    required String workflowName,
    required int? width,
    required int? height,
    required int? seed,
    required String relatedTaskId,
    required SceneIllustration? illustration,
  }) {
    final l10n = L10n.of(context);
    final insertPosition = _insertPosition(l10n, illustration);

    return SceneTaskInfoBlock(
      sections: [
        SceneTaskInfoSection(
          title: l10n.sceneTaskBasicInfoLabel,
          children: [
            SceneTaskInfoRow(
              label: l10n.sceneTaskTaskIdLabel,
              value: _task.id,
              mono: true,
            ),
            if (displayPrompt.trim().isNotEmpty)
              SceneTaskInfoRow(
                label: l10n.sceneTaskPromptLabel,
                value: displayPrompt,
                mono: true,
                maxLines: 5,
              ),
            if (workflowName.trim().isNotEmpty)
              SceneTaskInfoRow(
                label: l10n.sceneTaskWorkflowLabel,
                value: workflowName,
              ),
            if (width != null && height != null)
              SceneTaskInfoRow(
                label: l10n.sceneTaskCanvasSizeLabel,
                value: l10n.sceneWorkflowSizeValue(width, height),
              ),
            if (seed != null)
              SceneTaskInfoRow(
                label: l10n.sceneTaskSeedLabel,
                value: '$seed',
                mono: true,
              ),
            if (relatedTaskId.isNotEmpty)
              SceneTaskInfoRow(
                label: l10n.sceneTaskRelatedTaskIdLabel,
                value: relatedTaskId,
                mono: true,
              ),
            if (insertPosition != null)
              SceneTaskInfoRow(
                label: l10n.sceneTaskInsertPositionLabel,
                value: insertPosition,
              ),
          ],
        ),
      ],
    );
  }

  /// 只有这张卡（不是同锚点的别的任务）插进正文后才给插入位置。
  String? _insertPosition(L10n l10n, SceneIllustration? record) {
    if (record == null || !record.isValid || record.taskId != _task.id) {
      return null;
    }
    final paragraphIndex = record.paragraphIndex >= 0
        ? record.paragraphIndex
        : _task.sourceParagraphIndex;
    if (paragraphIndex < 0) return null;
    final chapter = _task.chapter.trim().isEmpty
        ? l10n.sceneTaskNoChapter
        : _task.chapter.trim();
    return l10n.sceneTaskInsertPosition(chapter, paragraphIndex + 1);
  }

  Widget _footer(
    BuildContext context, {
    required SceneTaskStore store,
    required SceneTaskHistoryEntry? entry,
    required String imagePath,
    required bool showingThisEntry,
    required bool canInsertIntoBody,
    required String? insertDisabledReason,
  }) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: canInsertIntoBody
                      ? () => _insertIntoBody(entry)
                      : null,
                  child: Text(
                    showingThisEntry
                        ? l10n.sceneIllustrationInserted
                        : l10n.sceneIllustrationInsert,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _task.status.isActive
                  ? null
                  : () => store.retryTask(_task.id),
              child: Text(l10n.sceneTaskRetry),
            ),
            TextButton(
              onPressed:
                  imagePath.isEmpty ? null : () => _openViewer(context, imagePath),
              child: Text(l10n.sceneTaskViewImage),
            ),
            if (_task.status.isActive)
              TextButton(
                onPressed: () => store.cancelTask(_task.id),
                child: Text(l10n.sceneTaskCancel),
              ),
          ],
        ),
        if (insertDisabledReason != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              insertDisabledReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
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

  Future<void> _insertIntoBody(SceneTaskHistoryEntry? entry) async {
    if (entry == null) return;
    final player = epubPlayerKey.currentState;
    if (player == null) return;
    await player.insertIllustration(_task, entry);
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
}
