import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/providers/scene_tasks.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// 「画这一幕」的补充输入层。填完（可留空）入队一条提示词任务。
///
/// 关闭后不负责恢复阅读焦点，由调用方在 await 之后处理。
Future<void> showSceneSupplementSheet({
  required BuildContext context,
  required int bookId,
  required String bookTitle,
  required String excerpt,
  required String chapter,
  required String cfi,
  required double progress,
  String? contextBefore,
  String? contextAfter,
}) async {
  final l10n = L10n.of(context);
  final supplement = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => PointerInterceptor(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: _SupplementForm(
          excerpt: excerpt,
          chapter: chapter,
          progress: progress,
          hint: l10n.sceneImageSupplementHint,
          note: l10n.sceneImageSupplementNote,
          emptyNote: l10n.sceneImageSupplementEmptyNote,
        ),
      ),
    ),
  );

  if (supplement == null) return;

  await SceneTaskStore.instance.createPromptTask(
    bookId: bookId,
    bookTitle: bookTitle,
    excerpt: excerpt,
    chapter: chapter,
    cfi: cfi,
    progress: progress,
    supplement: supplement,
    contextBefore: contextBefore ?? '',
    contextAfter: contextAfter ?? '',
  );

  final toastContext = navigatorKey.currentContext;
  if (toastContext != null && toastContext.mounted) {
    AnxToast.show(L10n.of(toastContext).sceneImageQueuedToast);
  }
}

class _SupplementForm extends StatefulWidget {
  const _SupplementForm({
    required this.excerpt,
    required this.chapter,
    required this.progress,
    required this.hint,
    required this.note,
    required this.emptyNote,
  });

  final String excerpt;
  final String chapter;
  final double progress;
  final String hint;
  final String note;
  final String emptyNote;

  @override
  State<_SupplementForm> createState() => _SupplementFormState();
}

class _SupplementFormState extends State<_SupplementForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final progress = (widget.progress * 100).round();
    final source = widget.chapter.trim().isEmpty
        ? '$progress%'
        : '${widget.chapter} · $progress%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.sceneImageSupplementTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.excerpt, maxLines: 5, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                source,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.sceneImageSupplementLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          autofocus: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _controller.text.trim().isEmpty ? widget.emptyNote : widget.note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.sceneImageCancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _controller.text),
              child: Text(l10n.sceneImageGeneratePrompt),
            ),
          ],
        ),
      ],
    );
  }
}
