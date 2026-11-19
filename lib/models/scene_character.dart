import 'dart:convert';

import 'package:anx_reader/enums/scene_character_field.dart';

/// 按书归档的角色档案。只有 [name] 必填，其余四块都可以留空。
class SceneCharacter {
  int? id;
  int bookId;
  String name;

  /// 正文命中任一关键字，就带上该角色的提示词与片段。
  List<String> keywords;

  /// 中文自然语言简介，可手改。
  String bio;

  /// 七项角色提示词，键是 [SceneCharacterField.code]，值为空表示未知。
  Map<String, String> promptFields;

  /// 由 DAO 单独查询后挂上，不属于角色表本身。
  List<SceneCharacterFragment> fragments;
  DateTime createTime;
  DateTime updateTime;

  SceneCharacter({
    this.id,
    required this.bookId,
    required this.name,
    List<String>? keywords,
    this.bio = '',
    Map<String, String>? promptFields,
    List<SceneCharacterFragment>? fragments,
    DateTime? createTime,
    DateTime? updateTime,
  })  : keywords = keywords ?? <String>[],
        promptFields = promptFields ?? <String, String>{},
        fragments = fragments ?? <SceneCharacterFragment>[],
        createTime = createTime ?? DateTime.now(),
        updateTime = updateTime ?? DateTime.now();

  /// 按字段顺序拼成一段提示词，空的字段不拼。
  String get promptText {
    final parts = <String>[];
    for (final field in SceneCharacterField.values) {
      final value = promptFields[field.code]?.trim() ?? '';
      if (value.isNotEmpty) parts.add(value);
    }
    return parts.join(', ');
  }

  Map<String, Object?> toRow() => {
        'book_id': bookId,
        'name': name,
        'keywords': jsonEncode(keywords),
        'bio': bio,
        'prompt_fields': jsonEncode(promptFields),
        'create_time': createTime.toIso8601String(),
        'update_time': updateTime.toIso8601String(),
      };

  factory SceneCharacter.fromRow(Map<String, dynamic> row) {
    return SceneCharacter(
      id: (row['id'] as num?)?.toInt(),
      bookId: (row['book_id'] as num?)?.toInt() ?? -1,
      name: row['name'] as String? ?? '',
      keywords: _stringList(row['keywords']),
      bio: row['bio'] as String? ?? '',
      promptFields: _stringMap(row['prompt_fields']),
      createTime:
          DateTime.tryParse(row['create_time'] as String? ?? '') ??
              DateTime.now(),
      updateTime:
          DateTime.tryParse(row['update_time'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// 划词归入角色的原文片段；原文只读，带来源章段。
class SceneCharacterFragment {
  int? id;
  int characterId;
  String text;
  String cfi;
  String chapter;

  /// 0..1，来源位置在书里的阅读进度。
  double progress;
  DateTime createTime;

  SceneCharacterFragment({
    this.id,
    required this.characterId,
    required this.text,
    this.cfi = '',
    this.chapter = '',
    this.progress = 0,
    DateTime? createTime,
  }) : createTime = createTime ?? DateTime.now();

  Map<String, Object?> toRow() => {
        'character_id': characterId,
        'text': text,
        'cfi': cfi,
        'chapter': chapter,
        'progress': progress,
        'create_time': createTime.toIso8601String(),
      };

  factory SceneCharacterFragment.fromRow(Map<String, dynamic> row) {
    return SceneCharacterFragment(
      id: (row['id'] as num?)?.toInt(),
      characterId: (row['character_id'] as num?)?.toInt() ?? -1,
      text: row['text'] as String? ?? '',
      cfi: row['cfi'] as String? ?? '',
      chapter: row['chapter'] as String? ?? '',
      progress: (row['progress'] as num?)?.toDouble() ?? 0,
      createTime:
          DateTime.tryParse(row['create_time'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! String || raw.isEmpty) return <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>[];
    return decoded.whereType<String>().toList(growable: false);
  } catch (_) {
    return <String>[];
  }
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! String || raw.isEmpty) return <String, String>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, String>{};
    final result = <String, String>{};
    decoded.forEach((key, value) {
      if (key is String && value is String) result[key] = value;
    });
    return result;
  } catch (_) {
    return <String, String>{};
  }
}
