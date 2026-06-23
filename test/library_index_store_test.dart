import 'dart:io';

import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/features/library/library_index_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies that [LibraryIndexStore] writes the library index atomically and
/// recovers from a torn/corrupt `index.json` instead of silently presenting an
/// empty library. These tests drive the real `dart:io` file APIs against a
/// throwaway temp directory (the Dart VM test runner supports this without a
/// device or platform channels).
void main() {
  late Directory dir;
  late File index;
  late File backup;
  late File corrupt;
  late File tmp;
  late LibraryIndexStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lib_index_store_test_');
    index = File('${dir.path}/index.json');
    backup = File('${index.path}.bak');
    corrupt = File('${index.path}.corrupt');
    tmp = File('${index.path}.tmp');
    store = LibraryIndexStore(index);
  });

  tearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup of the unique temp dir we created.
    }
  });

  LibraryEntry entry(String id, {DateTime? at}) => LibraryEntry(
        id: id,
        title: 'Doc $id',
        source: DocSource.txt,
        cacheBlocksPath: '/cache/$id.json',
        wordCount: 1,
        pageCount: 0,
        importedAt: at ?? DateTime.parse('2026-01-01T00:00:00.000'),
      );

  test('write then read round-trips the entries', () async {
    await store.write([entry('1'), entry('2')]);
    final back = await store.read();
    expect(back.map((e) => e.id).toSet(), {'1', '2'});
  });

  test('read returns entries newest-first', () async {
    await store.write([
      entry('old', at: DateTime.parse('2026-01-01T00:00:00.000')),
      entry('new', at: DateTime.parse('2026-02-01T00:00:00.000')),
    ]);
    final back = await store.read();
    expect(back.map((e) => e.id).toList(), ['new', 'old']);
  });

  test('a missing index reads as empty without creating artifacts', () async {
    expect(await index.exists(), isFalse);
    expect(await store.read(), isEmpty);
    expect(await corrupt.exists(), isFalse);
    expect(await backup.exists(), isFalse);
  });

  test('a valid empty index is not treated as corruption', () async {
    await store.write(<LibraryEntry>[]);
    expect(await store.read(), isEmpty);
    // An empty *but valid* library must never be mistaken for a torn file.
    expect(await corrupt.exists(), isFalse);
  });

  test('a successful write leaves no temp file behind', () async {
    await store.write([entry('1')]);
    expect(await tmp.exists(), isFalse);
    expect(await index.exists(), isTrue);
  });

  test('overwriting rotates the previous index into a backup', () async {
    await store.write([entry('1')]);
    await store.write([entry('2')]);
    expect(await backup.exists(), isTrue);
    final bak = LibraryEntry.decodeList(await backup.readAsString());
    expect(bak.single.id, '1'); // the previous generation is retained
  });

  test('a corrupt primary is recovered from the backup', () async {
    final good = [entry('keep')];
    await store.write(good); // index.json = [keep], no backup yet
    await store.write(good); // backup = [keep], index.json = [keep]

    // Simulate external corruption / an interrupted legacy write.
    await index.writeAsString('{ this is not valid json');

    final back = await store.read();
    expect(back.single.id, 'keep'); // recovered from the backup, not emptied
    expect(await corrupt.exists(), isTrue); // corrupt bytes preserved
    expect(await corrupt.readAsString(), contains('not valid json'));

    // The store self-heals: a subsequent read sees a good primary again.
    expect(await index.exists(), isTrue);
    expect((await store.read()).single.id, 'keep');
  });

  test('a corrupt primary with no backup yields empty but preserves the bytes',
      () async {
    await index.writeAsString('totally not json');

    final back = await store.read();
    expect(back, isEmpty);
    // The unreadable bytes are moved aside for manual recovery, never
    // overwritten by the next write.
    expect(await corrupt.exists(), isTrue);
    expect(await corrupt.readAsString(), 'totally not json');
    expect(await index.exists(), isFalse);
  });

  test('a zero-byte index is cleared, not preserved as corrupt', () async {
    await index.writeAsString('');
    final back = await store.read();
    expect(back, isEmpty);
    // An empty file holds nothing recoverable, so there is no point keeping it.
    expect(await corrupt.exists(), isFalse);
    expect(await index.exists(), isFalse);
  });

  test('seeds a backup the first time a good legacy index is read', () async {
    // An index written by an older app version that predates the store: a bare
    // index.json with no sidecar backup.
    await index.writeAsString(LibraryEntry.encodeList([entry('legacy')]));
    expect(await backup.exists(), isFalse);

    final back = await store.read();
    expect(back.single.id, 'legacy');
    expect(await backup.exists(), isTrue); // backup seeded for future recovery

    // Corruption is now recoverable even though the store never wrote it.
    await index.writeAsString('torn');
    expect((await store.read()).single.id, 'legacy');
  });

  test('recovers when an interrupted write left only the rotated backup',
      () async {
    // Reproduce the crash window between "rename index.json -> .bak" and
    // "rename index.json.tmp -> index.json": the primary is gone, the backup is
    // the last complete generation, and a possibly-torn temp file remains.
    await backup.writeAsString(LibraryEntry.encodeList([entry('gen-n')]));
    await tmp.writeAsString('partial, possibly torn new generation');
    expect(await index.exists(), isFalse);

    final back = await store.read();
    expect(back.single.id, 'gen-n'); // falls back to the complete backup
    expect(await index.exists(), isTrue); // primary restored
  });

  test('recovery returns the backup data even if re-persisting it fails',
      () async {
    await backup.writeAsString(LibraryEntry.encodeList([entry('safe')]));
    await index.writeAsString('corrupt primary bytes');

    // Make the directory read-only so the self-healing re-write cannot persist.
    // If the test runner has privileges that bypass this (e.g. running as
    // root), the write simply succeeds instead — either way read() must return
    // the recovered entries and must never throw or empty the library.
    await Process.run('chmod', ['a-w', dir.path]);
    try {
      final back = await store.read();
      expect(back.single.id, 'safe');
    } finally {
      await Process.run('chmod', ['u+w', dir.path]); // restore for teardown
    }
  });

  test('a stale temp file from an interrupted write is overwritten', () async {
    await tmp.writeAsString('garbage left over from a crash');
    await store.write([entry('x')]);
    expect((await store.read()).single.id, 'x');
    expect(await tmp.exists(), isFalse);
  });

  test('concurrent writes serialize to the last write with no temp left behind',
      () async {
    // Fire several writes without awaiting between them; the store must queue
    // them so they cannot clobber a shared temp file or race each other's
    // rename.
    final futures = [
      store.write([entry('a')]),
      store.write([entry('b')]),
      store.write([entry('c')]),
    ];
    await Future.wait(futures);

    expect((await store.read()).single.id, 'c');
    expect(await tmp.exists(), isFalse);
  });
}
