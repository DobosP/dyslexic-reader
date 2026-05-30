import 'package:flutter/services.dart';

/// A file the app was opened with (VIEW/SEND intent), or an [error] explaining
/// why it couldn't be opened (surfaced to the user for diagnosis).
class IncomingFile {
  const IncomingFile({this.path, this.name, this.error});

  final String? path;
  final String? name;
  final String? error;

  bool get isError => error != null;
  bool get hasFile => path != null && name != null && path!.isNotEmpty;
}

/// Dart side of the native open-with / share bridge. See MainActivity.kt.
class IncomingFileChannel {
  const IncomingFileChannel();

  static const MethodChannel _channel = MethodChannel('dyslexic_reader/incoming');

  /// Returns the file the app was opened with (or an error), clearing it so it
  /// is handled once. Safe to call repeatedly (e.g. on app resume).
  Future<IncomingFile?> consume() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('consumeInitialFile');
      if (res == null) return null;
      final error = res['error'] as String?;
      if (error != null) return IncomingFile(error: error);
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
