import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library entry list round-trips through JSON (incl. bookmarks)', () {
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
        hasTextLayer: false,
        pdfPath: '/x/1.pdf',
        readingCharOffset: 250,
        bookmarks: [
          Bookmark(
            offset: 100,
            label: 'Chapter 2',
            createdAt: DateTime.parse('2026-01-03T00:00:00.000'),
          ),
        ],
      ),
    ];
    final back = LibraryEntry.decodeList(LibraryEntry.encodeList(entries));
    expect(back, hasLength(1));
    final e = back.first;
    expect(e.source, DocSource.pdf);
    expect(e.hasTextLayer, false);
    expect(e.pdfPath, '/x/1.pdf');
    expect(e.readingCharOffset, 250);
    expect(e.bookmarks, hasLength(1));
    expect(e.bookmarks.first.offset, 100);
    expect(e.bookmarks.first.label, 'Chapter 2');
  });

  test('unknown source falls back to txt; defaults applied', () {
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
    expect(e.readingCharOffset, 0);
    expect(e.bookmarks, isEmpty);
  });

  test('copyWith updates reading offset without touching other fields', () {
    final e = LibraryEntry(
      id: '1',
      title: 'Doc',
      source: DocSource.txt,
      cacheTextPath: '/x/1.txt',
      wordCount: 5,
      pageCount: 0,
      importedAt: DateTime.parse('2026-01-01T00:00:00.000'),
    );
    final moved = e.copyWith(readingCharOffset: 42);
    expect(moved.readingCharOffset, 42);
    expect(moved.title, 'Doc');
    expect(moved.id, e.id);
    expect(moved.bookmarks, isEmpty);
  });
}
