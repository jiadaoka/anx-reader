import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/scene_workflow.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_workflow.dart';
import 'package:anx_reader/page/scene_characters_page.dart';
import 'package:anx_reader/page/settings_page/scene_prompt_settings.dart';
import 'package:anx_reader/page/settings_page/scene_workflow_edit.dart';
import 'package:anx_reader/providers/current_reading.dart';
import 'package:anx_reader/providers/scene_characters.dart';
import 'package:anx_reader/providers/scene_workflows.dart';
import 'package:anx_reader/service/scene_image/comfyui_client.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SceneImageSettings extends ConsumerStatefulWidget {
  const SceneImageSettings({super.key});

  @override
  ConsumerState<SceneImageSettings> createState() => _SceneImageSettingsState();
}

class _SceneImageSettingsState extends ConsumerState<SceneImageSettings> {
  bool _testingConnection = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workflows =
        ref.watch(sceneWorkflowsProvider).valueOrNull ?? const <SceneWorkflow>[];
    final activeWorkflow = ref.watch(activeSceneWorkflowProvider).valueOrNull ??
        _findActive(workflows);
    final book = ref.watch(currentReadingProvider).book;
    final characterCount = book == null
        ? null
        : ref.watch(sceneCharactersProvider(book.id)).valueOrNull?.length;

