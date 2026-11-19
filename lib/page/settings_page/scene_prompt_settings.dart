import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/scene_image/prompt_base.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/anx_button.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';

class ScenePromptSettingsPage extends StatefulWidget {
  const ScenePromptSettingsPage({super.key});

  @override
  State<ScenePromptSettingsPage> createState() =>
      _ScenePromptSettingsPageState();
}

class _ScenePromptSettingsPageState extends State<ScenePromptSettingsPage> {
  late final TextEditingController _jailbreakController;
  late final TextEditingController _specController;
  late final TextEditingController _contractController;
  late final TextEditingController _thinkingController;
  late bool _jailbreakEnabled;

  @override
  void initState() {
    super.initState();
    final prefs = Prefs();
    _jailbreakEnabled = prefs.scenePromptJailbreakEnabled;
    _jailbreakController =
        TextEditingController(text: prefs.scenePromptJailbreakText);
    _specController = TextEditingController(text: prefs.scenePromptSpecText);
    _contractController =
        TextEditingController(text: prefs.scenePromptContractText);
    _thinkingController =
        TextEditingController(text: prefs.scenePromptThinkingText);
    for (final controller in [
      _jailbreakController,
      _specController,
      _contractController,
      _thinkingController,
    ]) {
      controller.addListener(_handleTextChanged);
    }
  }

  void _handleTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _jailbreakController.dispose();
    _specController.dispose();
    _contractController.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scenePromptTitle)),
      body: settingsSections(sections: [
        SettingsSection(
          title: Text(l10n.scenePromptJailbreakSection),
          tiles: [
            SettingsTile.switchTile(
              initialValue: _jailbreakEnabled,
              onToggle: (value) {
                Prefs().scenePromptJailbreakEnabled = value;
                setState(() => _jailbreakEnabled = value);
              },
              title: Text(l10n.scenePromptJailbreakToggle),
              description: Text(l10n.scenePromptJailbreakHint),
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.scenePromptJailbreakTextTitle),
          tiles: [
            _promptField(
              controller: _jailbreakController,
              builtin: sceneJailbreakPrompt,
              enabled: _jailbreakEnabled,
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.scenePromptSpecTitle),
          tiles: [
            _promptField(
              controller: _specController,
              builtin: scenePromptSpec,
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.scenePromptContractTitle),
          tiles: [
            _promptField(
              controller: _contractController,
              builtin: scenePromptContract,
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.scenePromptThinkingTitle),
          tiles: [
            _promptField(
              controller: _thinkingController,
              builtin: sceneThinkingList,
            ),
          ],
        ),
        CustomSettingsSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: AnxButton(
                onPressed: _save,
                child: Text(l10n.scenePromptSave),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  CustomSettingsTile _promptField({
    required TextEditingController controller,
    required String builtin,
    bool enabled = true,
  }) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final modified =
        controller.text.trim().isNotEmpty && controller.text != builtin;

    return CustomSettingsTile(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              enabled: enabled,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.6,
                color: enabled ? null : theme.disabledColor,
              ),
              decoration: InputDecoration(
                hintText: l10n.scenePromptPlaceholder,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              modified ? l10n.scenePromptModified : l10n.scenePromptBuiltinNote,
              style: TextStyle(
                fontSize: 12,
                color: modified ? theme.colorScheme.primary : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final prefs = Prefs();
    prefs.scenePromptJailbreakText = _jailbreakController.text;
    prefs.scenePromptSpecText = _specController.text;
    prefs.scenePromptContractText = _contractController.text;
    prefs.scenePromptThinkingText = _thinkingController.text;
    AnxToast.show(L10n.of(context).scenePromptSaved);
  }
}
