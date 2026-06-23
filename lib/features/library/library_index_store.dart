import 'dart:io';

import '../../domain/models/library_entry.dart';

/// Persists the library index (`.../library/index.json`) with **atomic,
/// recoverable** writes so a torn or corrupt index can never silently empty the
/// user's library.
///
/// Guarantees:
/// * **Atomic writes** — each write goes to a temp file that is flushed to disk
///   and then atomically renamed over the live index. A reader therefore always
///   observes either the complete previous index or the complete new one, never
///   a half-written file (a plain `writeAsString` truncates first, so an
///   interrupted write would leave `index.json` torn).
/// * **A backup** — the previous good index is kept as `index.json.bak`, so if
///   `index.json` is ever unreadable (external corruption, bad sectors, an
///   interrupted legacy write) it is recovered from the backup instead of being
///   treated as an empty library.
/// * **No silent loss** — if the primary is unreadable *and* cannot be
///   recovered, the corrupt bytes are preserved as `index.json.corrupt` rather
///   than being overwritten by the next write. The cached per-document block
///   files on disk are left untouched either way.
class LibraryIndexStore {
  LibraryIndexStore(this.file);

  /// The live index file (`.../library/index.json`).
  final File file;

  File get _tmpFile => File('${file.path}.tmp');
  File get _backupFile => File('${file.path}.bak');
  File get _corruptFile => File('${file.path}.corrupt');

  /// Serializes writes. Dart is single-threaded, but mutators `await` between
  /// steps, so two index writes can interleave; chaining them prevents one from
  /// clobbering the shared temp file or racing another's rename.
  Future<void> _queue = Future<void>.value();

  /// Load the index, recovering from the backup when the primary is corrupt or
  /// missing. Never throws. Returns an empty list only when there is genuinely
  /// nothing to read — never merely because a present file failed to parse.
  Future<List<LibraryEntry>> read() async {
    final primary = await _tryDecode(file);
    if (primary != null) {
      // Seed a backup the first time we see a good primary (e.g. an index
      // written by an older app version that predates this store), so later
      // corruption is recoverable.
      await _ensureBackup();
      return _sorted(primary);
    }

    final recovered = await _tryDecode(_backupFile);
    if (recovered != null) {
      // The primary was unreadable but the backup is good. Preserve the corrupt
      // primary for diagnostics, then restore the index from the backup.
      await _preserveCorrupt();
      // Self-heal best-effort: re-persist the recovered index. If this write
      // fails (e.g. the disk is full) we must STILL return the recovered
      // entries — the backup is untouched on disk, so the next launch recovers
      // again. Letting this throw would bubble up to the caller and could
      // present an empty library, which is the exact failure this store exists
      // to prevent.
      try {
        await write(recovered);
      } catch (_) {
        // best effort; the in-memory recovery still stands
      }
      return _sorted(recovered);
    }

    // Nothing usable anywhere. Preserve a corrupt primary (if any) so the next
    // write does not silently overwrite the user's only remaining copy.
    await _preserveCorrupt();
    return <LibraryEntry>[];
  }

  /// Atomically persist [entries]: write a flushed temp file, rotate the
  /// current index into the backup, then atomically rename the temp into place.
  Future<void> write(List<LibraryEntry> entries) {
    final data = LibraryEntry.encodeList(entries);
    final result = _queue.then((_) => _atomicWrite(data));
    // Keep the chain usable even if one write fails.
    _queue = result.catchError((_) {});
    return result;
  }

  Future<void> _atomicWrite(String data) async {
    await _tmpFile.writeAsString(data, flush: true);
    // Rotate the current good index into the backup before replacing it. Using
    // an atomic rename keeps the backup a complete file (the prior generation).
    if (await file.exists()) {
      try {
        if (await _backupFile.exists()) await _backupFile.delete();
        await file.rename(_backupFile.path);
      } catch (_) {
        // Best-effort backup. The atomic rename below is what guarantees the
        // primary is never left torn.
      }
    }
    await _tmpFile.rename(file.path);
  }

  /// Decode [f] into entries, or null if it is missing or unparseable.
  Future<List<LibraryEntry>?> _tryDecode(File f) async {
    try {
      if (!await f.exists()) return null;
      return LibraryEntry.decodeList(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Create a backup from the current good primary if one doesn't exist yet.
  Future<void> _ensureBackup() async {
    try {
      if (!await _backupFile.exists() && await file.exists()) {
        await file.copy(_backupFile.path);
      }
    } catch (_) {
      // best effort
    }
  }

  /// Move an unreadable, non-empty primary aside as `index.json.corrupt` so its
  /// bytes survive for manual recovery instead of being overwritten. Keeps the
  /// earliest corrupt snapshot if one was already preserved.
  Future<void> _preserveCorrupt() async {
    try {
      if (!await file.exists()) return;
      if (await file.length() == 0) {
        // An empty file holds no recoverable data; just clear it.
        await file.delete();
        return;
      }
      if (await _corruptFile.exists()) {
        // Keep the first corrupt snapshot (closest to the last good state) and
        // drop the live corrupt copy so the next write starts clean.
        await file.delete();
      } else {
        await file.rename(_corruptFile.path);
      }
    } catch (_) {
      // best effort
    }
  }

  List<LibraryEntry> _sorted(List<LibraryEntry> entries) {
    entries.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return entries;
  }
}
