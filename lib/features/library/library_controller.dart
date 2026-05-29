import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/pdf_text_channel.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../../domain/reflow/tokenizer.dart';

class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns the on-device document library: a JSON index plus a cached text file
/// (and, for PDFs, a copied original) per document, under the app docs dir.
class LibraryController extends AsyncNotifier<List<LibraryEntry>> {
  Directory? _root;
  File? _indexFile;

  @override
  Future<List<LibraryEntry>> build() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final root = Directory('${dir.path}/library');
      await root.create(recursive: true);
      _root = root;
      _indexFile = File('${root.path}/index.json');
      return _readIndex();
    } catch (_) {
      // Platform storage unavailable (e.g. unit tests) — start empty.
      return <LibraryEntry>[];
    }
  }

  Future<List<LibraryEntry>> _readIndex() async {
    final f = _indexFile;
    if (f == null || !await f.exists()) return <LibraryEntry>[];
    try {
      final entries = LibraryEntry.decodeList(await f.readAsString());
      entries.sort((a, b) => b.importedAt.compareTo(a.importedAt));
      return entries;
    } catch (_) {
      return <LibraryEntry>[];
    }
  }

  Future<void> _writeIndex(List<LibraryEntry> entries) async {
    await _indexFile?.writeAsString(LibraryEntry.encodeList(entries));
  }

  /// Show the system picker for a PDF or .txt file. Returns null if cancelled.
  Future<XFile?> pickFile() async {
    const group = XTypeGroup(
      label: 'Documents',
      extensions: ['pdf', 'txt'],
      mimeTypes: ['application/pdf', 'text/plain'],
    );
    return openFile(acceptedTypeGroups: [group]);
  }

  /// Extract/read a picked [file] and store it. Scanned PDFs (no text layer)
  /// are still imported so they can be read in the original page view.
  Future<LibraryEntry> importPicked(XFile file) async {
    if (file.path.isEmpty) {
      throw const ImportException('Could not read the selected file.');
    }
    return importFromPath(file.path, file.name);
  }

  /// Import a document from a filesystem [path] with display [name] (used by the
  /// picker and by open-with / share intents).
  Future<LibraryEntry> importFromPath(String path, String name) async {
    final file = File(path);
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final title = _stripExtension(name);

    if (ext == 'pdf') {
      final res = await const PdfTextChannel().extractText(path);
      final bytes = await file.readAsBytes();
      return _store(
        title: title,
        text: res.fullText,
        source: DocSource.pdf,
        hasTextLayer: res.hasText,
        originalPath: path,
        pdfBytes: bytes,
        pageCount: res.pageCount,
      );
    }
    final text = await file.readAsString();
    return _store(
      title: title,
      text: text,
      source: DocSource.txt,
      hasTextLayer: true,
      originalPath: path,
    );
  }

  Future<LibraryEntry> _store({
    required String title,
    required String text,
    required DocSource source,
    required bool hasTextLayer,
    String? originalPath,
    List<int>? pdfBytes,
    int pageCount = 0,
  }) async {
    final root = _root;
    if (root == null) throw const ImportException('Storage is not available.');
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final textFile = File('${root.path}/$id.txt');
    await textFile.writeAsString(text);

    String? pdfPath;
    if (pdfBytes != null) {
      final pdfFile = File('${root.path}/$id.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      pdfPath = pdfFile.path;
    }

    final doc = Tokenizer.parse(text, title: title);
    final entry = LibraryEntry(
      id: id,
      title: title,
      source: source,
      cacheTextPath: textFile.path,
      wordCount: doc.wordCount,
      pageCount: pageCount,
      importedAt: DateTime.now(),
      originalPath: originalPath,
      hasTextLayer: hasTextLayer,
      pdfPath: pdfPath,
    );
    final current = state.valueOrNull ?? await _readIndex();
    final next = [entry, ...current];
    await _writeIndex(next);
    state = AsyncData(next);
    return entry;
  }

  Future<ReadingDocument> open(LibraryEntry e) async {
    final text = await File(e.cacheTextPath).readAsString();
    return Tokenizer.parse(text, title: e.title);
  }

  /// Persist the reading position (char offset) for [id]; no-op otherwise.
  Future<void> saveProgress(String id, int charOffset) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final next = [...list];
    next[idx] = list[idx].copyWith(readingCharOffset: charOffset);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  Future<void> addBookmark(String id, Bookmark bookmark) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final entry = list[idx];
    final bookmarks = [...entry.bookmarks, bookmark]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    final next = [...list];
    next[idx] = entry.copyWith(bookmarks: bookmarks);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  Future<void> removeBookmark(String id, Bookmark bookmark) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final entry = list[idx];
    final bookmarks = entry.bookmarks
        .where((b) => !(b.offset == bookmark.offset &&
            b.createdAt == bookmark.createdAt))
        .toList();
    final next = [...list];
    next[idx] = entry.copyWith(bookmarks: bookmarks);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  Future<void> delete(LibraryEntry e) async {
    for (final p in [e.cacheTextPath, e.pdfPath]) {
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // best effort
      }
    }
    final next = (state.valueOrNull ?? <LibraryEntry>[])
        .where((x) => x.id != e.id)
        .toList();
    await _writeIndex(next);
    state = AsyncData(next);
  }

  static String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<LibraryEntry>>(
  LibraryController.new,
);
