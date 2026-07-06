import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OneDocLibrary extends LibraryController {
  _OneDocLibrary(this._entry);

  final LibraryEntry _entry;

  @override
  Future<List<LibraryEntry>> build() async => [_entry];
}

void main() {
  test(
    'upsertHighlight replaces same range and removeHighlight deletes it',
    () async {
      final entry = LibraryEntry(
        id: 'doc',
        title: 'Doc',
        source: DocSource.txt,
        cacheBlocksPath: '/cache/doc.json',
        wordCount: 4,
        pageCount: 1,
        importedAt: DateTime(2026),
        highlights: [
          TextHighlight(start: 30, end: 40, createdAt: DateTime(2026, 1, 3)),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          libraryControllerProvider.overrideWith(() => _OneDocLibrary(entry)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(libraryControllerProvider.future);
      final controller = container.read(libraryControllerProvider.notifier);

      final first = TextHighlight(
        start: 10,
        end: 20,
        createdAt: DateTime(2026, 1, 1),
      );
      final replacement = TextHighlight(
        start: 10,
        end: 20,
        createdAt: DateTime(2026, 1, 2),
      );

      await controller.upsertHighlight('doc', first);
      await controller.upsertHighlight('doc', replacement);

      final afterUpsert = container.read(libraryControllerProvider).value!;
      expect(afterUpsert.single.highlights, hasLength(2));
      expect(afterUpsert.single.highlights.first.start, 10);
      expect(
        afterUpsert.single.highlights.first.createdAt,
        replacement.createdAt,
      );
      expect(afterUpsert.single.highlights.last.start, 30);

      await controller.removeHighlight('doc', replacement);

      final afterRemove = container.read(libraryControllerProvider).value!;
      expect(afterRemove.single.highlights, hasLength(1));
      expect(afterRemove.single.highlights.single.start, 30);
    },
  );
}
