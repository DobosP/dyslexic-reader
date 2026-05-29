import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

/// Thrown for image-only PDFs with no selectable text (need OCR — later phase).
class ScannedPdfException implements Exception {
  const ScannedPdfException();
}

/// Owns the on-device document library: a JSON index plus one cached text file
/// per document, stored under the app documents directory.
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

  Future<LibraryEntry> _add({
    required String title,
    required String text,
    required DocSource source,
    String? originalPath,
    int pageCount = 0,
  }) async {
    final root = _root;
    if (root == null) throw const ImportException('Storage is not available.');
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final textFile = File('${root.path}/$id.txt');
    await textFile.writeAsString(text);
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
    );
    final current = state.valueOrNull ?? await _readIndex();
    final next = [entry, ...current];
    await _writeIndex(next);
    state = AsyncData(next);
    return entry;
  }

  /// Show the system picker for a PDF or .txt file. Returns null if cancelled.
  Future<PlatformFile?> pickFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );
    if (picked == null || picked.files.isEmpty) return null;
    return picked.files.single;
  }

  /// Extract/read [file]'s text and store it. Throws [ScannedPdfException] for
  /// image-only PDFs.
  Future<LibraryEntry> importPicked(PlatformFile file) async {
    final path = file.path;
    if (path == null) {
      throw const ImportException('Could not read the selected file.');
    }
    final ext = (file.extension ?? '').toLowerCase();
    final title = _stripExtension(file.name);

    if (ext == 'pdf') {
      final res = await const PdfTextChannel().extractText(path);
      if (!res.hasText) throw const ScannedPdfException();
      return _add(
        title: title,
        text: res.fullText,
        source: DocSource.pdf,
        originalPath: path,
        pageCount: res.pageCount,
      );
    }
    final text = await File(path).readAsString();
    return _add(
      title: title,
      text: text,
      source: DocSource.txt,
      originalPath: path,
    );
  }

  Future<ReadingDocument> open(LibraryEntry e) async {
    final text = await File(e.cacheTextPath).readAsString();
    return Tokenizer.parse(text, title: e.title);
  }

  Future<void> delete(LibraryEntry e) async {
    try {
      final f = File(e.cacheTextPath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best effort
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
