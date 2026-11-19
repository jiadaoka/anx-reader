import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/scene_character.dart';

class SceneCharacterDao extends BaseDao {
  static const String characterTable = 'tb_scene_characters';
  static const String fragmentTable = 'tb_scene_character_fragments';

  Future<int> saveCharacter(SceneCharacter character) async {
    character.updateTime = DateTime.now();
    if (character.id != null) {
      await update(
        characterTable,
        character.toRow(),
        where: 'id = ?',
        whereArgs: [character.id],
      );
      return character.id!;
    }
    final id = await insert(characterTable, character.toRow());
    character.id = id;
    return id;
  }

  Future<List<SceneCharacter>> selectByBook(int bookId) async {
    return queryList(
      characterTable,
      mapper: SceneCharacter.fromRow,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'create_time ASC',
    );
  }

  Future<SceneCharacter?> selectById(int id) async {
    return querySingle(
      characterTable,
      mapper: SceneCharacter.fromRow,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SceneCharacter>> selectWithFragmentsByBook(int bookId) async {
    final characters = await selectByBook(bookId);
    for (final character in characters) {
      if (character.id != null) {
        character.fragments = await selectFragments(character.id!);
      }
    }
    return characters;
  }

  Future<void> deleteCharacter(int id) async {
    await transaction((txn) async {
      await txn.delete(
        fragmentTable,
        where: 'character_id = ?',
        whereArgs: [id],
      );
      await txn.delete(characterTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> saveFragment(SceneCharacterFragment fragment) async {
    if (fragment.id != null) {
      await update(
        fragmentTable,
        fragment.toRow(),
        where: 'id = ?',
        whereArgs: [fragment.id],
      );
      return fragment.id!;
    }
    final id = await insert(fragmentTable, fragment.toRow());
    fragment.id = id;
    return id;
  }

  Future<List<SceneCharacterFragment>> selectFragments(int characterId) async {
    return queryList(
      fragmentTable,
      mapper: SceneCharacterFragment.fromRow,
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'create_time ASC',
    );
  }

  Future<void> deleteFragment(int id) async {
    await delete(fragmentTable, where: 'id = ?', whereArgs: [id]);
  }
}

final sceneCharacterDao = SceneCharacterDao();
