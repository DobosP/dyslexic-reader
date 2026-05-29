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

/// Metadata for a document saved in the on-device library. The extracted/plain
/// text is cached in a file at [cacheTextPath] so reopening is instant.
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
  });

  final String id;
  final String title;
  final DocSource source;
  final String cacheTextPath;
  final int wordCount;
  final int pageCount;
  final DateTime importedAt;
  final String? originalPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source.name,
        'cacheTextPath': cacheTextPath,
        'wordCount': wordCount,
        'pageCount': pageCount,
        'importedAt': importedAt.toIso8601String(),
        'originalPath': originalPath,
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
      );

  static String encodeList(List<LibraryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<LibraryEntry> decodeList(String s) => (jsonDecode(s) as List)
      .cast<Map<String, dynamic>>()
      .map(LibraryEntry.fromJson)
      .toList();
}
