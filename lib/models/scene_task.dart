import 'dart:convert';
import 'dart:math';

import 'package:anx_reader/enums/scene_task_status.dart';
import 'package:anx_reader/enums/scene_task_type.dart';
import 'package:anx_reader/models/scene_workflow.dart';

/// 一次划词在提示词阶段命中的角色档案快照。
///
/// 任务落库后可能跨重启存在，角色档案之后被改名或删除都不回写这里。
class SceneTaskCharacterRef {
  String name;

  /// 命中的关键字，而不是角色档案里的全部关键字。
  List<String> keywords;

  /// 角色提示词七项拼成的一段文本。
  String promptText;
  String bio;

  /// 该角色当时引用的原文片段。
  List<String> fragments;

  SceneTaskCharacterRef({
    required this.name,
    List<String>? keywords,
    this.promptText = '',
    this.bio = '',
    List<String>? fragments,
  })  : keywords = keywords ?? <String>[],
        fragments = fragments ?? <String>[];

  Map<String, Object?> toJson() => {
        'name': name,
        'keywords': keywords,
        'promptText': promptText,
        'bio': bio,
        'fragments': fragments,
      };

  factory SceneTaskCharacterRef.fromJson(Map<String, dynamic> json) {
    return SceneTaskCharacterRef(
      name: json['name'] as String? ?? '',
      keywords: _stringList(json['keywords']),
      promptText: json['promptText'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      fragments: _stringList(json['fragments']),
    );
  }
}

/// 任务里的一次结果或一次提示词版本。
///
/// 提示词任务的一条历史只有一个 prompt；生图任务的一条历史有 imagePath 与出图参数。
class SceneTaskHistoryEntry {
  String id;
  SceneTaskStatus status;
  String prompt;
  String negative;
  String imagePath;
  int? width;
  int? height;
  int? seed;
  String workflowName;
  String failureReason;
  DateTime createTime;

