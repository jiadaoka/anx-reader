import 'package:anx_reader/dao/scene_character.dart';
import 'package:anx_reader/models/scene_character.dart';
import 'package:anx_reader/models/scene_task.dart';

/// 关键字命中判定：精确子串、大小写不敏感。
///
/// 命中顺序按在划中段出现的先后；划中段没出现、只在上下文段出现的角色排在后面。
Future<List<SceneTaskCharacterRef>> resolveSceneCharacters({
  required int bookId,
  required String excerpt,
  required String contextBefore,
  required String contextAfter,
}) async {
  final characters =
      await sceneCharacterDao.selectWithFragmentsByBook(bookId);
  if (characters.isEmpty) return <SceneTaskCharacterRef>[];

  final haystacks = <String>[
    excerpt,
    '$contextBefore\n$contextAfter',
  ];

  final hits = <_CharacterHit>[];
  for (final character in characters) {
    final keywords = character.keywords
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (keywords.isEmpty) continue;

    final matched = <String>[];
    var bestPosition = -1;
    var firstIndex = -1;
    for (var i = 0; i < haystacks.length; i++) {
      final text = haystacks[i].toLowerCase();
      if (text.isEmpty) continue;
      for (final keyword in keywords) {
        final position = text.indexOf(keyword.toLowerCase());
        if (position < 0) continue;
        if (!matched.contains(keyword)) matched.add(keyword);
        final weighted = i * 1000000 + position;
        if (bestPosition < 0 || weighted < bestPosition) {
          bestPosition = weighted;
          firstIndex = i;
        }
      }
    }
    if (matched.isEmpty) continue;

    hits.add(_CharacterHit(
      character: character,
      matchedKeywords: matched,
      position: bestPosition,
      inExcerpt: firstIndex == 0,
    ));
  }

  hits.sort((a, b) {
    if (a.inExcerpt != b.inExcerpt) return a.inExcerpt ? -1 : 1;
    return a.position.compareTo(b.position);
  });

  return hits.map((hit) {
    final character = hit.character;
    return SceneTaskCharacterRef(
      name: character.name,
      keywords: hit.matchedKeywords,
      promptText: character.promptText,
      bio: character.bio,
      fragments: character.fragments
          .map((fragment) => fragment.text)
          .toList(growable: false),
    );
  }).toList(growable: false);
}

class _CharacterHit {
  _CharacterHit({
    required this.character,
    required this.matchedKeywords,
    required this.position,
    required this.inExcerpt,
  });

  final SceneCharacter character;
  final List<String> matchedKeywords;
  final int position;
  final bool inExcerpt;
}
