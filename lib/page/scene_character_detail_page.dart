import 'package:anx_reader/dao/scene_character.dart';
import 'package:anx_reader/enums/scene_character_field.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_character.dart';
import 'package:anx_reader/providers/scene_characters.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/delete_confirm.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SceneCharacterDetailPage extends ConsumerStatefulWidget {
  const SceneCharacterDetailPage({
    super.key,
    required this.characterId,
    required this.bookId,
  });

  final int characterId;
  final int bookId;

  @override
  ConsumerState<SceneCharacterDetailPage> createState() =>
      _SceneCharacterDetailPageState();
}

class _SceneCharacterDetailPageState
    extends ConsumerState<SceneCharacterDetailPage> {
  final Map<SceneCharacterField, TextEditingController> _promptControllers = {};
  TextEditingController? _bioController;

  @override
  void dispose() {
    _bioController?.dispose();
    for (final controller in _promptControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final charactersAsync = ref.watch(sceneCharactersProvider(widget.bookId));
    final title = _findCharacter(charactersAsync.valueOrNull)?.name ??
        l10n.sceneCharacterTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: charactersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (characters) {
          final character = _findCharacter(characters);
          if (character == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.sceneCharacterEmptyTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonOk),
                    ),
                  ],
                ),
              ),
            );
          }

          _ensureControllers(character);
          return settingsSections(
            sections: [
              _keywordsSection(context, character),
              _bioSection(context, character),
              _promptSection(context, character),
              CustomSettingsSection(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    l10n.sceneCharacterPromptHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              _fragmentsSection(context, character),
              CustomSettingsSection(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    l10n.sceneCharacterFragmentDeleteHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              CustomSettingsSection(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: OutlinedButton(
                    onPressed: () => _confirmDeleteCharacter(character),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(l10n.sceneCharacterDelete),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SceneCharacter? _findCharacter(List<SceneCharacter>? characters) {
    if (characters == null) return null;
    for (final character in characters) {
      if (character.id == widget.characterId) return character;
    }
    return null;
  }

  void _ensureControllers(SceneCharacter character) {
    _bioController ??= TextEditingController(text: character.bio);
    for (final field in SceneCharacterField.values) {
      _promptControllers.putIfAbsent(
        field,
        () => TextEditingController(
          text: character.promptFields[field.code] ?? '',
        ),
      );
    }
  }

  SettingsSection _keywordsSection(BuildContext context, SceneCharacter character) {
    final l10n = L10n.of(context);
    return SettingsSection(
      title: Text(l10n.sceneCharacterKeywords),
      tiles: [
        CustomSettingsTile(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final keyword in character.keywords)
                      InputChip(
                        label: Text(keyword),
                        deleteButtonTooltipMessage:
                            l10n.sceneCharacterDeleteKeyword,
                        onDeleted: () => _removeKeyword(character, keyword),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(l10n.sceneCharacterAddKeyword),
                      onPressed: () => _addKeyword(character),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.sceneCharacterKeywordsHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SettingsSection _bioSection(BuildContext context, SceneCharacter character) {
    final l10n = L10n.of(context);
    return SettingsSection(
      title: Text(l10n.sceneCharacterBio),
      tiles: [
        CustomSettingsTile(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      _saveCharacter(
                        character,
                        showToast: false,
                        invalidate: false,
                      );
                    }
                  },
                  child: TextField(
                    controller: _bioController,
                    minLines: 3,
                    maxLines: 6,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: l10n.sceneCharacterBioUnknown,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _saveCharacter(character),
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SettingsSection _promptSection(BuildContext context, SceneCharacter character) {
    final l10n = L10n.of(context);
    final fields = SceneCharacterField.values;

    return SettingsSection(
      title: Text(l10n.sceneCharacterPrompt),
      tiles: [
        CustomSettingsTile(
          child: Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                _promptFieldRow(context, character, fields[index]),
                if (index != fields.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _saveCharacter(character),
                    child: Text(l10n.commonSave),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _promptFieldRow(
    BuildContext context,
    SceneCharacter character,
    SceneCharacterField field,
  ) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              _fieldLabel(l10n, field),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) {
                  _saveCharacter(
                    character,
                    showToast: false,
                    invalidate: false,
                  );
                }
              },
              child: TextField(
                controller: _promptControllers[field],
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: l10n.sceneCharacterUnknown,
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SettingsSection _fragmentsSection(BuildContext context, SceneCharacter character) {
    final l10n = L10n.of(context);
    final fragments = character.fragments;

    return SettingsSection(
      title: Text(l10n.sceneCharacterFragments),
      tiles: [
        CustomSettingsTile(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: fragments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        l10n.sceneCharacterFragmentEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < fragments.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == fragments.length - 1 ? 0 : 10,
                          ),
                          child: _fragmentCard(
                            context,
                            fragments[index],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _fragmentCard(
    BuildContext context,
    SceneCharacterFragment fragment,
  ) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final chapter = fragment.chapter.trim();
    final percentage = (fragment.progress * 100).clamp(0, 100).round();
    final source = chapter.isEmpty
        ? l10n.sceneCharacterUnknown
        : '$chapter · $percentage%';

    return FilledContainer(
      key: ValueKey(fragment.id),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fragment.text,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Tooltip(
                message: l10n.sceneCharacterFragmentDelete,
                child: DeleteConfirm(
                  delete: () => _deleteFragment(fragment),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  confirmIcon: Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fieldLabel(L10n l10n, SceneCharacterField field) {
    return switch (field) {
      SceneCharacterField.hairColor => l10n.sceneCharacterFieldHairColor,
      SceneCharacterField.eyeColor => l10n.sceneCharacterFieldEyeColor,
      SceneCharacterField.hairstyle => l10n.sceneCharacterFieldHairstyle,
      SceneCharacterField.body => l10n.sceneCharacterFieldBody,
      SceneCharacterField.age => l10n.sceneCharacterFieldAge,
      SceneCharacterField.outfit => l10n.sceneCharacterFieldOutfit,
      SceneCharacterField.marks => l10n.sceneCharacterFieldMarks,
    };
  }

  Future<void> _saveCharacter(
    SceneCharacter character, {
    bool showToast = true,
    bool invalidate = true,
  }) async {
    character.bio = _bioController?.text.trim() ?? character.bio;

    final fields = <String, String>{};
    for (final field in SceneCharacterField.values) {
      final value = _promptControllers[field]?.text.trim() ??
          character.promptFields[field.code]?.trim() ??
          '';
      if (value.isNotEmpty) {
        fields[field.code] = value;
      }
    }
    character.promptFields = fields;

    await sceneCharacterDao.saveCharacter(character);
    if (!mounted) return;

    if (invalidate) {
      ref.invalidate(sceneCharactersProvider(widget.bookId));
    }
    if (showToast) {
      AnxToast.show(L10n.of(context).sceneCharacterSaved);
    }
  }

  Future<void> _addKeyword(SceneCharacter character) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sceneCharacterAddKeyword),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.sceneCharacterKeywords,
          ),
          onSubmitted: (text) =>
              Navigator.of(dialogContext).pop(text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || value.isEmpty || !mounted) return;
    if (character.keywords.contains(value)) return;

    character.keywords = [...character.keywords, value];
    await _saveCharacter(character);
  }

  Future<void> _removeKeyword(
    SceneCharacter character,
    String keyword,
  ) async {
    character.keywords =
        character.keywords.where((item) => item != keyword).toList();
    await _saveCharacter(character);
  }

  Future<void> _deleteFragment(SceneCharacterFragment fragment) async {
    final id = fragment.id;
    if (id == null) return;

    await sceneCharacterDao.deleteFragment(id);
    if (!mounted) return;

    ref.invalidate(sceneCharactersProvider(widget.bookId));
  }

  Future<void> _confirmDeleteCharacter(SceneCharacter character) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sceneCharacterDelete),
        content: Text(l10n.sceneCharacterDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    final id = character.id;
    if (confirmed != true || id == null || !mounted) return;

    await sceneCharacterDao.deleteCharacter(id);
    if (!mounted) return;

    ref.invalidate(sceneCharactersProvider(widget.bookId));
    Navigator.of(context).pop();
  }
}
