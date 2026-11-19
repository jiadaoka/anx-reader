import 'package:anx_reader/dao/scene_character.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_character.dart';
import 'package:anx_reader/providers/scene_characters.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/anx_button.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// 划词菜单「归入角色」的底部弹层。
///
/// 关闭后不负责恢复阅读焦点，由调用方在 await 之后处理。
Future<void> showSceneCharacterSheet({
  required BuildContext context,
  required int bookId,
  required String bookTitle,
  required String excerpt,
  required String chapter,
  required String cfi,
  required double progress,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => PointerInterceptor(
      child: _SceneCharacterSheet(
        bookId: bookId,
        bookTitle: bookTitle,
        excerpt: excerpt,
        chapter: chapter,
        cfi: cfi,
        progress: progress,
      ),
    ),
  );
}

class _SceneCharacterSheet extends ConsumerStatefulWidget {
  const _SceneCharacterSheet({
    required this.bookId,
    required this.bookTitle,
    required this.excerpt,
    required this.chapter,
    required this.cfi,
    required this.progress,
  });

  final int bookId;
  final String bookTitle;
  final String excerpt;
  final String chapter;
  final String cfi;
  final double progress;

  @override
  ConsumerState<_SceneCharacterSheet> createState() =>
      _SceneCharacterSheetState();
}

class _SceneCharacterSheetState extends ConsumerState<_SceneCharacterSheet> {
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  int? _selectedId;
  bool _creatingNew = false;
  bool _saving = false;

  @override
  void dispose() {
    _filterController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final charactersAsync = ref.watch(sceneCharactersProvider(widget.bookId));

    return charactersAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SizedBox(
        height: 240,
        child: Center(child: Text('$error')),
      ),
      data: (characters) => _buildSheet(context, l10n, characters),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    L10n l10n,
    List<SceneCharacter> characters,
  ) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets;
    final maxHeight = (media.size.height - viewInsets.bottom) * 0.85;

    final query = _filterController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? characters
        : characters.where((character) {
            if (character.name.toLowerCase().contains(query)) return true;
            return character.keywords
                .any((keyword) => keyword.toLowerCase().contains(query));
          }).toList();

    final name = _nameController.text.trim();
    final duplicate = name.isNotEmpty &&
        characters.any((character) => character.name == name);
    final canSubmit = _creatingNew
        ? name.isNotEmpty && !duplicate
        : _selectedId != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sceneCharacterAssignTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        widget.bookTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledContainer(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.excerpt,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _sourceText(l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.sceneCharacterAssignTo,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _filterController,
                      decoration: InputDecoration(
                        hintText: l10n.sceneCharacterFilter,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    for (final character in filtered)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(_initial(character.name)),
                        ),
                        title: Text(character.name),
                        subtitle: Text(_counts(l10n, character)),
                        selected: !_creatingNew && character.id == _selectedId,
                        trailing: !_creatingNew && character.id == _selectedId
                            ? Icon(
                                Icons.check,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () => setState(() {
                          _selectedId = character.id;
                          _creatingNew = false;
                        }),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add),
                      title: Text(l10n.sceneCharacterAssignNew),
                      selected: _creatingNew,
                      trailing: _creatingNew
                          ? Icon(
                              Icons.check,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => setState(() {
                        _creatingNew = true;
                        _selectedId = null;
                      }),
                    ),
                    if (_creatingNew) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l10n.sceneCharacterName,
                          hintText: l10n.sceneCharacterNamePlaceholder,
                          errorText:
                              duplicate ? l10n.sceneCharacterNameExists : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnxButton(
                    disabled: !canSubmit || _saving,
                    isLoading: _saving,
                    onPressed: () => _submit(characters),
                    child: Text(
                      _creatingNew
                          ? l10n.sceneCharacterCreateAndSave
                          : l10n.sceneCharacterSaveFragment,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  String _counts(L10n l10n, SceneCharacter character) {
    return [
      l10n.sceneCharacterKeywordCount(character.keywords.length),
      l10n.sceneCharacterFragmentCount(character.fragments.length),
    ].join(' • ');
  }

  String _sourceText(L10n l10n) {
    final chapter = widget.chapter.trim();
    if (chapter.isEmpty) return l10n.sceneCharacterSourceCurrent;
    final percentage = (widget.progress * 100).clamp(0, 100).round();
    return '$chapter · $percentage%';
  }

  Future<void> _submit(List<SceneCharacter> characters) async {
    if (_saving) return;

    final l10n = L10n.of(context);
    setState(() => _saving = true);
    try {
      if (_creatingNew) {
        final name = _nameController.text.trim();
        if (name.isEmpty ||
            characters.any((character) => character.name == name)) {
          return;
        }
        final character = SceneCharacter(
          bookId: widget.bookId,
          name: name,
          keywords: [name],
        );
        await sceneCharacterDao.saveCharacter(character);
        await sceneCharacterDao.saveFragment(
          SceneCharacterFragment(
            characterId: character.id!,
            text: widget.excerpt,
            cfi: widget.cfi,
            chapter: widget.chapter,
            progress: widget.progress,
          ),
        );
      } else {
        final characterId = _selectedId;
        if (characterId == null) return;
        await sceneCharacterDao.saveFragment(
          SceneCharacterFragment(
            characterId: characterId,
            text: widget.excerpt,
            cfi: widget.cfi,
            chapter: widget.chapter,
            progress: widget.progress,
          ),
        );
      }

      if (!mounted) return;
      ref.invalidate(sceneCharactersProvider(widget.bookId));
      AnxToast.show(l10n.sceneCharacterFragmentSaved);
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
