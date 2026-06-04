import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/pdf_text_channel.dart';
import '../../data/services/ocr_service.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../../domain/reflow/tokenizer.dart';

/// Reports OCR progress (pages done / total, with an optional status label) so
/// the UI can show it.
typedef OcrProgress = void Function(int done, int total, {String? label});

class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns the on-device document library: a JSON index plus a cached **typed
/// blocks** file per document (and, for PDFs, a copied original).
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

  Future<LibraryEntry> importPicked(XFile file, {OcrProgress? onOcrProgress}) async {
    if (file.path.isEmpty) {
      throw const ImportException('Could not read the selected file.');
    }
    return importFromPath(file.path, file.name, onOcrProgress: onOcrProgress);
  }

  /// Import from a filesystem [path] (picker or open-with/share intent).
  /// Scanned PDFs (no text layer) are OCR'd on-device into text.
  Future<LibraryEntry> importFromPath(
    String path,
    String name, {
    OcrProgress? onOcrProgress,
  }) async {
    final file = File(path);
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final title = _stripExtension(name);

    if (ext == 'pdf') {
      final res = await const PdfTextChannel().extractText(path);
      final bytes = await file.readAsBytes();
      if (res.hasText) {
        return _store(
          title: title,
          blocks: res.blocks,
          source: DocSource.pdf,
          hasTextLayer: true,
          originalPath: path,
          pdfBytes: bytes,
          pageCount: res.pageCount,
        );
      }
      // Scanned / image-only PDF → OCR each page on-device.
      final ocrBlocks = await _ocrPdf(path, res.pageCount, onOcrProgress);
      return _store(
        title: title,
        blocks: ocrBlocks,
        source: DocSource.pdf,
        hasTextLayer: ocrBlocks.isNotEmpty,
        originalPath: path,
        pdfBytes: bytes,
        pageCount: res.pageCount,
      );
    }

    final text = await file.readAsString();
    return _store(
      title: title,
      blocks: Tokenizer.blocksFromText(text),
      source: DocSource.txt,
      hasTextLayer: true,
      originalPath: path,
    );
  }

  /// Render each page (native PdfRenderer) and OCR it into body blocks.
  Future<List<TextBlock>> _ocrPdf(String path, int pageCount, OcrProgress? onProgress) async {
    if (pageCount <= 0) return const [];
    const channel = PdfTextChannel();
    final ocr = await _resolveOcrEngine(onProgress);
    final tmpDir = await getTemporaryDirectory();
    final blocks = <TextBlock>[];
    try {
      for (var i = 0; i < pageCount; i++) {
        onProgress?.call(i, pageCount);
        // Render at higher resolution than the on-screen view for better OCR accuracy.
        final png = await channel.renderPage(path, i, targetWidth: 2200);
        if (png == null) continue;
        final tmp = File('${tmpDir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}_$i.png');
        await tmp.writeAsBytes(png);
        try {
          for (final text in await ocr.recognizeBlocks(tmp.path)) {
            blocks.add(TextBlock(role: BlockRole.body, text: text));
          }
        } catch (_) {
          // Skip a page the engine can't process; keep importing the rest.
        } finally {
          try {
            await tmp.delete();
          } catch (_) {}
        }
      }
      onProgress?.call(pageCount, pageCount);
    } finally {
      await ocr.dispose();
    }
    return blocks;
  }

  /// Prefer PaddleOCR (PP-OCRv5); fall back to bundled ML Kit if its models
  /// can't be prepared (e.g. offline on first run, or an unsupported device).
  Future<OcrEngine> _resolveOcrEngine(OcrProgress? onProgress) async {
    final paddle = PaddleOcrEngine();
    try {
      onProgress?.call(0, 0, label: 'Preparing OCR model…');
      if (await paddle.prepare()) return paddle;
    } catch (_) {
      // fall through to ML Kit
    }
    await paddle.dispose();
    return MlKitOcrEngine();
  }

  Future<LibraryEntry> _store({
    required String title,
    required List<TextBlock> blocks,
    required DocSource source,
    required bool hasTextLayer,
    String? originalPath,
    List<int>? pdfBytes,
    int pageCount = 0,
  }) async {
    final root = _root;
    if (root == null) throw const ImportException('Storage is not available.');
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final blocksFile = File('${root.path}/$id.json');
    await blocksFile.writeAsString(TextBlock.encodeList(blocks));

    String? pdfPath;
    if (pdfBytes != null) {
      final pdfFile = File('${root.path}/$id.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      pdfPath = pdfFile.path;
    }

    final entry = LibraryEntry(
      id: id,
      title: title,
      source: source,
      cacheBlocksPath: blocksFile.path,
      wordCount: Tokenizer.fromBlocks(blocks).wordCount,
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
    final blocks = TextBlock.decodeList(await File(e.cacheBlocksPath).readAsString());
    return Tokenizer.fromBlocks(blocks, title: e.title);
  }

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
        .where((b) =>
            !(b.offset == bookmark.offset && b.createdAt == bookmark.createdAt))
        .toList();
    final next = [...list];
    next[idx] = entry.copyWith(bookmarks: bookmarks);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  /// Add a note, or replace an existing note on the same character range.
  Future<void> upsertNote(String id, Note note) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final entry = list[idx];
    final notes = entry.notes
        .where((n) => !(n.start == note.start && n.end == note.end))
        .toList()
      ..add(note)
      ..sort((a, b) => a.start.compareTo(b.start));
    final next = [...list];
    next[idx] = entry.copyWith(notes: notes);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  Future<void> removeNote(String id, Note note) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final entry = list[idx];
    final notes = entry.notes
        .where((n) => !(n.start == note.start && n.end == note.end))
        .toList();
    final next = [...list];
    next[idx] = entry.copyWith(notes: notes);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  Future<void> saveTtsPosition(String id, int charOffset) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final next = [...list];
    next[idx] = list[idx].copyWith(ttsCharOffset: charOffset);
    await _writeIndex(next);
    state = AsyncData(next);
  }

  Future<void> delete(LibraryEntry e) async {
    for (final p in [e.cacheBlocksPath, e.pdfPath]) {
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
