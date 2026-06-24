import 'dart:convert';

import '../structure/document_structure.dart';

/// Where an imported document came from.
enum DocSource {
  sampleText('Sample'),
  pasted('Pasted'),
  pdf('PDF'),
  docx('Word document'),
  txt('Text file');

  const DocSource(this.label);
  final String label;
}

/// A saved spot in a document. [offset] is a character offset into the full
/// text, so it survives font/spacing changes (unlike a page index).
class Bookmark {
  const Bookmark({
    required this.offset,
    required this.label,
    required this.createdAt,
  });

  final int offset;
  final String label;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'offset': offset,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    offset: (j['offset'] as num?)?.toInt() ?? 0,
    label: j['label'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// A user note anchored to a character range [start, end) in the full text.
class Note {
  const Note({
    required this.start,
    required this.end,
    required this.text,
    required this.createdAt,
  });

  final int start;
  final int end;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    start: (j['start'] as num?)?.toInt() ?? 0,
    end: (j['end'] as num?)?.toInt() ?? 0,
    text: j['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Metadata for a document saved in the on-device library. The extracted
/// **typed blocks** are cached as JSON at [cacheBlocksPath]; for PDFs the
/// original file is copied to [pdfPath] for the "original pages" view.
class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.title,
    required this.source,
    required this.cacheBlocksPath,
    required this.wordCount,
    required this.pageCount,
    required this.importedAt,
    this.originalPath,
    this.hasTextLayer = true,
    this.pdfPath,
    this.readingCharOffset = 0,
    this.ttsCharOffset = 0,
    this.bookmarks = const [],
    this.notes = const [],
    this.pdfOutline = const [],
    this.contentHash = '',
    this.processingVersion = 0,
  });

  final String id;
  final String title;
  final DocSource source;
  final String cacheBlocksPath;
  final int wordCount;
  final int pageCount;
  final DateTime importedAt;
  final String? originalPath;

  /// False for scanned/image PDFs with no selectable text (original view only).
  final bool hasTextLayer;

  /// Path to the PDF copied into app storage (for the original page view).
  final String? pdfPath;

  /// Last reading position as a character offset into the full text.
  final int readingCharOffset;

  /// Saved bookmarks for this document.
  final List<Bookmark> bookmarks;

  /// Last text-to-speech position as a character offset into the full text.
  final int ttsCharOffset;

  /// User notes anchored to character ranges.
  final List<Note> notes;

  /// Native PDF outline/bookmark entries mapped to reader character offsets.
  ///
  /// Empty for non-PDF documents and for PDFs without an embedded outline. The
  /// reader falls back to heading-derived contents when this is empty.
  final List<OutlineItem> pdfOutline;

  /// Stable fingerprint of the source file, used to de-duplicate imports.
  final String contentHash;

  /// Which version of the extraction/OCR pipeline produced the cached blocks.
  final int processingVersion;

  LibraryEntry copyWith({
    String? title,
    int? wordCount,
    int? pageCount,
    DateTime? importedAt,
    bool? hasTextLayer,
    int? readingCharOffset,
    int? ttsCharOffset,
    List<Bookmark>? bookmarks,
    List<Note>? notes,
    List<OutlineItem>? pdfOutline,
    String? contentHash,
    int? processingVersion,
  }) => LibraryEntry(
    id: id,
    title: title ?? this.title,
    source: source,
    cacheBlocksPath: cacheBlocksPath,
    wordCount: wordCount ?? this.wordCount,
    pageCount: pageCount ?? this.pageCount,
    importedAt: importedAt ?? this.importedAt,
    originalPath: originalPath,
    hasTextLayer: hasTextLayer ?? this.hasTextLayer,
    pdfPath: pdfPath,
    readingCharOffset: readingCharOffset ?? this.readingCharOffset,
    ttsCharOffset: ttsCharOffset ?? this.ttsCharOffset,
    bookmarks: bookmarks ?? this.bookmarks,
    notes: notes ?? this.notes,
    pdfOutline: pdfOutline ?? this.pdfOutline,
    contentHash: contentHash ?? this.contentHash,
    processingVersion: processingVersion ?? this.processingVersion,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source': source.name,
    'cacheBlocksPath': cacheBlocksPath,
    'wordCount': wordCount,
    'pageCount': pageCount,
    'importedAt': importedAt.toIso8601String(),
    'originalPath': originalPath,
    'hasTextLayer': hasTextLayer,
    'pdfPath': pdfPath,
    'readingCharOffset': readingCharOffset,
    'ttsCharOffset': ttsCharOffset,
    'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'pdfOutline': pdfOutline.map((o) => o.toJson()).toList(),
    'contentHash': contentHash,
    'processingVersion': processingVersion,
  };

  factory LibraryEntry.fromJson(Map<String, dynamic> j) => LibraryEntry(
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Untitled',
    source: DocSource.values.firstWhere(
      (s) => s.name == j['source'],
      orElse: () => DocSource.txt,
    ),
    cacheBlocksPath: j['cacheBlocksPath'] as String,
    wordCount: (j['wordCount'] as num?)?.toInt() ?? 0,
    pageCount: (j['pageCount'] as num?)?.toInt() ?? 0,
    importedAt:
        DateTime.tryParse(j['importedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    originalPath: j['originalPath'] as String?,
    hasTextLayer: j['hasTextLayer'] as bool? ?? true,
    pdfPath: j['pdfPath'] as String?,
    readingCharOffset: (j['readingCharOffset'] as num?)?.toInt() ?? 0,
    ttsCharOffset: (j['ttsCharOffset'] as num?)?.toInt() ?? 0,
    bookmarks: _decodeSafe(j['bookmarks'], Bookmark.fromJson),
    notes: _decodeSafe(j['notes'], Note.fromJson),
    pdfOutline: _decodeSafe(j['pdfOutline'], OutlineItem.fromJson),
    contentHash: j['contentHash'] as String? ?? '',
    processingVersion: (j['processingVersion'] as num?)?.toInt() ?? 0,
  );

  /// Decodes a list of nested metadata items tolerantly: items that are not
  /// Maps or that [fromJson] rejects are skipped rather than aborting the
  /// containing entry. A single malformed bookmark or note must never cause the
  /// whole document record to disappear from the library.
  static List<T> _decodeSafe<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return <T>[];
    final result = <T>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      try {
        result.add(fromJson(item));
      } catch (_) {}
    }
    return result;
  }

  static String encodeList(List<LibraryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<LibraryEntry> decodeList(String s) => (jsonDecode(s) as List)
      .cast<Map<String, dynamic>>()
      .map(LibraryEntry.fromJson)
      .toList();
}
