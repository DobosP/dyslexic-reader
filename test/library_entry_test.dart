import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library entry list round-trips through JSON', () {
    final entries = [
      LibraryEntry(
        id: '1',
        title: 'Doc',
        source: DocSource.pdf,
        cacheTextPath: '/x/1.txt',
        wordCount: 10,
        pageCount: 3,
        importedAt: DateTime.parse('2026-01-02T03:04:05.000'),
        originalPath: '/x/orig.pdf',
      ),
    ];
    final back = LibraryEntry.decodeList(LibraryEntry.encodeList(entries));
    expect(back, hasLength(1));
    expect(back.first.title, 'Doc');
    expect(back.first.source, DocSource.pdf);
    expect(back.first.pageCount, 3);
    expect(back.first.importedAt, DateTime.parse('2026-01-02T03:04:05.000'));
    expect(back.first.originalPath, '/x/orig.pdf');
  });

  test('unknown source falls back to txt', () {
    final e = LibraryEntry.fromJson(const {
      'id': '1',
      'title': 't',
      'source': 'weird',
      'cacheTextPath': '/p',
      'wordCount': 1,
      'pageCount': 0,
      'importedAt': '2026-01-01T00:00:00.000',
    });
    expect(e.source, DocSource.txt);
  });
}
