import 'package:anx_reader/enums/scene_task_status.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/scene_characters_page.dart';
import 'package:anx_reader/providers/scene_characters.dart';
import 'package:anx_reader/providers/scene_illustrations.dart';
import 'package:anx_reader/providers/scene_tasks.dart';
import 'package:anx_reader/widgets/scene_image/scene_task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SceneTaskList extends ConsumerStatefulWidget {
  const SceneTaskList({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.closeDrawer,
  });

  final int bookId;
  final String bookTitle;
  final VoidCallback closeDrawer;

  @override
  ConsumerState<SceneTaskList> createState() => _SceneTaskListState();
}

class _SceneTaskListState extends ConsumerState<SceneTaskList> {
  @override
  void initState() {
    super.initState();
    final store = ref.read(sceneTaskStoreProvider);
    store.ensureLoaded();
    SceneIllustrationStore.instance.ensureLoaded();
    store.markBookRead(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final store = ref.watch(sceneTaskStoreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _charactersEntry(context),
        const SizedBox(height: 10),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              store,
              SceneIllustrationStore.instance,
            ]),
            builder: (context, _) {
              final tasks = store.tasksForBook(widget.bookId);
              if (tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.sceneTaskEmptyTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.sceneTaskEmptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final cleanable = tasks
                  .where(
                    (t) =>
                        t.status == SceneTaskStatus.failed ||
                        t.status == SceneTaskStatus.cancelled,
                  )
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.sceneTaskBookCount(widget.bookTitle, tasks.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) => SceneTaskCard(
                        key: ValueKey(tasks[index].id),
                        task: tasks[index],
                      ),
                    ),
                  ),
                  if (cleanable > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            await store.cleanupFinished(widget.bookId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(l10n.sceneTaskCleanupDone),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Text(l10n.sceneTaskCleanup(cleanable)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _charactersEntry(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final count =
        ref.watch(sceneCharactersProvider(widget.bookId)).valueOrNull?.length;
    final subtitle = count == null
        ? l10n.sceneImageCharacterEntryHint
        : '${l10n.sceneImageCharacterCount(count)} · '
            '${l10n.sceneImageCharacterEntryHint}';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SceneCharactersPage(
                bookId: widget.bookId,
                bookTitle: widget.bookTitle,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.people_outline,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sceneTaskCharactersEntry,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
