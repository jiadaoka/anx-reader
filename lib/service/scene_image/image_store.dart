import 'dart:convert';
import 'dart:io';

import 'package:anx_reader/utils/get_path/get_base_path.dart';
import 'package:path/path.dart' as p;

/// 生图结果落在应用私有目录；数据库只存相对路径。
const String sceneImageDir = 'scene_image';

Future<String> saveSceneImage({
  required int bookId,
  required String taskId,
  required List<int> bytes,
  required String mimeType,
}) async {
  final extension = _extensionFor(mimeType);
  final relative =
      '$sceneImageDir/$bookId/${taskId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
  final file = File(getBasePath(relative));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return relative;
}

String sceneImageFullPath(String relative) => getBasePath(relative);

Future<File?> sceneImageFile(String relative) async {
  if (relative.isEmpty) return null;
  final file = File(getBasePath(relative));
  if (!await file.exists()) return null;
  return file;
}

/// app 现有看图页只收 base64 data URL，这里把私有目录里的图转成它要的形状。
Future<String?> sceneImageDataUrl(String relative) async {
  final file = await sceneImageFile(relative);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final mimeType = _mimeFor(p.extension(relative).toLowerCase());
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

Future<void> deleteSceneImage(String relative) async {
  final file = await sceneImageFile(relative);
  if (file == null) return;
  try {
    await file.delete();
  } catch (_) {
    // 文件已经被删或暂时不可删；任务记录不因此失败。
  }
}

String _extensionFor(String mimeType) {
  switch (mimeType.toLowerCase()) {
    case 'image/jpeg':
    case 'image/jpg':
      return 'jpg';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    default:
      return 'png';
  }
}

String _mimeFor(String extension) {
  switch (extension) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    default:
      return 'image/png';
  }
}
