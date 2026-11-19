import 'package:anx_reader/dao/scene_workflow.dart';
import 'package:anx_reader/models/scene_workflow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sceneWorkflowsProvider = FutureProvider<List<SceneWorkflow>>((ref) async {
  return sceneWorkflowDao.selectAll();
});

final activeSceneWorkflowProvider =
    FutureProvider<SceneWorkflow?>((ref) async {
  return sceneWorkflowDao.selectActive();
});
