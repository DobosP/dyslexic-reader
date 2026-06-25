import 'dart:io';

/// Writes a single file through a flushed temp file and atomic rename.
///
/// This avoids truncating an existing user-data file before the replacement is
/// complete. The target and temp file live in the same directory so the final
/// rename is atomic on the app's local filesystem.
class AtomicFileWriter {
  const AtomicFileWriter._();

  static Future<void> writeString(File target, String data) async {
    await _write(target, (tmp) => tmp.writeAsString(data, flush: true));
  }

  static Future<void> writeBytes(File target, List<int> bytes) async {
    await _write(target, (tmp) => tmp.writeAsBytes(bytes, flush: true));
  }

  static Future<void> _write(
    File target,
    Future<File> Function(File tmp) writeTmp,
  ) async {
    final parent = target.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final tmp = File('${target.path}.tmp');
    await writeTmp(tmp);
    await tmp.rename(target.path);
  }
}