  SceneTaskHistoryEntry({
    required this.id,
    required this.status,
    this.prompt = '',
    this.negative = '',
    this.imagePath = '',
    this.width,
    this.height,
    this.seed,
    this.workflowName = '',
    this.failureReason = '',
    required this.createTime,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'status': status.code,
        'prompt': prompt,
        'negative': negative,
        'imagePath': imagePath,
        'width': width,
        'height': height,
        'seed': seed,
        'workflowName': workflowName,
        'failureReason': failureReason,
        'createTime': createTime.toIso8601String(),
      };

  factory SceneTaskHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SceneTaskHistoryEntry(
      id: json['id'] as String? ?? '',
      status: SceneTaskStatus.fromCode(json['status'] as String? ?? ''),
      prompt: json['prompt'] as String? ?? '',
      negative: json['negative'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      seed: (json['seed'] as num?)?.toInt(),
      workflowName: json['workflowName'] as String? ?? '',
      failureReason: json['failureReason'] as String? ?? '',
      createTime:
          DateTime.tryParse(json['createTime'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// 提示词任务与生图任务共用的记录。按 [bookId] 归属，不跨书。
class SceneTask {
  String id;
  int bookId;
  String bookTitle;
  SceneTaskType type;
  SceneTaskStatus status;
  String excerpt;
  String chapter;
  String cfi;

  /// 0..1，来源位置在书里的阅读进度。
  double progress;

  /// 提示词任务：当前提示词；生图任务：提交时的提示词快照。
  String prompt;
  String negative;
  String supplement;
  String contextBefore;
  String contextAfter;
  bool contextComplete;

  /// 来源段落锚点：划中段起点所在段落。正文插图按它落位；
  /// 空值表示没有段信息，不参与插入（旧任务）。
  String sourceSectionHref;
  int sourceSectionIndex;
  int sourceParagraphIndex;
  String sourceParagraphText;

  /// 提示词引擎给出的画幅方向（portrait / landscape）；空表示没拿到。
  String sizeHint;

  /// 生图任务指向发起它的提示词任务。
  String? promptTaskId;

  int? workflowId;
  String workflowName;

  /// 提交生图时的工作流快照，重试也用它，不受之后的编辑影响。
  SceneWorkflow? workflowSnapshot;
  int? width;
  int? height;
  int? seed;
  String imagePath;
  String failureReason;
  List<SceneTaskCharacterRef> characterRefs;
  List<SceneTaskHistoryEntry> history;

  /// 生图排队时「前面还有几个」，只用于当前展示，不落库。
  int? queueAhead;
  DateTime createTime;
  DateTime updateTime;

  SceneTask({
    required this.id,
    required this.bookId,
    this.bookTitle = '',
    required this.type,
    this.status = SceneTaskStatus.queued,
    this.excerpt = '',
    this.chapter = '',
    this.cfi = '',
    this.progress = 0,
    this.prompt = '',
    this.negative = '',
    this.supplement = '',
    this.contextBefore = '',
    this.contextAfter = '',
    this.contextComplete = true,
    this.sourceSectionHref = '',
    this.sourceSectionIndex = -1,
    this.sourceParagraphIndex = -1,
    this.sourceParagraphText = '',
    this.sizeHint = '',
    this.promptTaskId,
    this.workflowId,
    this.workflowName = '',
    this.workflowSnapshot,
    this.width,
    this.height,
    this.seed,
    this.imagePath = '',
    this.failureReason = '',
    List<SceneTaskCharacterRef>? characterRefs,
    List<SceneTaskHistoryEntry>? history,
    DateTime? createTime,
    DateTime? updateTime,
  })  : characterRefs = characterRefs ?? <SceneTaskCharacterRef>[],
        history = history ?? <SceneTaskHistoryEntry>[],
        createTime = createTime ?? DateTime.now(),
        updateTime = updateTime ?? DateTime.now();

  bool get isPromptTask => type == SceneTaskType.prompt;

  bool get isImageTask => type == SceneTaskType.image;

  /// 历史按时间倒序，最新在前；界面「第 1 / N 版」以此为准。
  void addHistory(SceneTaskHistoryEntry entry) {
    history.add(entry);
    history.sort((a, b) => b.createTime.compareTo(a.createTime));
  }

  SceneTaskHistoryEntry? get latestHistory =>
      history.isEmpty ? null : history.first;

  Map<String, Object?> toRow() => {
        'id': id,
        'book_id': bookId,
        'book_title': bookTitle,
        'type': type.code,
        'status': status.code,
        'excerpt': excerpt,
        'chapter': chapter,
        'cfi': cfi,
        'progress': progress,
        'prompt': prompt,
        'negative': negative,
        'supplement': supplement,
        'context_before': contextBefore,
        'context_after': contextAfter,
        'context_complete': contextComplete ? 1 : 0,
        'source_section_href': sourceSectionHref,
        'source_section_index': sourceSectionIndex,
        'source_paragraph_index': sourceParagraphIndex,
        'source_paragraph_text': sourceParagraphText,
        'size_hint': sizeHint,
        'prompt_task_id': promptTaskId,
        'workflow_id': workflowId,
        'workflow_name': workflowName,
        'workflow_snapshot': workflowSnapshot == null
            ? null
            : jsonEncode(workflowSnapshot!.toSnapshot()),
        'width': width,
        'height': height,
        'seed': seed,
        'image_path': imagePath,
        'failure_reason': failureReason,
        'character_refs': jsonEncode(
          characterRefs.map((e) => e.toJson()).toList(growable: false),
        ),
        'history': jsonEncode(
          history.map((e) => e.toJson()).toList(growable: false),
        ),
        'create_time': createTime.toIso8601String(),
        'update_time': updateTime.toIso8601String(),
      };

  factory SceneTask.fromRow(Map<String, dynamic> row) {
    return SceneTask(
      id: row['id'] as String? ?? '',
      bookId: (row['book_id'] as num?)?.toInt() ?? -1,
      bookTitle: row['book_title'] as String? ?? '',
      type: SceneTaskType.fromCode(row['type'] as String? ?? ''),
      status: SceneTaskStatus.fromCode(row['status'] as String? ?? ''),
      excerpt: row['excerpt'] as String? ?? '',
      chapter: row['chapter'] as String? ?? '',
      cfi: row['cfi'] as String? ?? '',
      progress: (row['progress'] as num?)?.toDouble() ?? 0,
      prompt: row['prompt'] as String? ?? '',
      negative: row['negative'] as String? ?? '',
      supplement: row['supplement'] as String? ?? '',
      contextBefore: row['context_before'] as String? ?? '',
      contextAfter: row['context_after'] as String? ?? '',
      contextComplete: (row['context_complete'] as int? ?? 1) == 1,
      sourceSectionHref: row['source_section_href'] as String? ?? '',
      sourceSectionIndex: (row['source_section_index'] as num?)?.toInt() ?? -1,
      sourceParagraphIndex:
          (row['source_paragraph_index'] as num?)?.toInt() ?? -1,
      sourceParagraphText: row['source_paragraph_text'] as String? ?? '',
      sizeHint: row['size_hint'] as String? ?? '',
      promptTaskId: row['prompt_task_id'] as String?,
      workflowId: (row['workflow_id'] as num?)?.toInt(),
      workflowName: row['workflow_name'] as String? ?? '',
      workflowSnapshot: _decodeWorkflowSnapshot(row['workflow_snapshot']),
      width: (row['width'] as num?)?.toInt(),
      height: (row['height'] as num?)?.toInt(),
      seed: (row['seed'] as num?)?.toInt(),
      imagePath: row['image_path'] as String? ?? '',
      failureReason: row['failure_reason'] as String? ?? '',
      characterRefs: _decodeRefs(row['character_refs']),
      history: _decodeHistory(row['history']),
      createTime:
          DateTime.tryParse(row['create_time'] as String? ?? '') ?? DateTime.now(),
      updateTime:
          DateTime.tryParse(row['update_time'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return <String>[];
  return raw.whereType<String>().toList(growable: false);
}

List<SceneTaskCharacterRef> _decodeRefs(Object? raw) {
  if (raw is! String || raw.isEmpty) return <SceneTaskCharacterRef>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <SceneTaskCharacterRef>[];
    return decoded
        .whereType<Map>()
        .map((e) => SceneTaskCharacterRef.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  } catch (_) {
    return <SceneTaskCharacterRef>[];
  }
}

List<SceneTaskHistoryEntry> _decodeHistory(Object? raw) {
  if (raw is! String || raw.isEmpty) return <SceneTaskHistoryEntry>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <SceneTaskHistoryEntry>[];
    final entries = decoded
        .whereType<Map>()
        .map((e) => SceneTaskHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    entries.sort((a, b) => b.createTime.compareTo(a.createTime));
    return entries;
  } catch (_) {
    return <SceneTaskHistoryEntry>[];
  }
}

SceneWorkflow? _decodeWorkflowSnapshot(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return SceneWorkflow.fromSnapshot(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return null;
  }
}

final Random _sceneIdRandom = Random();

String newSceneTaskId() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final suffix = _sceneIdRandom.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  return '${micros}_$suffix';
}
