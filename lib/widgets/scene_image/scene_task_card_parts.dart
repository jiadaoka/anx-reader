import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:flutter/material.dart';

/// 任务卡公共四块骨架：头部（类型 + 展开 / 收起）、主体、信息块、尾部。
///
/// 卡片类型只决定 [main]、[info] 与 [footer] 装什么；展开状态由调用方持有，
/// 本组件只负责排版与分隔线。
class SceneTaskCardFrame extends StatelessWidget {
  const SceneTaskCardFrame({
    super.key,
    required this.isImageTask,
    required this.expanded,
    required this.onToggle,
    required this.main,
    required this.footer,
    this.info,
  });

  final bool isImageTask;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget main;
  final Widget footer;

  /// 展开后显示；收起时为 null，整块不参与布局。
  final Widget? info;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final infoWidget = info;

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
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isImageTask
                          ? scheme.primaryContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isImageTask
                          ? l10n.sceneTaskImageKind
                          : l10n.sceneTaskPromptKind,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onToggle,
                    child: Text(
                      expanded
                          ? l10n.sceneTaskCollapse
                          : l10n.sceneTaskExpand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: main,
          ),
          if (expanded && infoWidget != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: infoWidget,
            ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            child: footer,
          ),
        ],
      ),
    );
  }
}

/// 信息块：一组或多组明细，只放内容，不放动作。
class SceneTaskInfoBlock extends StatelessWidget {
  const SceneTaskInfoBlock({super.key, required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
            ],
            sections[i],
          ],
        ],
      ),
    );
  }
}

/// 信息块里的一组明细，如「基础信息」「上下文」「引用档案」。
class SceneTaskInfoSection extends StatelessWidget {
  const SceneTaskInfoSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
}

/// 一行「标签 + 值」。值为空时由调用方决定是否渲染，这里只兜底一个短横线。
class SceneTaskInfoRow extends StatelessWidget {
  const SceneTaskInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.maxLines,
  });

  final String label;
  final String value;
  final bool mono;

  /// 为 null 时按内容换行，不截断。
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 引用档案一行：只留档案名与命中关键词。
class SceneTaskRefRow extends StatelessWidget {
  const SceneTaskRefRow({
    super.key,
    required this.name,
    required this.keywords,
  });

  final String name;
  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (keywords.isNotEmpty)
              TextSpan(
                text: '：${keywords.join('、')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 版本行：x / y + 左右切换，可选显示当前版本的生成时间。
class SceneTaskVersionRow extends StatelessWidget {
  const SceneTaskVersionRow({
    super.key,
    required this.index,
    required this.total,
    this.time,
    this.onPrevious,
    this.onNext,
  });

  /// 从 1 开始的版本序号。
  final int index;
  final int total;
  final String? time;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l10n.sceneTaskPrevious,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          l10n.sceneTaskHistoryImage(index, total),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l10n.sceneTaskNext,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        const Spacer(),
        if (time != null)
          Text(
            time!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// 还没有内容时的占位骨架。
class SceneTaskPromptSkeleton extends StatelessWidget {
  const SceneTaskPromptSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    Widget line(double factor) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(1),
          const SizedBox(height: 7),
          line(0.92),
          const SizedBox(height: 7),
          line(0.64),
        ],
      ),
    );
  }
}

/// 排队中 / 生成中的一行提示。
class SceneTaskBusyRow extends StatelessWidget {
  const SceneTaskBusyRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 失败原因的一行提示。
class SceneTaskErrorRow extends StatelessWidget {
  const SceneTaskErrorRow({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 15, color: theme.colorScheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
