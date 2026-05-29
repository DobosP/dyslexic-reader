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

/// Metadata for a document saved in the on-device library. Extracted/plain text
/// is cached at [cacheTextPath]; for PDFs the original file is copied to
/// [pdfPath] so the "original pages" view can render it.
class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.title,
    required this.source,
    required this.cacheTextPath,
    required this.wordCount,
    required this.pageCount,
    required this.importedAt,
    this.originalPath,
    this.hasTextLayer = true,
    this.pdfPath,
    this.scrollOffset = 0,
  });

  final String id;
  final String title;
  final DocSource source;
  final String cacheTextPath;
  final int wordCount;
  final int pageCount;
  final DateTime importedAt;
  final String? originalPath;

  /// False for scanned/image PDFs with no selectable text (original view only).
  final bool hasTextLayer;

  /// Path to the PDF copied into app storage (for the original page view).
  final String? pdfPath;

  /// Saved reflow scroll position, restored when the document is reopened.
  final double scrollOffset;

  LibraryEntry copyWith({double? scrollOffset}) => LibraryEntry(
        id: id,
        title: title,
        source: source,
        cacheTextPath: cacheTextPath,
        wordCount: wordCount,
        pageCount: pageCount,
        importedAt: importedAt,
        originalPath: originalPath,
        hasTextLayer: hasTextLayer,
        pdfPath: pdfPath,
        scrollOffset: scrollOffset ?? this.scrollOffset,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source.name,
        'cacheTextPath': cacheTextPath,
        'wordCount': wordCount,
        'pageCount': pageCount,
        'importedAt': importedAt.toIso8601String(),
        'originalPath': originalPath,
        'hasTextLayer': hasTextLayer,
        'pdfPath': pdfPath,
        'scrollOffset': scrollOffset,
      };

  factory LibraryEntry.fromJson(Map<String, dynamic> j) => LibraryEntry(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Untitled',
        source: DocSource.values.firstWhere(
          (s) => s.name == j['source'],
          orElse: () => DocSource.txt,
        ),
        cacheTextPath: j['cacheTextPath'] as String,
        wordCount: (j['wordCount'] as num?)?.toInt() ?? 0,
        pageCount: (j['pageCount'] as num?)?.toInt() ?? 0,
        importedAt: DateTime.tryParse(j['importedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        originalPath: j['originalPath'] as String?,
        hasTextLayer: j['hasTextLayer'] as bool? ?? true,
        pdfPath: j['pdfPath'] as String?,
        scrollOffset: (j['scrollOffset'] as num?)?.toDouble() ?? 0,
      );

  static String encodeList(List<LibraryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<LibraryEntry> decodeList(String s) => (jsonDecode(s) as List)
      .cast<Map<String, dynamic>>()
      .map(LibraryEntry.fromJson)
      .toList();
}
