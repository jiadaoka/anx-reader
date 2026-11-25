import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:flutter/material.dart';

enum SceneIllustrationAction { save, share, remove }

/// 正文插图长按菜单：保存、分享、移除。
///
/// 「移除」只改正文显示，图片文件与任务历史都不动。
Future<SceneIllustrationAction?> showSceneIllustrationActionSheet(
  BuildContext context,
) {
  final l10n = L10n.of(context);
  return showModalBottomSheet<SceneIllustrationAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.sceneIllustrationMenuTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.sceneIllustrationSave),
              onTap: () =>
                  Navigator.pop(sheetContext, SceneIllustrationAction.save),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.sceneIllustrationShare),
              onTap: () =>
                  Navigator.pop(sheetContext, SceneIllustrationAction.share),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.sceneIllustrationRemove,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, SceneIllustrationAction.remove),
            ),
            const Divider(height: 1),
            ListTile(
              title: Center(child: Text(l10n.commonCancel)),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      );
    },
  );
}
