import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_file_dialog_platform_interface.dart';

/// An implementation of [FlutterFileDialogPlatform] that uses method channels.
class MethodChannelFlutterFileDialog extends FlutterFileDialogPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_file_dialog');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
