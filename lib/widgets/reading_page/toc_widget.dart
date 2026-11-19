import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/book_player/epub_player.dart';
import 'package:anx_reader/providers/scene_tasks.dart';
import 'package:anx_reader/widgets/reading_page/widgets/book_toc.dart';
import 'package:anx_reader/widgets/reading_page/widgets/bookmark.dart';
import 'package:anx_reader/widgets/scene_image/scene_task_list.dart';
import 'package:flutter/material.dart';

class TocWidget extends StatefulWidget {
  const TocWidget({
    super.key,
    required this.epubPlayerKey,
    required this.hideAppBarAndBottomBar,
    required this.closeDrawer,
  });

  final GlobalKey<EpubPlayerState> epubPlayerKey;
  final Function hideAppBarAndBottomBar;
  final VoidCallback closeDrawer;

  @override
  State<TocWidget> createState() => TocWidgetState();
}

class TocWidgetState extends State<TocWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_tabController.index != 2) return;
    final bookId = widget.epubPlayerKey.currentState?.book.id;
    if (bookId != null) {
      SceneTaskStore.instance.markBookRead(bookId);
    }
  }

  void showTasksTab() {
    if (_tabController.index != 2) {
      _tabController.animateTo(2);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.epubPlayerKey.currentState?.book;
    final hasUnread = book != null && Prefs().sceneTaskUnread(book.id);
    final theme = Theme.of(context);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: L10n.of(context).readingContents),
            Tab(text: L10n.of(context).readingBookmark),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(L10n.of(context).sceneTaskTab),
                  if (hasUnread)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TabBarView(
              controller: _tabController,
              children: [
                buildBookToc(),
                buildBookmarkList(),
                if (book == null)
                  const SizedBox.shrink()
                else
                  SceneTaskList(
                    bookId: book.id,
                    bookTitle: book.title,
                    closeDrawer: widget.closeDrawer,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildBookmarkList() {
    return BookmarkWidget(
      epubPlayerKey: widget.epubPlayerKey,
      onNavigate: () {
        widget.hideAppBarAndBottomBar(false);
        widget.closeDrawer();
      },
    );
  }

  BookToc buildBookToc() {
    return BookToc(
      epubPlayerKey: widget.epubPlayerKey,
      hideAppBarAndBottomBar: widget.hideAppBarAndBottomBar,
      closeDrawer: widget.closeDrawer,
    );
  }
}
