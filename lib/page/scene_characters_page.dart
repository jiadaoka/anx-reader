import 'package:anx_reader/dao/scene_character.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_character.dart';
import 'package:anx_reader/page/scene_character_detail_page.dart';
import 'package:anx_reader/providers/scene_characters.dart';
import 'package:anx_reader/widgets/common/anx_button.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SceneCharactersPage extends ConsumerStatefulWidget {
  const SceneCharactersPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  final int bookId;
  final String bookTitle;

  @override
  ConsumerState<SceneCharactersPage> createState() =>
      _SceneCharactersPageState();
}

class _SceneCharactersPageState extends ConsumerState<SceneCharactersPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final charactersAsync = ref.watch(sceneCharactersProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sceneCharacterTitle),
      ),
      body: charactersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (characters) => settingsSections(
          sections: [
            CustomSettingsSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AnxButton.outlined(
                        onPressed: () => _createCharacter(characters),
                        child: Text(l10n.sceneCharacterAdd),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (characters.isEmpty)
              CustomSettingsSection(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        l10n.sceneCharacterEmptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.sceneCharacterEmptyHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              SettingsSection(
                tiles: [
                  for (final character in characters)
                    SettingsTile.navigation(
                      leading: CircleAvatar(
                        child: Text(_initial(character.name)),
                      ),
                      title: Text(character.name),
                      description: Text(_counts(l10n, character)),
                      onPressed: (context) => _openDetail(character),
                    ),
                ],
              ),
            CustomSettingsSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Text(
                  l10n.sceneCharacterKeywordsHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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

  Future<void> _openDetail(SceneCharacter character) async {
    final id = character.id;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneCharacterDetailPage(
          characterId: id,
          bookId: widget.bookId,
        ),
      ),
    );
    if (mounted) {
      ref.invalidate(sceneCharactersProvider(widget.bookId));
    }
  }

  Future<void> _createCharacter(List<SceneCharacter> characters) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final value = controller.text.trim();
            final exists = value.isNotEmpty &&
                characters.any((character) => character.name == value);
            final canCreate = value.isNotEmpty && !exists;

            return AlertDialog(
              title: Text(l10n.sceneCharacterNewTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.sceneCharacterName,
                  hintText: l10n.sceneCharacterNamePlaceholder,
                  errorText: value.isEmpty
                      ? l10n.sceneCharacterNameRequired
                      : exists
                          ? l10n.sceneCharacterNameExists
                          : null,
                ),
                onChanged: (_) => setDialogState(() {}),
                onSubmitted: (_) {
                  if (canCreate) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed:
                      canCreate ? () => Navigator.of(dialogContext).pop(value) : null,
                  child: Text(l10n.sceneCharacterCreate),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (name == null || !mounted) return;

    final character = SceneCharacter(
      bookId: widget.bookId,
      name: name,
      keywords: [name],
    );
    final id = await sceneCharacterDao.saveCharacter(character);
    if (!mounted) return;

    ref.invalidate(sceneCharactersProvider(widget.bookId));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneCharacterDetailPage(
          characterId: id,
          bookId: widget.bookId,
        ),
      ),
    );
    if (mounted) {
      ref.invalidate(sceneCharactersProvider(widget.bookId));
    }
  }
}
