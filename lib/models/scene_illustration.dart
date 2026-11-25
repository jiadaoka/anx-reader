import 'dart:math';

import 'package:anx_reader/enums/scene_illustration.dart';

/// 正文里的一张插图：引用某条生图任务历史里的某一版结果。
///
/// 每个来源段落一条；替换只改指向，不复制图片文件。
class SceneIllustration {
  String id;
  int bookId;

  /// 来源章节的 spine 标识（EPUB 的 manifest href）；锚点作用域。
  String sectionHref;
  int sectionIndex;

  /// 来源段在章节块元素里的序号，仅作定位提示，必须用 [paragraphText] 核对。
  int paragraphIndex;
  String paragraphText;

  /// 划中段原文，凭据里回溯用。
  String excerpt;

  String taskId;
  String entryId;
  String imagePath;
  int? width;
  int? height;

  SceneIllustrationMode mode;
  SceneAnchorStatus status;

  DateTime createTime;
  DateTime updateTime;

  SceneIllustration({
    required this.id,
    required this.bookId,
    required this.sectionHref,
    this.sectionIndex = -1,
    this.paragraphIndex = -1,
    this.paragraphText = '',
    this.excerpt = '',
    this.taskId = '',
    this.entryId = '',
    this.imagePath = '',
    this.width,
    this.height,
    this.mode = SceneIllustrationMode.auto,
    this.status = SceneAnchorStatus.valid,
    DateTime? createTime,
    DateTime? updateTime,
  })  : createTime = createTime ?? DateTime.now(),
        updateTime = updateTime ?? DateTime.now();

  bool get isValid => status == SceneAnchorStatus.valid;

  /// 同一个来源段落的判定：章 + 段序号 + 段文本。
  bool sameAnchor({
    required int bookId,
    required String sectionHref,
    required int paragraphIndex,
    required String paragraphText,
  }) {
    return this.bookId == bookId &&
        this.sectionHref == sectionHref &&
        this.paragraphIndex == paragraphIndex &&
        this.paragraphText == paragraphText;
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'book_id': bookId,
        'section_href': sectionHref,
        'section_index': sectionIndex,
        'paragraph_index': paragraphIndex,
        'paragraph_text': paragraphText,
        'excerpt': excerpt,
        'task_id': taskId,
        'entry_id': entryId,
        'image_path': imagePath,
        'width': width,
        'height': height,
        'insert_mode': mode.code,
        'anchor_status': status.code,
        'create_time': createTime.toIso8601String(),
        'update_time': updateTime.toIso8601String(),
      };

  factory SceneIllustration.fromRow(Map<String, dynamic> row) {
    return SceneIllustration(
      id: row['id'] as String? ?? '',
      bookId: (row['book_id'] as num?)?.toInt() ?? -1,
      sectionHref: row['section_href'] as String? ?? '',
      sectionIndex: (row['section_index'] as num?)?.toInt() ?? -1,
      paragraphIndex: (row['paragraph_index'] as num?)?.toInt() ?? -1,
      paragraphText: row['paragraph_text'] as String? ?? '',
      excerpt: row['excerpt'] as String? ?? '',
      taskId: row['task_id'] as String? ?? '',
      entryId: row['entry_id'] as String? ?? '',
      imagePath: row['image_path'] as String? ?? '',
      width: (row['width'] as num?)?.toInt(),
      height: (row['height'] as num?)?.toInt(),
      mode: SceneIllustrationMode.fromCode(row['insert_mode'] as String? ?? ''),
      status:
          SceneAnchorStatus.fromCode(row['anchor_status'] as String? ?? ''),
      createTime:
          DateTime.tryParse(row['create_time'] as String? ?? '') ??
              DateTime.now(),
      updateTime:
          DateTime.tryParse(row['update_time'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

final Random _sceneIllustrationRandom = Random();

String newSceneIllustrationId() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final suffix =
      _sceneIllustrationRandom.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  return '${micros}_$suffix';
}
