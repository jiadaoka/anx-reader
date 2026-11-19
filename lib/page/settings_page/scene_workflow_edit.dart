import 'package:anx_reader/dao/scene_workflow.dart';
import 'package:anx_reader/enums/scene_orientation.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/scene_workflow.dart';
import 'package:anx_reader/providers/scene_workflows.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/anx_button.dart';
import 'package:anx_reader/widgets/common/anx_segmented_button.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SceneWorkflowEditPage extends ConsumerStatefulWidget {
  const SceneWorkflowEditPage({super.key, this.workflow});

  final SceneWorkflow? workflow;

  @override
  ConsumerState<SceneWorkflowEditPage> createState() =>
      _SceneWorkflowEditPageState();
}

class _SceneWorkflowEditPageState extends ConsumerState<SceneWorkflowEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _jsonController;
  late final TextEditingController _portraitWidthController;
  late final TextEditingController _portraitHeightController;
  late final TextEditingController _landscapeWidthController;
  late final TextEditingController _landscapeHeightController;
  late SceneOrientation _orientation;
  late bool _isActive;

  SceneWorkflow? get _workflow => widget.workflow;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _jsonController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final workflow = widget.workflow;
    _nameController = TextEditingController(text: workflow?.name ?? '');
    _jsonController = TextEditingController(text: workflow?.workflowJson ?? '');
    _portraitWidthController = TextEditingController(
      text: '${workflow?.portraitWidth ?? SceneWorkflow.defaultPortraitWidth}',
    );
    _portraitHeightController = TextEditingController(
      text: '${workflow?.portraitHeight ?? SceneWorkflow.defaultPortraitHeight}',
    );
    _landscapeWidthController = TextEditingController(
      text: '${workflow?.landscapeWidth ?? SceneWorkflow.defaultLandscapeWidth}',
    );
    _landscapeHeightController = TextEditingController(
      text:
          '${workflow?.landscapeHeight ?? SceneWorkflow.defaultLandscapeHeight}',
    );
    _orientation = workflow?.orientation ?? SceneOrientation.auto;
    _isActive = workflow?.isActive ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jsonController.dispose();
    _portraitWidthController.dispose();
    _portraitHeightController.dispose();
    _landscapeWidthController.dispose();
    _landscapeHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isEditing = _workflow != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.sceneWorkflowTitle : l10n.sceneWorkflowNewTitle,
        ),
      ),
      body: settingsSections(sections: [
        CustomSettingsSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.sceneWorkflowName,
                hintText: l10n.sceneWorkflowNamePlaceholder,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        SettingsSection(
          title: Text(l10n.sceneWorkflowJsonTitle),
          tiles: [
            CustomSettingsTile(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _jsonController,
                  onChanged: (_) => setState(() {}),
                  minLines: 10,
                  maxLines: 16,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.sceneWorkflowJsonPlaceholder,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                ),
              ),
            ),
            CustomSettingsTile(child: _placeholderHelp(l10n)),
          ],
        ),
        SettingsSection(
          title: Text(l10n.sceneWorkflowFrameSection),
          tiles: [
            _sizeTile(
              l10n,
              title: l10n.sceneWorkflowPortrait,
              widthController: _portraitWidthController,
              heightController: _portraitHeightController,
              defaultWidth: SceneWorkflow.defaultPortraitWidth,
              defaultHeight: SceneWorkflow.defaultPortraitHeight,
            ),
            _sizeTile(
              l10n,
              title: l10n.sceneWorkflowLandscape,
              widthController: _landscapeWidthController,
              heightController: _landscapeHeightController,
              defaultWidth: SceneWorkflow.defaultLandscapeWidth,
              defaultHeight: SceneWorkflow.defaultLandscapeHeight,
            ),
            _orientationTile(l10n),
          ],
        ),
        if (isEditing)
          SettingsSection(
            title: Text(l10n.sceneWorkflowActions),
            tiles: [
              SettingsTile.navigation(
                title: Text(l10n.sceneWorkflowSetCurrent),
                description: Text(l10n.sceneWorkflowSetCurrentHint),
                trailing:
                    _isActive ? Text(l10n.sceneWorkflowCurrent) : null,
                enabled: !_isActive && _workflow?.id != null,
                onPressed: !_isActive && _workflow?.id != null
                    ? (context) => _setCurrent()
                    : null,
              ),
              SettingsTile.navigation(
                title: Text(l10n.sceneWorkflowCopyJson),
                onPressed: (context) => _copyJson(),
              ),
              SettingsTile.navigation(
                title: Text(
                  l10n.sceneWorkflowDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: (context) => _confirmDelete(),
              ),
            ],
          ),
        CustomSettingsSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: AnxButton(
                onPressed: _canSave ? _save : null,
                child: Text(l10n.commonSave),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _placeholderHelp(L10n l10n) {
    final theme = Theme.of(context);
    final helpItems = [
      (SceneWorkflow.promptPlaceholder, l10n.sceneWorkflowHelpPrompt),
      (SceneWorkflow.negativePlaceholder, l10n.sceneWorkflowHelpNegative),
      (SceneWorkflow.seedPlaceholder, l10n.sceneWorkflowHelpSeed),
      (SceneWorkflow.widthPlaceholder, l10n.sceneWorkflowHelpWidth),
      (SceneWorkflow.heightPlaceholder, l10n.sceneWorkflowHelpHeight),
    ];

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(l10n.sceneWorkflowHelpSummary),
        children: [
          for (final item in helpItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            l10n.sceneWorkflowHelpFooter,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  CustomSettingsTile _sizeTile(
    L10n l10n, {
    required String title,
    required TextEditingController widthController,
    required TextEditingController heightController,
    required int defaultWidth,
    required int defaultHeight,
  }) {
    final width = _sizeValue(widthController, defaultWidth);
    final height = _sizeValue(heightController, defaultHeight);
    return CustomSettingsTile(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  l10n.sceneWorkflowSizeValue(width, height),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _sizeField(widthController)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('×'),
                ),
                Expanded(child: _sizeField(heightController)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sizeField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }

  CustomSettingsTile _orientationTile(L10n l10n) {
    return CustomSettingsTile(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sceneWorkflowOrientation,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.sceneWorkflowOrientationHint,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            AnxSegmentedButton<SceneOrientation>(
              segments: [
                SegmentButtonItem(
                  value: SceneOrientation.auto,
                  label: l10n.sceneWorkflowAuto,
                ),
                SegmentButtonItem(
                  value: SceneOrientation.portrait,
                  label: l10n.sceneWorkflowPortraitLock,
                ),
                SegmentButtonItem(
                  value: SceneOrientation.landscape,
                  label: l10n.sceneWorkflowLandscapeLock,
                ),
              ],
              selected: {_orientation},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) return;
                setState(() => _orientation = selected.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  int _sizeValue(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return fallback;
    return value;
  }

  Future<void> _setCurrent() async {
    final id = _workflow?.id;
    if (id == null) return;
    await sceneWorkflowDao.setActive(id);
    if (!mounted) return;
    // 保存时会把对象写回数据库，这里同步内存里的标记以免保存后又被置回未启用。
    final workflow = _workflow;
    if (workflow != null) workflow.isActive = true;
    setState(() => _isActive = true);
    ref.invalidate(sceneWorkflowsProvider);
    ref.invalidate(activeSceneWorkflowProvider);
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _jsonController.text));
    if (!mounted) return;
    AnxToast.show(L10n.of(context).sceneWorkflowCopied);
  }

  Future<void> _confirmDelete() async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sceneWorkflowDelete),
        content: Text(l10n.sceneWorkflowDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = _workflow?.id;
    if (id == null) return;
    await sceneWorkflowDao.deleteWorkflow(id);
    if (!mounted) return;
    ref.invalidate(sceneWorkflowsProvider);
    ref.invalidate(activeSceneWorkflowProvider);
    AnxToast.show(l10n.sceneWorkflowDeleted);
    Navigator.pop(context, true);
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AnxToast.show(l10n.sceneWorkflowNameRequired);
      return;
    }
    final json = _jsonController.text;
    if (json.trim().isEmpty) return;

    final isNew = _workflow == null;
    final workflow = _workflow ?? SceneWorkflow(name: name);
    workflow.name = name;
    workflow.workflowJson = json;
    workflow.portraitWidth = _sizeValue(
      _portraitWidthController,
      SceneWorkflow.defaultPortraitWidth,
    );
    workflow.portraitHeight = _sizeValue(
      _portraitHeightController,
      SceneWorkflow.defaultPortraitHeight,
    );
    workflow.landscapeWidth = _sizeValue(
      _landscapeWidthController,
      SceneWorkflow.defaultLandscapeWidth,
    );
    workflow.landscapeHeight = _sizeValue(
      _landscapeHeightController,
      SceneWorkflow.defaultLandscapeHeight,
    );
    workflow.orientation = _orientation;

    await sceneWorkflowDao.save(workflow);
    if (isNew) {
      final active = await sceneWorkflowDao.selectActive();
      if (active == null && workflow.id != null) {
        await sceneWorkflowDao.setActive(workflow.id!);
      }
    }
    if (!mounted) return;
    ref.invalidate(sceneWorkflowsProvider);
    ref.invalidate(activeSceneWorkflowProvider);
    AnxToast.show(l10n.sceneWorkflowSaved);
    Navigator.pop(context, true);
  }
}
