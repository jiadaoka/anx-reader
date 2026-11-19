import 'dart:async';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/ai_provider.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:anx_reader/service/ai/ai_key_rotator.dart';
import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/service/scene_image/prompt_base.dart';
import 'package:anx_reader/service/scene_image/prompt_protocol.dart';
import 'package:anx_reader/utils/ai_reasoning_parser.dart';
import 'package:langchain_core/chat_models.dart';

const Duration scenePromptTimeout = Duration(minutes: 5);

class ScenePromptException implements Exception {
  ScenePromptException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 用 app 现有 AI 服务生成一段提示词。
///
/// 四段 system 文本留空即用 [prompt_base.dart] 的内置文本；破限受总开关控制。
/// 失败抛 [ScenePromptException]，[message] 是可直接展示的原因。
Future<ScenePromptResult> generateScenePrompt({
  required String excerpt,
  required String supplement,
  required String contextBefore,
  required String contextAfter,
  required bool contextComplete,
  required List<SceneTaskCharacterRef> refs,
}) async {
  _ensureAiConfigured();

  final prefs = Prefs();
  final messages = <ChatMessage>[];
  if (prefs.scenePromptJailbreakEnabled) {
    messages.add(ChatMessage.system(_orBuiltin(
      prefs.scenePromptJailbreakText,
      sceneJailbreakPrompt,
    )));
  }
  messages.add(ChatMessage.system(_orBuiltin(
    prefs.scenePromptSpecText,
    scenePromptSpec,
  )));
  messages.add(ChatMessage.system(_orBuiltin(
    prefs.scenePromptContractText,
    scenePromptContract,
  )));
  messages.add(ChatMessage.system(_orBuiltin(
    prefs.scenePromptThinkingText,
    sceneThinkingList,
  )));
  messages.add(ChatMessage.humanText(buildSceneUserMessage(
    excerpt: excerpt,
    supplement: supplement,
    contextBefore: contextBefore,
    contextAfter: contextAfter,
    contextComplete: contextComplete,
    refs: refs,
  )));

  String? lastChunk;
  try {
    final stream = aiGenerateStream(messages).timeout(scenePromptTimeout);
    await for (final chunk in stream) {
      if (chunk.startsWith('Error: ')) {
        throw ScenePromptException('AI 服务返回错误：${chunk.substring(7)}');
      }
      lastChunk = chunk;
    }
  } on ScenePromptException {
    rethrow;
  } on TimeoutException {
    throw ScenePromptException('AI 服务响应超时');
  } catch (e) {
    throw ScenePromptException('AI 请求失败：$e');
  }

  if (lastChunk == null || lastChunk.trim().isEmpty) {
    throw ScenePromptException('AI 服务没有返回内容');
  }

  final answer = splitReasoningEnvelope(lastChunk).answerContent.trim();
  if (answer.isEmpty) {
    throw ScenePromptException('AI 只返回了思考过程，没有提示词正文');
  }

  try {
    return parseScenePromptResult(answer);
  } on ScenePromptFormatException catch (e) {
    throw ScenePromptException(e.message);
  }
}

String _orBuiltin(String custom, String builtin) {
  final trimmed = custom.trim();
  return trimmed.isEmpty ? builtin : custom;
}

void _ensureAiConfigured() {
  final provider = _selectedProvider();
  if (provider == null) {
    // 老版本可能只写了 aiConfig_<id>，aiGenerateStream 仍能读它。
    final legacy = Prefs().getAiConfig(Prefs().selectedAiService);
    if (legacy.isNotEmpty) {
      final key = (legacy['api_key'] ?? '').trim();
      final model = (legacy['model'] ?? '').trim();
      if (key.isEmpty) {
        throw ScenePromptException('当前 AI 服务缺少有效的 API Key');
      }
      if (model.isEmpty) {
        throw ScenePromptException('当前 AI 服务还没有选择模型');
      }
      return;
    }
    throw ScenePromptException('还没有配置 AI 服务，请到 设置 → AI 添加一个供应商');
  }
  if (!provider.enabled) {
    throw ScenePromptException('当前 AI 服务「${provider.title}」已被禁用');
  }
  if (provider.url.trim().isEmpty) {
    throw ScenePromptException('当前 AI 服务「${provider.title}」缺少服务地址');
  }
  if (provider.model.trim().isEmpty) {
    throw ScenePromptException('当前 AI 服务「${provider.title}」还没有选择模型');
  }
  if (!AiKeyRotator.hasValidKey(provider)) {
    throw ScenePromptException('当前 AI 服务「${provider.title}」缺少有效的 API Key');
  }
}

AiProvider? _selectedProvider() {
  final providers = <AiProvider>[];
  for (final raw in Prefs().getAiProviders()) {
    if (raw is! Map) continue;
    try {
      providers.add(AiProvider.fromJson(Map<String, dynamic>.from(raw)));
    } catch (_) {
      // 一条损坏的配置不应该让整个功能不可用。
    }
  }
  final selectedId = Prefs().selectedAiService;
  for (final provider in providers) {
    if (provider.id == selectedId) return provider;
  }
  for (final provider in providers) {
    if (provider.enabled) return provider;
  }
  return null;
}