    return settingsSections(sections: [
      CustomSettingsSection(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FilledContainer(
            padding: EdgeInsets.zero,
            child: SettingsTile.switchTile(
              initialValue: Prefs().sceneImageEnabled,
              onToggle: (value) {
                Prefs().sceneImageEnabled = value;
                setState(() {});
              },
              title: Text(l10n.sceneImageEnabled),
              description: Text(l10n.sceneImageEnableHint),
            ),
          ),
        ),
      ),
      SettingsSection(
        title: Text(l10n.sceneImagePromptSection),
        tiles: [
          SettingsTile.navigation(
            title: Text(l10n.sceneImagePromptSection),
            description: Text(l10n.sceneImagePromptSubtitle),
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScenePromptSettingsPage(),
                ),
              );
            },
          ),
          SettingsTile(
            title: Text(l10n.sceneImageAiService),
            description: Text(l10n.sceneImageAiServiceHint),
            trailing: Text(l10n.sceneImageAiServiceValue),
          ),
        ],
      ),
      SettingsSection(
        title: Text(l10n.sceneImageComfySection),
        tiles: [
          SettingsTile.navigation(
            title: Text(l10n.sceneImageComfyServer),
            description: Text(
              Prefs().sceneComfyServer.trim().isEmpty
                  ? l10n.sceneImageComfyServerHint
                  : Prefs().sceneComfyServer,
            ),
            onPressed: (context) => _editServer(context),
          ),
          CustomSettingsTile(child: _connectionTile(l10n)),
        ],
      ),
      SettingsSection(
        title: Text(l10n.sceneImageWorkflowSection),
        tiles: [
          SettingsTile.navigation(
            title: Text(l10n.sceneImageCurrentWorkflow),
            description: Text(l10n.sceneImageCurrentWorkflowHint),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                activeWorkflow?.name ?? l10n.sceneImageNoWorkflow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            enabled: workflows.isNotEmpty,
            onPressed: workflows.isEmpty
                ? null
                : (context) => _pickWorkflow(workflows, activeWorkflow),
          ),
          SettingsTile.navigation(
            title: Text(l10n.sceneImageEditWorkflow),
            enabled: activeWorkflow != null,
            onPressed: activeWorkflow == null
                ? null
                : (context) => _openWorkflowEdit(activeWorkflow),
          ),
          SettingsTile.navigation(
            title: Text(l10n.sceneImageNewWorkflow),
            onPressed: (context) => _openWorkflowEdit(null),
          ),
          CustomSettingsTile(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                l10n.sceneImageWorkflowFooter,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
      SettingsSection(
        title: Text(l10n.sceneImageCharacterSection),
        tiles: [
          if (book == null)
            SettingsTile.navigation(
              title: Text(l10n.sceneImageCharacterEntry),
              description: Text(l10n.sceneImageCharacterEntryHint),
              enabled: false,
              onPressed: null,
            )
          else
            SettingsTile.navigation(
              title: Text(l10n.sceneImageCharacterEntry),
              description: Text(l10n.sceneImageCharacterEntryHint),
              trailing: characterCount == null
                  ? null
                  : Text(l10n.sceneImageCharacterCount(characterCount)),
              onPressed: (context) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SceneCharactersPage(
                      bookId: book.id,
                      bookTitle: book.title,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      SettingsSection(
        title: Text(l10n.sceneImageDataSection),
        tiles: [
          SettingsTile.switchTile(
            initialValue: Prefs().sceneAutoInsertEnabled,
            onToggle: (value) {
              Prefs().sceneAutoInsertEnabled = value;
              setState(() {});
            },
            title: Text(l10n.sceneImageAutoInsert),
            description: Text(l10n.sceneImageAutoInsertHint),
          ),
          SettingsTile(
            title: Text(l10n.sceneImageImageLocation),
            trailing: Text(l10n.sceneImageAppPrivateDir),
          ),
          SettingsTile(
            title: Text(l10n.sceneImageTaskRecords),
            trailing: Text(l10n.sceneImageNoAutoClean),
          ),
        ],
      ),
    ]);
  }

  SceneWorkflow? _findActive(List<SceneWorkflow> workflows) {
    for (final workflow in workflows) {
      if (workflow.isActive) return workflow;
    }
    return null;
  }

  Widget _connectionTile(L10n l10n) {
    final serverConfigured = Prefs().sceneComfyServer.trim().isNotEmpty;
    final status = Prefs().sceneComfyStatus;
    final failed = status == Prefs.sceneComfyStatusFailed;
    final statusText = switch (status) {
      Prefs.sceneComfyStatusOk => l10n.sceneImageComfyOk,
      Prefs.sceneComfyStatusFailed => l10n.sceneImageComfyFailed,
      _ => l10n.sceneImageComfyUntested,
    };

    return ListTile(
      title: Text(l10n.sceneImageComfyConnection),
      subtitle: Text(statusText),
      trailing: _testingConnection
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: serverConfigured ? _testConnection : null,
              child: Text(
                failed ? l10n.sceneImageComfyRetry : l10n.sceneImageComfyTest,
              ),
            ),
    );
  }

  Future<void> _editServer(BuildContext context) async {
    final l10n = L10n.of(context);
    var server = Prefs().sceneComfyServer;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sceneImageComfyServer),
        content: TextFormField(
          initialValue: server,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: l10n.sceneImageComfyServerHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => server = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, server),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (result == null) return;
    final value = result.trim();
    if (value == Prefs().sceneComfyServer) return;
    Prefs().sceneComfyServer = value;
    // 换了地址，旧的连接结果就不作数了。
    Prefs().sceneComfyStatus = Prefs.sceneComfyStatusUntested;
    if (mounted) setState(() {});
  }

  Future<void> _testConnection() async {
    final server = Prefs().sceneComfyServer.trim();
    if (server.isEmpty) return;
    setState(() => _testingConnection = true);
    try {
      await ComfyUiClient(server: server).testConnection();
      Prefs().sceneComfyStatus = Prefs.sceneComfyStatusOk;
      if (!mounted) return;
      AnxToast.show(L10n.of(context).sceneImageComfyOk);
    } on SceneImageFailure catch (e) {
      Prefs().sceneComfyStatus = Prefs.sceneComfyStatusFailed;
      if (!mounted) return;
      AnxToast.show(e.detail);
    } catch (e) {
      Prefs().sceneComfyStatus = Prefs.sceneComfyStatusFailed;
      if (!mounted) return;
      AnxToast.show(e.toString());
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _pickWorkflow(
    List<SceneWorkflow> workflows,
    SceneWorkflow? activeWorkflow,
  ) async {
    final selected = await showModalBottomSheet<SceneWorkflow>(
      context: context,
      builder: (sheetContext) {
        final l10n = L10n.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.sceneImageCurrentWorkflow,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final workflow in workflows)
                ListTile(
                  title: Text(workflow.name),
                  trailing: workflow.id == activeWorkflow?.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, workflow),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    final selectedId = selected.id;
    if (selectedId == null || selectedId == activeWorkflow?.id) return;
    await sceneWorkflowDao.setActive(selectedId);
    if (!mounted) return;
    ref.invalidate(sceneWorkflowsProvider);
    ref.invalidate(activeSceneWorkflowProvider);
  }

  Future<void> _openWorkflowEdit(SceneWorkflow? workflow) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneWorkflowEditPage(workflow: workflow),
      ),
    );
    if (!mounted) return;
    ref.invalidate(sceneWorkflowsProvider);
    ref.invalidate(activeSceneWorkflowProvider);
  }
}
