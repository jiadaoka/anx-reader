import 'package:anx_reader/models/scene_task.dart';
import 'package:anx_reader/widgets/scene_image/scene_image_task_card.dart';
import 'package:anx_reader/widgets/scene_image/scene_prompt_task_card.dart';
import 'package:flutter/material.dart';

/// 任务卡入口：按任务类型分派到两种卡，不在这里拼字段。
class SceneTaskCard extends StatelessWidget {
  const SceneTaskCard({super.key, required this.task});

  final SceneTask task;

  @override
  Widget build(BuildContext context) {
    if (task.isImageTask) {
      return SceneImageTaskCard(task: task);
    }
    return ScenePromptTaskCard(task: task);
  }
}
