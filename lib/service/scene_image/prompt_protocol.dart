import 'dart:convert';

import 'package:anx_reader/models/scene_task.dart';

/// 提示词引擎解析后的结果。模型按「提示词.md」的协议返回 JSON，
/// 宿主把 tag 与 nl 合成一段连续提示词送进工作流的 %prompt%。
class ScenePromptResult {
  ScenePromptResult({
    required this.tag,
    required this.nl,
    required this.negative,
    required this.sizeHint,
  });

  final String tag;
  final String nl;
  final String negative;

  /// portrait / landscape；模型没给或给了别的值就是空串。
  final String sizeHint;

  /// 工作流 %prompt% 用的单段文本。
  String get prompt => nl.isEmpty ? tag : '$tag\n$nl';

  /// 生图任务凭据里展示的提示词文本。
  String get displayPrompt => prompt;
}

class ScenePromptFormatException implements Exception {
  ScenePromptFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 按固定顺序拼运行时内容：补充说明 → 角色档案 → 上下文段 → 划中段。
/// 划中段贴最后，模型注意力最近。
String buildSceneUserMessage({
  required String excerpt,
  required String supplement,
  required String contextBefore,
  required String contextAfter,
  required bool contextComplete,
  required List<SceneTaskCharacterRef> refs,
}) {
  final buffer = StringBuffer();

  final trimmedSupplement = supplement.trim();
  if (trimmedSupplement.isNotEmpty) {
    buffer.writeln('【补充说明】');
    buffer.writeln(trimmedSupplement);
    buffer.writeln();
  }

  buffer.writeln('【角色档案】');
  if (refs.isEmpty) {
    buffer.writeln('本次没有命中已建档的角色，按正文与上下文编写。');
  } else {
    for (final ref in refs) {
      buffer.writeln('- ${ref.name}');
      if (ref.keywords.isNotEmpty) {
        buffer.writeln('  命中关键字：${ref.keywords.join('、')}');
      }
      if (ref.promptText.trim().isNotEmpty) {
        buffer.writeln('  角色提示词：${ref.promptText.trim()}');
      }
      if (ref.bio.trim().isNotEmpty) {
        buffer.writeln('  角色简介：${ref.bio.trim()}');
      }
      if (ref.fragments.isNotEmpty) {
        buffer.writeln('  角色片段：');
        for (var i = 0; i < ref.fragments.length; i++) {
          buffer.writeln('    ${i + 1}. ${ref.fragments[i]}');
        }
      }
    }
  }
  buffer.writeln();

  buffer.writeln('【上下文段】');
  if (contextBefore.trim().isEmpty) {
    buffer.writeln('前一段：（缺少）');
  } else {
    buffer.writeln('前一段：');
    buffer.writeln(contextBefore.trim());
  }
  if (contextAfter.trim().isEmpty) {
    buffer.writeln('后一段：（缺少）');
  } else {
    buffer.writeln('后一段：');
    buffer.writeln(contextAfter.trim());
  }
  if (!contextComplete) {
    buffer.writeln('（上下文不足：缺少的段落已标注）');
  }
  buffer.writeln();

  buffer.writeln('【划中段】');
  buffer.writeln(excerpt.trim());

  return buffer.toString().trimRight();
}

/// 从模型回复里取 JSON。容忍 <thinking>、代码块、前后废话。
ScenePromptResult parseScenePromptResult(String raw) {
  final withoutThinking = _stripThinking(raw).trim();
  if (withoutThinking.isEmpty) {
    throw ScenePromptFormatException('模型没有返回内容');
  }

  final block = _firstCodeBlock(withoutThinking);
  final candidate = block ?? withoutThinking;
  final jsonText = _firstJsonObject(candidate);
  if (jsonText == null) {
    throw ScenePromptFormatException('模型回复里没有可解析的 JSON 对象');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    throw ScenePromptFormatException('模型返回的 JSON 无法解析：${e.message}');
  }
  if (decoded is! Map) {
    throw ScenePromptFormatException('模型返回的不是单个 JSON 对象');
  }

  final tag = (decoded['tag'] as String? ?? '').trim();
  if (tag.isEmpty) {
    throw ScenePromptFormatException('模型没有返回提示词 tag');
  }
  final nl = (decoded['nl'] as String? ?? '').trim();
  final negative = (decoded['negative'] as String? ?? '').trim();
  final rawSize = (decoded['size'] as String? ?? '').trim().toLowerCase();
  final sizeHint = rawSize == 'portrait' || rawSize == 'landscape' ? rawSize : '';

  return ScenePromptResult(
    tag: tag,
    nl: nl,
    negative: negative,
    sizeHint: sizeHint,
  );
}

String _stripThinking(String text) {
  var result = text;
  result = result.replaceAll(
    RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(
    RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
    '',
  );
  return result;
}

String? _firstCodeBlock(String text) {
  final match = RegExp(r'```(?:json)?\s*\r?\n?([\s\S]*?)```').firstMatch(text);
  final content = match?.group(1)?.trim() ?? '';
  return content.isEmpty ? null : content;
}

/// 扫第一个配平的花括号对象，跳过字符串里的括号与转义。
String? _firstJsonObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return null;
}
