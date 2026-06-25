import 'dart:io';

import 'package:dyslexic_reader/core/storage/atomic_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('atomic_file_writer_test_');
  });

  tearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup of the unique temp dir we created.
    }
  });

  test(
    'writeString replaces an existing file and removes the temp file',
    () async {
      final target = File('${dir.path}/blocks.json');
      final tmp = File('${target.path}.tmp');
      await target.writeAsString('old cached document text');

      await AtomicFileWriter.writeString(target, 'new cached document text');

      expect(await target.readAsString(), 'new cached document text');
      expect(await tmp.exists(), isFalse);
    },
  );

  test(
    'writeString overwrites a stale temp file from an interrupted write',
    () async {
      final target = File('${dir.path}/blocks.json');
      final tmp = File('${target.path}.tmp');
      await target.writeAsString('previous complete cache');
      await tmp.writeAsString('stale partial cache');

      await AtomicFileWriter.writeString(target, 'replacement cache');

      expect(await target.readAsString(), 'replacement cache');
      expect(await tmp.exists(), isFalse);
    },
  );

  test(
    'writeBytes creates parent directories and writes bytes atomically',
    () async {
      final target = File('${dir.path}/nested/original.pdf');
      final tmp = File('${target.path}.tmp');

      await AtomicFileWriter.writeBytes(target, [1, 2, 3, 4]);

      expect(await target.readAsBytes(), [1, 2, 3, 4]);
      expect(await tmp.exists(), isFalse);
    },
  );
}
