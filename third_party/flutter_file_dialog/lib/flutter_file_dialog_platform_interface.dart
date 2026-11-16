import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_file_dialog_method_channel.dart';

abstract class FlutterFileDialogPlatform extends PlatformInterface {
  /// Constructs a FlutterFileDialogPlatform.
  FlutterFileDialogPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterFileDialogPlatform _instance = MethodChannelFlutterFileDialog();

  /// The default instance of [FlutterFileDialogPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterFileDialog].
  static FlutterFileDialogPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterFileDialogPlatform] when
  /// they register themselves.
  static set instance(FlutterFileDialogPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
