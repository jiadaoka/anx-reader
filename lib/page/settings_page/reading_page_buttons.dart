import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/utils/env_var.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';

/// 阅读页按钮：按入口开关阅读页顶栏、底部菜单与划词菜单上的显示。
///
/// 开关只影响阅读页的入口显示，不删除数据，也不改对应功能页。
class ReadingPageButtonsSettings extends StatefulWidget {
  const ReadingPageButtonsSettings({super.key});

  @override
  State<ReadingPageButtonsSettings> createState() =>
      _ReadingPageButtonsSettingsState();
}

class _ReadingPageButtonsSettingsState
    extends State<ReadingPageButtonsSettings> {
  SettingsTile _switchTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String description,
  }) {
    return SettingsTile.switchTile(
      initialValue: value,
      onToggle: (value) {
        onChanged(value);
        setState(() {});
      },
      title: Text(title),
      description: Text(description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return settingsSections(
      sections: [
        if (EnvVar.enableAIFeature)
          SettingsSection(
            title: Text(l10n.readingPageButtonsTopBarSection),
            tiles: [
              _switchTile(
                value: Prefs().readerPageShowTopBarAi,
                onChanged: (value) => Prefs().readerPageShowTopBarAi = value,
                title: l10n.aiChat,
                description: l10n.readingPageButtonTopBarAiHint,
              ),
            ],
          ),
        SettingsSection(
          title: Text(l10n.readingPageButtonsBottomSection),
          tiles: [
            _switchTile(
              value: Prefs().readerPageShowBottomNotes,
              onChanged: (value) => Prefs().readerPageShowBottomNotes = value,
              title: l10n.notes,
              description: l10n.readingPageButtonBottomNotesHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowBottomStyle,
              onChanged: (value) => Prefs().readerPageShowBottomStyle = value,
              title: l10n.readingPageStyle,
              description: l10n.readingPageButtonBottomStyleHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowBottomTts,
              onChanged: (value) => Prefs().readerPageShowBottomTts = value,
              title: l10n.settingsNarrate,
              description: l10n.readingPageButtonBottomTtsHint,
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.readingPageButtonsSelectionSection),
          tiles: [
            _switchTile(
              value: Prefs().readerPageShowSelectionSearch,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionSearch = value,
              title: l10n.contextMenuSearch,
              description: l10n.readingPageButtonSelectionSearchHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowSelectionTranslate,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionTranslate = value,
              title: l10n.contextMenuTranslate,
              description: l10n.readingPageButtonSelectionTranslateHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowSelectionNarrate,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionNarrate = value,
              title: l10n.contextMenuNarrate,
              description: l10n.readingPageButtonSelectionNarrateHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowSelectionNote,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionNote = value,
              title: l10n.contextMenuWriteIdea,
              description: l10n.readingPageButtonSelectionNoteHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowSelectionMarkup,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionMarkup = value,
              title: l10n.readingPageButtonSelectionMarkup,
              description: l10n.readingPageButtonSelectionMarkupHint,
            ),
            if (EnvVar.enableAIFeature)
              _switchTile(
                value: Prefs().readerPageShowSelectionAi,
                onChanged: (value) =>
                    Prefs().readerPageShowSelectionAi = value,
                title: l10n.navBarAI,
                description: l10n.readingPageButtonSelectionAiHint,
              ),
            _switchTile(
              value: Prefs().readerPageShowSelectionShare,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionShare = value,
              title: l10n.contextMenuShare,
              description: l10n.readingPageButtonSelectionShareHint,
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.sceneImageTitle),
          tiles: [
            _switchTile(
              value: Prefs().readerPageShowSelectionSceneImage,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionSceneImage = value,
              title: l10n.sceneImageDrawThis,
              description: l10n.readingPageButtonSelectionSceneImageHint,
            ),
            _switchTile(
              value: Prefs().readerPageShowSelectionSceneCharacter,
              onChanged: (value) =>
                  Prefs().readerPageShowSelectionSceneCharacter = value,
              title: l10n.sceneCharacterAssign,
              description: l10n.readingPageButtonSelectionSceneCharacterHint,
            ),
          ],
        ),
      ],
    );
  }
}
