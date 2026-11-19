import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:sqflite/sqflite.dart';

class SceneTaskDao extends BaseDao {
  static const String table = 'tb_scene_tasks';

  Future<void> save(SceneTask task) async {
    task.updateTime = DateTime.now();
    await insert(
      table,
      task.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SceneTask>> selectByBook(int bookId) async {
    return queryList(
      table,
      mapper: SceneTask.fromRow,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'create_time DESC',
    );
  }

  Future<List<SceneTask>> selectAll() async {
    return queryList(
      table,
      mapper: SceneTask.fromRow,
      orderBy: 'create_time DESC',
    );
  }

  Future<SceneTask?> selectById(String id) async {
    return querySingle(
      table,
      mapper: SceneTask.fromRow,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteById(String id) async {
    await delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// 只清理失败与已取消；已完成的任务留着看图。
  Future<void> deleteFinishedByBook(int bookId) async {
    await delete(
      table,
      where: "book_id = ? AND status IN ('failed', 'cancelled')",
      whereArgs: [bookId],
    );
  }
}

final sceneTaskDao = SceneTaskDao();
