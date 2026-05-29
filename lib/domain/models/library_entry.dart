import 'dart:convert';

/// Where an imported document came from.
enum DocSource {
  sampleText('Sample'),
  pasted('Pasted'),
  pdf('PDF'),
  txt('Text file');

  const DocSource(this.label);
  final String label;
}

/// A saved spot in a document. [offset] is a character offset into the full
/// text, so it survives font/spacing changes (unlike a page index).
class Bookmark {
  const Bookmark({required this.offset, required this.label, required this.createdAt});

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
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
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
    this.bookmarks = const [],
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

  LibraryEntry copyWith({
    int? readingCharOffset,
    List<Bookmark>? bookmarks,
  }) =>
      LibraryEntry(
        id: id,
        title: title,
        source: source,
        cacheBlocksPath: cacheBlocksPath,
        wordCount: wordCount,
        pageCount: pageCount,
        importedAt: importedAt,
        originalPath: originalPath,
        hasTextLayer: hasTextLayer,
        pdfPath: pdfPath,
        readingCharOffset: readingCharOffset ?? this.readingCharOffset,
        bookmarks: bookmarks ?? this.bookmarks,
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
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
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
        importedAt: DateTime.tryParse(j['importedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        originalPath: j['originalPath'] as String?,
        hasTextLayer: j['hasTextLayer'] as bool? ?? true,
        pdfPath: j['pdfPath'] as String?,
        readingCharOffset: (j['readingCharOffset'] as num?)?.toInt() ?? 0,
        bookmarks: ((j['bookmarks'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Bookmark.fromJson)
            .toList(),
      );

  static String encodeList(List<LibraryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<LibraryEntry> decodeList(String s) => (jsonDecode(s) as List)
      .cast<Map<String, dynamic>>()
      .map(LibraryEntry.fromJson)
      .toList();
}
