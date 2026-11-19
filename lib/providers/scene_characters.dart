import 'package:anx_reader/dao/scene_character.dart';
import 'package:anx_reader/models/scene_character.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sceneCharactersProvider =
    FutureProvider.family<List<SceneCharacter>, int>((ref, bookId) async {
  return sceneCharacterDao.selectWithFragmentsByBook(bookId);
});
