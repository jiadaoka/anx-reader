import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/scene_illustration.dart';
import 'package:sqflite/sqflite.dart';

class SceneIllustrationDao extends BaseDao {
  static const String table = 'tb_scene_illustrations';

  Future<void> save(SceneIllustration illustration) async {
    illustration.updateTime = DateTime.now();
    await insert(
      table,
      illustration.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SceneIllustration>> selectAll() async {
    return queryList(
      table,
      mapper: SceneIllustration.fromRow,
      orderBy: 'create_time DESC',
    );
  }

  Future<List<SceneIllustration>> selectByBook(int bookId) async {
    return queryList(
      table,
      mapper: SceneIllustration.fromRow,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'create_time DESC',
    );
  }

  Future<void> deleteById(String id) async {
    await delete(table, where: 'id = ?', whereArgs: [id]);
  }
}

final sceneIllustrationDao = SceneIllustrationDao();
