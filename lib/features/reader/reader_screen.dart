import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/reading_theme.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../library/library_controller.dart';
import '../settings/reading_prefs_controller.dart';
import '../settings/settings_screen.dart';
import 'original_pdf_screen.dart';
import 'widgets/paginated_reader.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.document, this.entry});

  final ReadingDocument document;

  /// The library entry this came from, if any. Enables progress + bookmarks.
  final LibraryEntry? entry;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PageReaderController _pageCtrl = PageReaderController();

  @override
  void dispose() {
    final entry = widget.entry;
    if (entry != null) {
      ref
          .read(libraryControllerProvider.notifier)
          .saveProgress(entry.id, _pageCtrl.currentOffset);
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readingPrefsProvider);
    final palette = paletteFor(prefs.themeId);
    final entry = widget.entry;
    final canViewOriginal = entry?.pdfPath != null && entry!.pageCount > 0;

    final style = TextStyle(
      fontFamily: prefs.fontFamily.family,
      fontSize: prefs.fontSizeSp,
      height: prefs.lineHeight,
      letterSpacing: prefs.letterSpacingPx,
      wordSpacing: prefs.wordSpacingPx,
      color: palette.onBackground,
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (entry != null)
            IconButton(
              tooltip: 'Bookmark this page',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: () => _addBookmark(entry),
            ),
          if (entry != null)
            IconButton(
              tooltip: 'Bookmarks',
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => _showBookmarks(entry.id),
            ),
          if (canViewOriginal)
            IconButton(
              tooltip: 'Original pages',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OriginalPdfScreen(
                    title: widget.document.title,
                    pdfPath: entry.pdfPath!,
                    pageCount: entry.pageCount,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Quick text size',
            icon: const Icon(Icons.format_size),
            onPressed: _quickSize,
          ),
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PaginatedReader(
                document: widget.document,
                style: style,
                maxColumnWidth: prefs.maxLineWidthPx,
                paragraphSpacing: prefs.paragraphSpacingPx,
                bionic: prefs.bionicEnabled,
                initialOffset: entry?.readingCharOffset ?? 0,
                controller: _pageCtrl,
              ),
            ),
            _PageBar(controller: _pageCtrl, palette: palette),
          ],
        ),
      ),
    );
  }

  String _snippet(int offset) {
    final t = widget.document.text;
    if (offset < 0 || offset >= t.length) return 'Bookmark';
    final end = (offset + 48).clamp(0, t.length);
    var s = t.substring(offset, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (end < t.length) s += '…';
    return s.isEmpty ? 'Bookmark' : s;
  }

  void _addBookmark(LibraryEntry entry) {
    final offset = _pageCtrl.currentOffset;
    ref.read(libraryControllerProvider.notifier).addBookmark(
          entry.id,
          Bookmark(offset: offset, label: _snippet(offset), createdAt: DateTime.now()),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark saved'), duration: Duration(seconds: 1)),
    );
  }

  void _showBookmarks(String id) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final list = ref.watch(libraryControllerProvider).valueOrNull ?? const [];
          LibraryEntry? entry;
          for (final e in list) {
            if (e.id == id) entry = e;
          }
          final bookmarks = entry?.bookmarks ?? const <Bookmark>[];
          if (bookmarks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No bookmarks yet. Tap the bookmark icon to save your place.'),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final b in bookmarks)
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(b.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(libraryControllerProvider.notifier)
                        .removeBookmark(id, b),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pageCtrl.jumpToOffset(b.offset);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _quickSize() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final size = ref.watch(readingPrefsProvider.select((p) => p.fontSizeSp));
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text size: ${size.round()}'),
                Slider(
                  value: size,
                  min: 12,
                  max: 40,
                  divisions: 28,
                  label: size.round().toString(),
                  onChanged: (v) =>
                      ref.read(readingPrefsProvider.notifier).setFontSize(v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PageBar extends StatelessWidget {
  const _PageBar({required this.controller, required this.palette});

  final PageReaderController controller;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.pageCount;
        final index = controller.pageIndex.clamp(0, count - 1);
        return Material(
          color: palette.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: index > 0 ? controller.prev : null,
                ),
                Expanded(
                  child: count > 1
                      ? Slider(
                          value: index.toDouble(),
                          min: 0,
                          max: (count - 1).toDouble(),
                          onChanged: (v) => controller.goToPage(v.round()),
                        )
                      : const SizedBox.shrink(),
                ),
                IconButton(
                  tooltip: 'Next page',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: index < count - 1 ? controller.next : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: Text(
                    '${index + 1} / $count${controller.complete ? '' : '…'}',
                    style: TextStyle(color: palette.onBackground),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
