import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/reading_theme.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../../domain/reflow/sentences.dart';
import '../../domain/structure/document_structure.dart';
import '../library/library_controller.dart';
import '../settings/reading_prefs_controller.dart';
import '../settings/settings_screen.dart';
import 'original_pdf_screen.dart';
import 'widgets/outline_drawer.dart';
import 'widgets/paginated_reader.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.document, this.entry});

  final ReadingDocument document;
  final LibraryEntry? entry;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageReaderController _pageCtrl = PageReaderController();

  // Highlight is driven via a notifier so updates repaint only the visible
  // paragraphs (smooth, in sync with scrolling).
  final ValueNotifier<ReadingHighlight> _highlight =
      ValueNotifier(ReadingHighlight.none);

  ReadingDocument? _effectiveDoc;
  bool? _lastPacing;
  List<OutlineItem>? _outline;
  ReadingStats? _stats;
  List<SentenceRef>? _sentences;
  ReadingDocument? _sentencesDoc;

  int _currentSentence = -1;
  bool _playing = false;
  bool _helperOn = false;
  Timer? _timer;

  ReadingDocument _resolveDoc(bool pacing) {
    if (_effectiveDoc == null || _lastPacing != pacing) {
      _lastPacing = pacing;
      _effectiveDoc =
          pacing ? Sentences.splitDocument(widget.document) : widget.document;
    }
    return _effectiveDoc!;
  }

  List<SentenceRef> _resolveSentences(ReadingDocument doc) {
    if (_sentences == null || !identical(_sentencesDoc, doc)) {
      _sentencesDoc = doc;
      _sentences = DocumentStructure.sentenceRefs(doc);
    }
    return _sentences!;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _highlight.dispose();
    final entry = widget.entry;
    if (entry != null) {
      ref
          .read(libraryControllerProvider.notifier)
          .saveProgress(entry.id, _pageCtrl.currentOffset);
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Push the current sentence into the highlight notifier (or clear it).
  void _applyHighlight() {
    final sentences = _sentences ?? const <SentenceRef>[];
    if (_currentSentence < 0 || _currentSentence >= sentences.length) {
      _highlight.value = ReadingHighlight.none;
      return;
    }
    final s = sentences[_currentSentence];
    final accent = paletteFor(ref.read(readingPrefsProvider).themeId).accent;
    _highlight.value = ReadingHighlight(
      sentenceStart: s.start,
      sentenceEnd: s.end,
      paragraphStart: s.paragraphStart,
      paragraphEnd: s.paragraphEnd,
      sentenceColor: accent.withValues(alpha: 0.22),
      paragraphColor: accent.withValues(alpha: 0.08),
    );
  }

  // --- Read-along pacer (auto-advance) ---

  void _togglePlay() => _playing ? _pause() : _play();

  void _play() {
    final sentences = _sentences ?? const <SentenceRef>[];
    if (sentences.isEmpty) return;
    setState(() {
      _playing = true;
      if (_currentSentence < 0 || _currentSentence >= sentences.length) {
        _currentSentence =
            DocumentStructure.sentenceIndexAtOffset(sentences, _pageCtrl.currentOffset);
      }
    });
    _applyHighlight();
    _tick();
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  void _tick() {
    if (!_playing) return;
    final sentences = _sentences ?? const <SentenceRef>[];
    if (_currentSentence < 0 || _currentSentence >= sentences.length) {
      _pause();
      return;
    }
    final ref0 = sentences[_currentSentence];
    _pageCtrl.ensureVisible(ref0.start);
    _applyHighlight();
    final wpm = ref.read(readingPrefsProvider).readingWpm.clamp(40.0, 600.0);
    final seconds = (ref0.wordCount / wpm * 60).clamp(0.6, 8.0);
    _timer = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      if (!mounted || !_playing) return;
      if (_currentSentence + 1 >= sentences.length) {
        _pause();
        return;
      }
      _currentSentence++;
      _tick();
    });
  }

  // --- Reading guide (scroll-linked highlight) ---

  void _toggleHelper() {
    setState(() {
      _helperOn = !_helperOn;
      if (_helperOn) {
        final sentences = _sentences ?? const <SentenceRef>[];
        if (sentences.isNotEmpty && _currentSentence < 0) {
          _currentSentence = DocumentStructure.sentenceIndexAtOffset(
              sentences, _pageCtrl.currentOffset);
        }
      } else if (!_playing) {
        _currentSentence = -1;
      }
    });
    _applyHighlight();
  }

  void _onReadingLine(int offset) {
    if (_playing || !_helperOn) return;
    final sentences = _sentences ?? const <SentenceRef>[];
    if (sentences.isEmpty) return;
    final idx = DocumentStructure.sentenceIndexAtOffset(sentences, offset);
    if (idx != _currentSentence) {
      _currentSentence = idx;
      _applyHighlight();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readingPrefsProvider);
    final palette = paletteFor(prefs.themeId);
    final entry = widget.entry;
    final canViewOriginal = entry?.pdfPath != null && entry!.pageCount > 0;
    final doc = _resolveDoc(prefs.sentencePacing);
    final sentences = _resolveSentences(doc);

    final style = TextStyle(
      fontFamily: prefs.fontFamily.family,
      fontSize: prefs.fontSizeSp,
      height: prefs.lineHeight,
      letterSpacing: prefs.letterSpacingPx,
      wordSpacing: prefs.wordSpacingPx,
      color: palette.onBackground,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.background,
      endDrawer: OutlineDrawer(
        outline: _outline ??= DocumentStructure.outline(widget.document),
        stats: _stats ??= DocumentStructure.stats(widget.document),
        onJump: _pageCtrl.jumpToOffset,
      ),
      floatingActionButton: sentences.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: palette.accent,
              foregroundColor: palette.background,
              tooltip: _playing ? 'Pause read-along' : 'Start read-along',
              onPressed: _togglePlay,
              child: Icon(_playing ? Icons.pause : Icons.play_arrow),
            ),
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Contents',
            icon: const Icon(Icons.toc),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          IconButton(
            tooltip: _helperOn ? 'Reading guide: on' : 'Reading guide: off',
            icon: Icon(Icons.highlight, color: _helperOn ? palette.accent : null),
            onPressed: _toggleHelper,
          ),
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
                document: doc,
                style: style,
                maxColumnWidth: prefs.maxLineWidthPx,
                paragraphSpacing: prefs.paragraphSpacingPx,
                bionic: prefs.bionicEnabled,
                initialOffset: entry?.readingCharOffset ?? 0,
                controller: _pageCtrl,
                highlight: _highlight,
                readingHelper: _helperOn,
                onReadingLineOffset: _onReadingLine,
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
