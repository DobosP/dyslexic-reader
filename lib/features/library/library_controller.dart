import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../core/platform/pdf_text_channel.dart';
import '../../data/services/ocr_service.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../../domain/reflow/text_cleanup.dart';
import '../../domain/reflow/tokenizer.dart';
import '../../domain/structure/document_structure.dart';
import 'library_index_store.dart';

/// Reports OCR progress (pages done / total, with an optional status label) so
/// the UI can show it.
typedef OcrProgress = void Function(int done, int total, {String? label});

class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Bump when the extraction/OCR pipeline changes, so re-importing an existing
/// document refreshes its cached text in place instead of keeping the old one.
const int _kProcessingVersion = 2;

/// Owns the on-device document library: a JSON index plus a cached **typed
/// blocks** file per document (and, for PDFs, a copied original).
class LibraryController extends AsyncNotifier<List<LibraryEntry>> {
  Directory? _root;
  LibraryIndexStore? _indexStore;

  @override
  Future<List<LibraryEntry>> build() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final root = Directory('${dir.path}/library');
      await root.create(recursive: true);
      _root = root;
      _indexStore = LibraryIndexStore(File('${root.path}/index.json'));
      return _backfillHashes(await _readIndex());
    } catch (_) {
      return <LibraryEntry>[];
    }
  }

  /// Give already-saved PDFs a content hash (from their stored copy) so they can
  /// be de-duplicated on the next import. One-time, best-effort.
  Future<List<LibraryEntry>> _backfillHashes(List<LibraryEntry> entries) async {
    var changed = false;
    final out = <LibraryEntry>[];
    for (final e in entries) {
      if (e.contentHash.isEmpty && e.pdfPath != null) {
        try {
          final f = File(e.pdfPath!);
          if (await f.exists()) {
            out.add(
              e.copyWith(contentHash: _contentHash(await f.readAsBytes())),
            );
            changed = true;
            continue;
          }
        } catch (_) {
          // best effort
        }
      }
      out.add(e);
    }
    if (changed) await _writeIndex(out);
    return out;
  }

  /// Load the index via the atomic store, which recovers from the backup if the
  /// primary `index.json` is corrupt or missing (see [LibraryIndexStore]).
  Future<List<LibraryEntry>> _readIndex() async =>
      await _indexStore?.read() ?? <LibraryEntry>[];

  /// Persist the index atomically (temp file + flush + rename) with a rotating
  /// backup, so an interrupted write can never leave a torn `index.json`.
  Future<void> _writeIndex(List<LibraryEntry> entries) async {
    await _indexStore?.write(entries);
  }

  /// Show the system picker for a PDF or .txt file. Returns null if cancelled.
  Future<XFile?> pickFile() async {
    const group = XTypeGroup(
      label: 'Documents',
      extensions: ['pdf', 'txt', 'docx'],
      mimeTypes: [
        'application/pdf',
        'text/plain',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ],
    );
    return openFile(acceptedTypeGroups: [group]);
  }

  Future<LibraryEntry> importPicked(
    XFile file, {
    OcrProgress? onOcrProgress,
  }) async {
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
    final bytes = await file.readAsBytes();
    final hash = _contentHash(bytes);

    // De-duplicate: if this exact document is already saved, refresh it in place
    // (when the pipeline changed) instead of adding another copy.
    final existing = _findByHash(hash);
    if (existing != null) {
      if (existing.processingVersion >= _kProcessingVersion) {
        return _moveToTop(existing);
      }
      return _reprocessFrom(existing, path, onOcrProgress);
    }

    if (ext == 'pdf') {
      final res = await const PdfTextChannel().extractText(path);
      if (res.hasText) {
        return _store(
          title: title,
          blocks: res.blocks,
          source: DocSource.pdf,
          hasTextLayer: true,
          originalPath: path,
          pdfBytes: bytes,
          pageCount: res.pageCount,
          contentHash: hash,
          pdfOutline: _outlineForBlocks(res.pdfBlocks, res.outline),
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
        contentHash: hash,
      );
    }

    if (ext == 'docx') {
      final blocks = _docxBlocks(bytes);
      if (blocks.isEmpty) {
        throw const ImportException(
          'Could not read text from this Word document.',
        );
      }
      return _store(
        title: title,
        blocks: blocks,
        source: DocSource.docx,
        hasTextLayer: true,
        originalPath: path,
        contentHash: hash,
      );
    }

    final text = await file.readAsString();
    return _store(
      title: title,
      blocks: Tokenizer.blocksFromText(text),
      source: DocSource.txt,
      hasTextLayer: true,
      originalPath: path,
      contentHash: hash,
    );
  }

  /// Extract paragraphs (with heading styles) from a .docx archive's
  /// word/document.xml. Returns empty if the file isn't a readable .docx.
  List<TextBlock> _docxBlocks(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.findFile('word/document.xml');
      if (entry == null) return const [];
      final xml = XmlDocument.parse(
        utf8.decode(entry.content as List<int>, allowMalformed: true),
      );
      final blocks = <TextBlock>[];
      for (final p in xml.findAllElements('p', namespace: '*')) {
        final buf = StringBuffer();
        for (final t in p.findAllElements('t', namespace: '*')) {
          buf.write(t.innerText);
        }
        final text = buf.toString().trim();
        if (text.isEmpty) continue;
        var style = '';
        for (final s in p.findAllElements('pStyle', namespace: '*')) {
          style = s.getAttribute('val', namespace: '*') ?? '';
          break;
        }
        blocks.add(TextBlock(role: _docxRole(style), text: text));
      }
      return blocks;
    } catch (_) {
      return const [];
    }
  }

  BlockRole _docxRole(String style) {
    final s = style.toLowerCase().replaceAll(' ', '');
    if (s == 'title' || s == 'heading1') return BlockRole.h1;
    if (s == 'subtitle' || s == 'heading2') return BlockRole.h2;
    if (s.startsWith('heading')) return BlockRole.h3;
    return BlockRole.body;
  }

  /// Re-run extraction/OCR for an existing document and open the refreshed
  /// result, without re-uploading. Re-reads the stored PDF copy.
  Future<LibraryEntry> reprocess(
    LibraryEntry e, {
    OcrProgress? onOcrProgress,
  }) async {
    final pdf = e.pdfPath;
    if (e.source == DocSource.pdf && pdf != null && await File(pdf).exists()) {
      return _reprocessFrom(e, pdf, onOcrProgress);
    }
    // Nothing to re-extract (e.g. pasted text) — just mark it current.
    return _moveToTop(e.copyWith(processingVersion: _kProcessingVersion));
  }

  LibraryEntry? _findByHash(String hash) {
    if (hash.isEmpty) return null;
    for (final e in state.valueOrNull ?? const <LibraryEntry>[]) {
      if (e.contentHash == hash) return e;
    }
    return null;
  }

  Future<LibraryEntry> _moveToTop(LibraryEntry e) async {
    final updated = e.copyWith(importedAt: DateTime.now());
    final list = state.valueOrNull ?? await _readIndex();
    final next = [updated, ...list.where((x) => x.id != e.id)];
    await _writeIndex(next);
    state = AsyncData(next);
    return updated;
  }

  /// Re-extract [e] from [path] and overwrite its cached blocks, preserving the
  /// id, bookmarks, notes, and reading positions.
  Future<LibraryEntry> _reprocessFrom(
    LibraryEntry e,
    String path,
    OcrProgress? onProgress,
  ) async {
    List<TextBlock> blocks;
    var hasText = true;
    var pageCount = e.pageCount;
    var pdfOutline = e.pdfOutline;
    if (e.source == DocSource.pdf) {
      final res = await const PdfTextChannel().extractText(path);
      pageCount = res.pageCount;
      if (res.hasText) {
        blocks = res.blocks;
        pdfOutline = _outlineForBlocks(res.pdfBlocks, res.outline);
      } else {
        blocks = await _ocrPdf(path, res.pageCount, onProgress);
        hasText = blocks.isNotEmpty;
        pdfOutline = const [];
      }
    } else if (e.source == DocSource.docx) {
      blocks = _docxBlocks(await File(path).readAsBytes());
      hasText = blocks.isNotEmpty;
    } else {
      blocks = Tokenizer.blocksFromText(await File(path).readAsString());
    }
    await File(e.cacheBlocksPath).writeAsString(TextBlock.encodeList(blocks));
    final updated = e.copyWith(
      wordCount: Tokenizer.fromBlocks(blocks).wordCount,
      pageCount: pageCount,
      hasTextLayer: hasText,
      pdfOutline: pdfOutline,
      processingVersion: _kProcessingVersion,
      importedAt: DateTime.now(),
    );
    final list = state.valueOrNull ?? await _readIndex();
    final next = [updated, ...list.where((x) => x.id != e.id)];
    await _writeIndex(next);
    state = AsyncData(next);
    return updated;
  }

  /// Stable content fingerprint (sampled FNV-1a) used to de-duplicate imports.
  String _contentHash(List<int> bytes) {
    const prime = 0x100000001b3;
    var h = 0xcbf29ce484222325;
    final n = bytes.length;
    final step = n <= 1048576 ? 1 : (n ~/ 1048576) + 1;
    for (var i = 0; i < n; i += step) {
      h = (h ^ bytes[i]) * prime;
    }
    h = (h ^ n) * prime;
    return '$n:${h.toRadixString(16)}';
  }

  /// Render each page (native PdfRenderer) and OCR it into body blocks.
  Future<List<TextBlock>> _ocrPdf(
    String path,
    int pageCount,
    OcrProgress? onProgress,
  ) async {
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
        final tmp = File(
          '${tmpDir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}_$i.png',
        );
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
    String contentHash = '',
    List<OutlineItem> pdfOutline = const [],
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
      pdfOutline: pdfOutline,
      contentHash: contentHash,
      processingVersion: _kProcessingVersion,
    );
    final current = state.valueOrNull ?? await _readIndex();
    final next = [entry, ...current];
    await _writeIndex(next);
    state = AsyncData(next);
    return entry;
  }

  Future<ReadingDocument> open(LibraryEntry e) async {
    final blocks = TextBlock.decodeList(
      await File(e.cacheBlocksPath).readAsString(),
    );
    return Tokenizer.fromBlocks(blocks, title: e.title);
  }

  List<OutlineItem> _outlineForBlocks(
    List<PdfTextBlock> blocks,
    List<PdfOutlineDestination> outline,
  ) {
    if (blocks.isEmpty || outline.isEmpty) return const [];

    final pageOffsets = <int, int>{};
    var offset = 0;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.pageIndex >= 0) {
        pageOffsets.putIfAbsent(block.pageIndex, () => offset);
      }
      offset += TextCleanup.clean(block.block.text).length;
      if (i < blocks.length - 1) offset += 2; // Tokenizer.fromBlocks separator.
    }
    if (pageOffsets.isEmpty) return const [];

    int? offsetForPage(int pageIndex) {
      if (pageIndex < 0) return null;
      final exact = pageOffsets[pageIndex];
      if (exact != null) return exact;
      for (var page = pageIndex + 1; page <= pageIndex + 20; page++) {
        final next = pageOffsets[page];
        if (next != null) return next;
      }
      for (var page = pageIndex - 1; page >= 0; page--) {
        final prev = pageOffsets[page];
        if (prev != null) return prev;
      }
      return null;
    }

    final mapped = <OutlineItem>[];
    for (final item in outline) {
      final target = offsetForPage(item.pageIndex);
      if (target == null) continue;
      mapped.add(
        OutlineItem(title: item.title, level: item.level, offset: target),
      );
    }
    return mapped;
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
        .where(
          (b) =>
              !(b.offset == bookmark.offset &&
                  b.createdAt == bookmark.createdAt),
        )
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
    final notes =
        entry.notes
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
