import 'package:flutter/services.dart';

/// A file the app was opened with via an open-with (VIEW) or share (SEND) intent.
class IncomingFile {
  const IncomingFile({required this.path, required this.name});
  final String path;
  final String name;
}

/// Dart side of the native open-with / share bridge. See
/// `android/app/src/main/kotlin/.../MainActivity.kt`.
class IncomingFileChannel {
  const IncomingFileChannel();

  static const MethodChannel _channel = MethodChannel('dyslexic_reader/incoming');

  /// Returns the file the app was opened with, if any, and clears it so it is
  /// handled only once. Safe to call repeatedly (e.g. on app resume).
  Future<IncomingFile?> consume() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('consumeInitialFile');
      if (res == null) return null;
      final path = res['path'] as String?;
      final name = res['name'] as String?;
      if (path == null || name == null || path.isEmpty) return null;
      return IncomingFile(path: path, name: name);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
