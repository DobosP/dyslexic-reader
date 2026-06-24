import 'dart:convert';

import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library entry list round-trips through JSON (incl. bookmarks)', () {
    final entries = [
      LibraryEntry(
        id: '1',
        title: 'Doc',
        source: DocSource.pdf,
        cacheBlocksPath: '/x/1.txt',
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

  test('round-trip preserves notes, ttsCharOffset, contentHash, processingVersion', () {
    final original = LibraryEntry(
      id: '42',
      title: 'Rich Doc',
      source: DocSource.docx,
      cacheBlocksPath: '/c/42.json',
      wordCount: 500,
      pageCount: 10,
      importedAt: DateTime.parse('2026-03-01T10:00:00.000'),
      ttsCharOffset: 1234,
      contentHash: 'abc123',
      processingVersion: 3,
      notes: [
        Note(
          start: 50,
          end: 80,
          text: 'Interesting',
          createdAt: DateTime.parse('2026-03-02T08:00:00.000'),
        ),
      ],
    );
    final back = LibraryEntry.decodeList(LibraryEntry.encodeList([original])).first;
    expect(back.ttsCharOffset, 1234);
    expect(back.contentHash, 'abc123');
    expect(back.processingVersion, 3);
    expect(back.notes, hasLength(1));
    expect(back.notes.first.start, 50);
    expect(back.notes.first.end, 80);
    expect(back.notes.first.text, 'Interesting');
  });

  test('malformed bookmark items are skipped; valid ones are preserved', () {
    final json = jsonEncode([
      {
        'id': '1',
        'title': 'Doc',
        'source': 'txt',
        'cacheBlocksPath': '/p',
        'wordCount': 1,
        'pageCount': 0,
        'importedAt': '2026-01-01T00:00:00.000',
        'bookmarks': [
          null,                        // null — not a Map
          'bad string',                // String — not a Map
          42,                          // int — not a Map
          {'offset': 99, 'label': 'Good', 'createdAt': '2026-01-02T00:00:00.000'},
        ],
      }
    ]);
    final entries = LibraryEntry.decodeList(json);
    expect(entries, hasLength(1));
    expect(entries.first.bookmarks, hasLength(1));
    expect(entries.first.bookmarks.first.offset, 99);
    expect(entries.first.bookmarks.first.label, 'Good');
  });

  test('malformed note items are skipped; valid ones are preserved', () {
    final json = jsonEncode([
      {
        'id': '2',
        'title': 'Doc',
        'source': 'txt',
        'cacheBlocksPath': '/p',
        'wordCount': 1,
        'pageCount': 0,
        'importedAt': '2026-01-01T00:00:00.000',
        'notes': [
          null,
          {'start': 10, 'end': 20, 'text': 'Keep', 'createdAt': '2026-01-03T00:00:00.000'},
          'oops',
        ],
      }
    ]);
    final entries = LibraryEntry.decodeList(json);
    expect(entries, hasLength(1));
    expect(entries.first.notes, hasLength(1));
    expect(entries.first.notes.first.text, 'Keep');
  });

  test('all-malformed bookmark list decodes to empty without throwing', () {
    final json = jsonEncode([
      {
        'id': '3',
        'title': 'Doc',
        'source': 'txt',
        'cacheBlocksPath': '/p',
        'wordCount': 1,
        'pageCount': 0,
        'importedAt': '2026-01-01T00:00:00.000',
        'bookmarks': [null, 'x', 7],
      }
    ]);
    final entries = LibraryEntry.decodeList(json);
    expect(entries, hasLength(1));
    expect(entries.first.bookmarks, isEmpty);
  });

  test('unknown source falls back to txt; defaults applied', () {
    final e = LibraryEntry.fromJson(const {
      'id': '1',
      'title': 't',
      'source': 'weird',
      'cacheBlocksPath': '/p',
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
      cacheBlocksPath: '/x/1.txt',
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
