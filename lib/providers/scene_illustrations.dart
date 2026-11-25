import 'dart:io';

import 'package:anx_reader/dao/scene_illustration.dart';
import 'package:anx_reader/enums/scene_illustration.dart';
import 'package:anx_reader/models/scene_illustration.dart';
import 'package:anx_reader/models/scene_task.dart';
import 'package:anx_reader/service/book_player/book_player_server.dart';
import 'package:anx_reader/service/scene_image/image_store.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sceneIllustrationStoreProvider =
    Provider<SceneIllustrationStore>((ref) => SceneIllustrationStore.instance);

/// 正文插图的内存态 + 落库。按书归属，一个来源段落最多一条记录。
class SceneIllustrationStore extends ChangeNotifier {
  SceneIllustrationStore._();

  static final SceneIllustrationStore instance = SceneIllustrationStore._();

  final Map<String, SceneIllustration> _records = {};

  bool _loaded = false;
  Future<void>? _loadingFuture;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final pending = _loadingFuture;
    if (pending != null) return pending;
    final future = _loadFromDb();
    _loadingFuture = future;
    await future;
  }

  Future<void> _loadFromDb() async {
    try {
      final records = await sceneIllustrationDao.selectAll();
      for (final record in records) {
        _records[record.id] = record;
      }
    } catch (e) {
      AnxLog.warning('SceneImage: load illustrations failed: $e');
    } finally {
      _loaded = true;
      _loadingFuture = null;
      notifyListeners();
    }
  }

  List<SceneIllustration> recordsForBook(int bookId) {
    final records =
        _records.values.where((r) => r.bookId == bookId).toList(growable: false);
    records.sort((a, b) => a.createTime.compareTo(b.createTime));
    return records;
  }

  SceneIllustration? byId(String id) => _records[id];

  SceneIllustration? forAnchor({
    required int bookId,
    required String sectionHref,
    required int paragraphIndex,
    required String paragraphText,
  }) {
    if (sectionHref.isEmpty || paragraphText.isEmpty) return null;
    for (final record in _records.values) {
      if (record.sameAnchor(
        bookId: bookId,
        sectionHref: sectionHref,
        paragraphIndex: paragraphIndex,
        paragraphText: paragraphText,
      )) {
        return record;
      }
    }
    return null;
  }

  /// 任务来源段落当前显示的插图（不看是哪条任务插入的）。
  SceneIllustration? forTaskAnchor(SceneTask task) {
    return forAnchor(
      bookId: task.bookId,
      sectionHref: task.sourceSectionHref,
      paragraphIndex: task.sourceParagraphIndex,
      paragraphText: task.sourceParagraphText,
    );
  }

  /// 当前任务、当前版本是否就是正文里显示的那一张。
  bool isShowing(SceneTask task, SceneTaskHistoryEntry? entry) {
    if (entry == null) return false;
    final record = forTaskAnchor(task);
    return record != null &&
        record.isValid &&
        record.taskId == task.id &&
        record.entryId == entry.id;
  }

  /// 插入 / 替换：同一来源段落只保留一条记录，图片文件仍与任务历史共用。
  Future<SceneIllustration?> insertFromTask({
    required SceneTask task,
    required SceneTaskHistoryEntry entry,
    required SceneIllustrationMode mode,
  }) async {
    if (task.sourceSectionHref.isEmpty || task.sourceParagraphText.isEmpty) {
      return null;
    }
    if (entry.imagePath.isEmpty) return null;

    await ensureLoaded();

    final existing = forAnchor(
      bookId: task.bookId,
      sectionHref: task.sourceSectionHref,
      paragraphIndex: task.sourceParagraphIndex,
      paragraphText: task.sourceParagraphText,
    );
    final now = DateTime.now();
    final record = existing ??
        SceneIllustration(
          id: newSceneIllustrationId(),
          bookId: task.bookId,
          sectionHref: task.sourceSectionHref,
          createTime: now,
        );

    record.bookId = task.bookId;
    record.sectionHref = task.sourceSectionHref;
    record.sectionIndex = task.sourceSectionIndex;
    record.paragraphIndex = task.sourceParagraphIndex;
    record.paragraphText = task.sourceParagraphText;
    record.excerpt = task.excerpt;
    record.taskId = task.id;
    record.entryId = entry.id;
    record.imagePath = entry.imagePath;
    final pixelSize = await sceneImagePixelSize(entry.imagePath);
    record.width = pixelSize?.width ?? entry.width;
    record.height = pixelSize?.height ?? entry.height;
    record.mode = mode;
    record.status = SceneAnchorStatus.valid;
    record.updateTime = now;

    _records[record.id] = record;
    try {
      await sceneIllustrationDao.save(record);
    } catch (e) {
      AnxLog.warning('SceneImage: save illustration ${record.id} failed: $e');
    }
    notifyListeners();
    return record;
  }

  Future<void> remove(String id) async {
    final record = _records.remove(id);
    if (record == null) return;
    try {
      await sceneIllustrationDao.deleteById(id);
    } catch (e) {
      AnxLog.warning('SceneImage: delete illustration $id failed: $e');
    }
    notifyListeners();
  }

  /// 锚点对不上：不显示，不再重试；记录保留，任务卡据此标失效。
  Future<void> markInvalid(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      final record = _records[id];
      if (record == null || record.status == SceneAnchorStatus.invalid) {
        continue;
      }
      record.status = SceneAnchorStatus.invalid;
      record.updateTime = DateTime.now();
      changed = true;
      try {
        await sceneIllustrationDao.save(record);
      } catch (e) {
        AnxLog.warning('SceneImage: update illustration $id failed: $e');
      }
    }
    if (changed) notifyListeners();
  }

  /// 阅读器 JS 的入参；[enabled] 为 false 时推空表，记录与图片都不删。
  Map<String, Object?> buildPayloadForBook({
    required int bookId,
    required bool enabled,
    required String loadingText,
    required String unavailableText,
  }) {
    final images = <Map<String, Object?>>[];
    if (enabled) {
      for (final record in recordsForBook(bookId)) {
        if (!record.isValid ||
            record.sectionHref.isEmpty ||
            record.paragraphText.isEmpty) {
          continue;
        }
        images.add({
          'id': record.id,
          'sectionHref': record.sectionHref,
          'paragraphIndex': record.paragraphIndex,
          'paragraphText': record.paragraphText,
          'imageUrl': _illustrationUrl(record.imagePath),
          'width': record.width ?? 0,
          'height': record.height ?? 0,
          'missing': !_imageExists(record.imagePath),
        });
      }
    }
    return {
      'images': images,
      'loading': loadingText,
      'unavailable': unavailableText,
    };
  }

  String _illustrationUrl(String relative) {
    if (relative.isEmpty) return '';
    String base;
    try {
      base = 'http://127.0.0.1:${Server().port}';
    } catch (_) {
      return '';
    }
    final encoded = Uri.encodeComponent(relative).replaceAll('%2F', '/');
    return '$base/illustration/$encoded';
  }

  bool _imageExists(String relative) {
    if (relative.isEmpty) return false;
    try {
      return File(sceneImageFullPath(relative)).existsSync();
    } catch (_) {
      return false;
    }
  }
}
