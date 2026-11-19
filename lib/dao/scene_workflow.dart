import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/scene_workflow.dart';

class SceneWorkflowDao extends BaseDao {
  static const String table = 'tb_scene_workflows';

  Future<List<SceneWorkflow>> selectAll() async {
    return queryList(
      table,
      mapper: SceneWorkflow.fromRow,
      orderBy: 'create_time ASC',
    );
  }

  Future<SceneWorkflow?> selectById(int id) async {
    return querySingle(
      table,
      mapper: SceneWorkflow.fromRow,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<SceneWorkflow?> selectActive() async {
    return querySingle(
      table,
      mapper: SceneWorkflow.fromRow,
      where: 'is_active = ?',
      whereArgs: [1],
    );
  }

  Future<int> save(SceneWorkflow workflow) async {
    workflow.updateTime = DateTime.now();
    if (workflow.id != null) {
      final values = workflow.toRow();
      // 当前使用由 setActive 单独维护，保存一份工作流不应顺带改掉它。
      values.remove('is_active');
      await update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [workflow.id],
      );
      return workflow.id!;
    }
    final id = await insert(table, workflow.toRow());
    workflow.id = id;
    return id;
  }

  /// 全库只保留一套当前使用。
  Future<void> setActive(int id) async {
    await transaction((txn) async {
      await txn.update(table, {'is_active': 0});
      await txn.update(table, {'is_active': 1},
          where: 'id = ?', whereArgs: [id]);
    });
  }

  /// 删除后将第一套设为当前；如果删的不是当前使用的那套，当前使用不变。
  Future<void> deleteWorkflow(int id) async {
    await transaction((txn) async {
      await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      final active = await txn.query(
        table,
        where: 'is_active = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (active.isNotEmpty) return;
      final remaining = await txn.query(
        table,
        orderBy: 'create_time ASC',
        limit: 1,
      );
      if (remaining.isEmpty) return;
      final nextId = remaining.first['id'] as int;
      await txn.update(table, {'is_active': 1},
          where: 'id = ?', whereArgs: [nextId]);
    });
  }
}

final sceneWorkflowDao = SceneWorkflowDao();
