import 'dart:convert';

import 'package:anx_reader/enums/scene_character_field.dart';
import 'package:anx_reader/models/scene_character.dart';
import 'package:anx_reader/service/scene_image/prompt_engine.dart';
import 'package:anx_reader/service/scene_image/prompt_protocol.dart';
import 'package:langchain_core/chat_models.dart';

enum CharacterGenerationAction { all, bioOnly, promptOnly }

class CharacterGenerationResult {
  CharacterGenerationResult({
    this.keywords,
    this.bio,
    this.promptFields,
  });

  /// 仅「全部」返回；来自片段里明确出现的称呼。
  final List<String>? keywords;

  /// 仅「全部」与「只简介」返回。
  final String? bio;

  /// 仅「全部」与「简介→提示词」返回；包含全部七项键，未知字段为空串。
  final Map<String, String>? promptFields;
}

class CharacterGenerationException implements Exception {
  CharacterGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

const Duration _characterGenerationTimeout = Duration(minutes: 3);

/// 按角色片段或已有简介生成角色档案内容。
///
/// 只读 [character] 现有数据，不写库；是否覆盖由调用方确认后应用。
Future<CharacterGenerationResult> generateCharacterData({
  required CharacterGenerationAction action,
  required SceneCharacter character,
}) async {
  try {
    ensureSceneAiConfigured();
  } on ScenePromptException catch (e) {
    throw CharacterGenerationException(e.message);
  }

  final fragments = character.fragments
      .map((fragment) => fragment.text.trim())
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
  final bio = character.bio.trim();

  if ((action == CharacterGenerationAction.all ||
          action == CharacterGenerationAction.bioOnly) &&
      fragments.isEmpty) {
    throw CharacterGenerationException('还没有片段，无法从片段生成');
  }
  if (action == CharacterGenerationAction.promptOnly && bio.isEmpty) {
    throw CharacterGenerationException('角色简介为空，无法从简介生成提示词');
  }

  final messages = <ChatMessage>[
    ChatMessage.system(_systemPrompt(action)),
    ChatMessage.humanText(_userPrompt(
      action: action,
      character: character,
      fragments: fragments,
      bio: bio,
    )),
  ];

  final String answer;
  try {
    answer = await generateSceneAiAnswer(
      messages,
      timeout: _characterGenerationTimeout,
    );
  } on ScenePromptException catch (e) {
    throw CharacterGenerationException(e.message);
  }

  final jsonText = extractSceneJsonObject(answer);
  if (jsonText == null) {
    throw CharacterGenerationException('模型回复里没有可解析的 JSON');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    throw CharacterGenerationException('模型返回的 JSON 无法解析：${e.message}');
  }
  if (decoded is! Map) {
    throw CharacterGenerationException('模型返回的不是单个 JSON 对象');
  }

  switch (action) {
    case CharacterGenerationAction.all: {
      final keywords = _readKeywords(decoded['keywords']);
      if (keywords.isEmpty) {
        throw CharacterGenerationException('没有从片段里识别到角色称呼');
      }
      final generatedBio = _readString(decoded['bio']);
      final fields = _readPromptFields(decoded['promptFields']);
      if (generatedBio.isEmpty && !_hasAnyField(fields)) {
        throw CharacterGenerationException('没有从片段里提取到外貌信息');
      }
      return CharacterGenerationResult(
        keywords: keywords,
        bio: generatedBio,
        promptFields: fields,
      );
    }
    case CharacterGenerationAction.bioOnly: {
      final generatedBio = _readString(decoded['bio']);
      if (generatedBio.isEmpty) {
        throw CharacterGenerationException('没有从片段里提取到外貌描述');
      }
      return CharacterGenerationResult(bio: generatedBio);
    }
    case CharacterGenerationAction.promptOnly: {
      final fields = _readPromptFields(decoded['promptFields']);
      if (!_hasAnyField(fields)) {
        throw CharacterGenerationException('没有从简介里提取到外貌信息');
      }
      return CharacterGenerationResult(promptFields: fields);
    }
  }
  throw CharacterGenerationException('未知的生成动作');
}

String _systemPrompt(CharacterGenerationAction action) {
  final common = r'''你是小说角色档案整理员。只依据【材料】里明确写出的事实整理角色，不编造、不推测、不补充材料之外的知识。

输出一个 JSON 对象，不要输出解释、Markdown 代码块或 JSON 以外的文字。

字段规则：
- bio：中文自然语言，只写角色外貌的提炼（年龄感、发色、瞳色、发型、体型、服饰基调、稳定特征），不写性格、关系、剧情或能力。材料没有外貌信息就填空字符串。
- promptFields：固定七个键 hairColor、eyeColor、hairstyle、body、age、outfit、marks。值用英文 danbooru 风格短 tag：小写、空格分词，不要下划线，不要完整句子，不要质量词；材料没写就填空字符串。
- keywords：只取材料里实际出现的该角色姓名或称呼，原样保留，不要推断材料里没有的称呼；去重后输出数组。
- 不要把叙述者、作者、物品名或作品名当成角色称呼。

''';

  switch (action) {
    case CharacterGenerationAction.all:
      return common +
          r'''本次任务：从【角色片段】重写关键字、角色简介、角色提示词三块。
只输出这个形状：
{"keywords":["称呼1","称呼2"],"bio":"中文外貌提炼","promptFields":{"hairColor":"","eyeColor":"","hairstyle":"","body":"","age":"","outfit":"","marks":""}}''';
    case CharacterGenerationAction.bioOnly:
      return common +
          r'''本次任务：只从【角色片段】重写角色简介（外貌提炼），不输出关键字、不输出角色提示词。
只输出这个形状：
{"bio":"中文外貌提炼"}''';
    case CharacterGenerationAction.promptOnly:
      return common +
          r'''本次任务：只依据【角色简介】填写七个角色提示词字段，不输出简介、不输出关键字。
只输出这个形状：
{"promptFields":{"hairColor":"","eyeColor":"","hairstyle":"","body":"","age":"","outfit":"","marks":""}}''';
  }
  throw CharacterGenerationException('未知的生成动作');
}

String _userPrompt({
  required CharacterGenerationAction action,
  required SceneCharacter character,
  required List<String> fragments,
  required String bio,
}) {
  if (action == CharacterGenerationAction.promptOnly) {
    return '【角色】\n${character.name}\n\n【角色简介】\n$bio';
  }

  final buffer = StringBuffer()
    ..writeln('【角色】')
    ..writeln(character.name)
    ..writeln()
    ..writeln('【角色片段】');
  for (var i = 0; i < fragments.length; i++) {
    buffer.writeln('${i + 1}. ${fragments[i]}');
  }
  return buffer.toString().trimRight();
}

String _readString(Object? raw) => raw is String ? raw.trim() : '';

List<String> _readKeywords(Object? raw) {
  if (raw is! List) return const [];
  final result = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    final value = item.trim();
    if (value.isEmpty || result.contains(value)) continue;
    result.add(value);
  }
  return result;
}

Map<String, String> _readPromptFields(Object? raw) {
  final source = raw is Map ? raw : const {};
  final result = <String, String>{};
  for (final field in SceneCharacterField.values) {
    final value = source[field.code];
    result[field.code] = value is String ? value.trim() : '';
  }
  return result;
}

bool _hasAnyField(Map<String, String> fields) =>
    fields.values.any((value) => value.isNotEmpty);
