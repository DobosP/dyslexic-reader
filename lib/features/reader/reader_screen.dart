import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../app/theme/reading_theme.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../../domain/models/reading_prefs.dart';
import '../../domain/reflow/sentences.dart';
import '../../domain/search.dart';
import '../../domain/structure/document_structure.dart';
import '../library/library_controller.dart';
import '../settings/about_screen.dart';
import '../settings/reading_prefs_controller.dart';
import '../settings/settings_screen.dart';
import '../settings/tts_voice_screen.dart';
import 'notes_screens.dart';
import 'original_pdf_screen.dart';
import 'widgets/outline_drawer.dart';
import 'widgets/paginated_reader.dart';
import 'widgets/reading_ruler.dart';

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
  final ValueNotifier<ReadingHighlight> _highlight = ValueNotifier(
    ReadingHighlight.none,
  );

  ReadingDocument? _effectiveDoc;
  bool? _lastPacing;
  List<OutlineItem>? _outline;
  ReadingStats? _stats;

  // Current highlight chunk (≤2 rendered lines): character range [start, end).
  int _hlStart = -1;
  int _hlEnd = -1;
  bool _playing = false;
  FlutterTts? _tts;

  // Captured in initState so dispose() can persist progress without touching
  // `ref` (which Riverpod forbids once the widget has been disposed).
  late final LibraryController _library;

  // Words of the chunk currently being spoken: (spokenStart, spokenEnd,
  // absStart, absEnd). Maps the TTS progress callback's offsets (into the
  // spoken string) back to absolute document offsets for word-level highlight.
  final List<(int, int, int, int)> _spokenWords = [];

  // In-document search.
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<int> _matches = const [];
  int _matchIdx = -1;

  ReadingDocument _resolveDoc(bool pacing) {
    if (_effectiveDoc == null || _lastPacing != pacing) {
      _lastPacing = pacing;
      _effectiveDoc = pacing
          ? Sentences.splitDocument(widget.document)
          : widget.document;
    }
    return _effectiveDoc!;
  }

  /// The freshest copy of this document's library entry (so newly-added notes
  /// appear immediately), falling back to the one passed in.
  LibraryEntry? _liveEntry(List<LibraryEntry>? list) {
    final base = widget.entry;
    if (base == null) return null;
    if (list != null) {
      for (final e in list) {
        if (e.id == base.id) return e;
      }
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    _library = ref.read(libraryControllerProvider.notifier);
  }

  @override
  void dispose() {
    _tts?.stop();
    _searchCtrl.dispose();
    _highlight.dispose();
    final entry = widget.entry;
    if (entry != null) {
      _library.saveProgress(entry.id, _pageCtrl.currentOffset);
      if (_hlStart >= 0) _library.saveTtsPosition(entry.id, _hlStart);
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Push a highlight chunk into the notifier (or clear it when null).
  void _setHighlight(Chunk? chunk) {
    if (chunk == null) {
      _hlStart = -1;
      _hlEnd = -1;
      _highlight.value = ReadingHighlight.none;
      return;
    }
    _hlStart = chunk.$1;
    _hlEnd = chunk.$2;
    final accent = paletteFor(ref.read(readingPrefsProvider).themeId).accent;
    _highlight.value = ReadingHighlight(
      sentenceStart: _hlStart,
      sentenceEnd: _hlEnd,
      sentenceColor: accent.withValues(alpha: 0.22),
    );
  }

  // --- Read-aloud (text-to-speech, one ≤2-line chunk at a time) ---

  void _togglePlay() {
    if (_playing) {
      _pause();
    } else {
      _play();
    }
  }

  Future<void> _ensureTts() async {
    if (_tts != null) return;
    final tts = FlutterTts();
    tts.setCompletionHandler(_onSpoken);
    tts.setProgressHandler(_onProgress);
    _tts = tts; // set before awaiting so callers never see a null engine
    await _applyVoice(tts);
    await tts.setSpeechRate(_ttsRate());
  }

  /// Apply the user's chosen voice + pitch (best-effort; the engine may not
  /// support a given voice). Called on init and at the start of each playback
  /// so a voice changed in settings takes effect.
  Future<void> _applyVoice(FlutterTts tts) async {
    final p = ref.read(readingPrefsProvider);
    final name = p.ttsVoiceName, locale = p.ttsVoiceLocale;
    if (name != null && locale != null) {
      try {
        await tts.setVoice({'name': name, 'locale': locale});
      } catch (_) {
        // Voice unavailable on this device; fall back to the engine default.
      }
    }
    try {
      await tts.setPitch(p.ttsPitch);
    } catch (_) {}
  }

  /// Map the read-along pace (wpm) to a TTS rate (~180 wpm ≈ normal).
  double _ttsRate() =>
      (ref.read(readingPrefsProvider).readingWpm / 360).clamp(0.2, 1.0);

  double get _autoFollowAlignment {
    final p = ref.read(readingPrefsProvider);
    return p.rulerStyle.isBand ? p.rulerCenter : 0.3;
  }

  String _chunkText(int start, int end) {
    final t = widget.document.text;
    final s = start.clamp(0, t.length);
    final e = end.clamp(s, t.length);
    return t.substring(s, e).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _play() async {
    try {
      await _ensureTts();
      if (!mounted) return;
      var anchor = _hlStart;
      if (anchor < 0) {
        // Resume from the last spoken position when starting fresh.
        final saved =
            _liveEntry(
              ref.read(libraryControllerProvider).valueOrNull,
            )?.ttsCharOffset ??
            0;
        anchor = saved > 0 ? saved : _pageCtrl.currentOffset;
      }
      final start = _pageCtrl.chunkAt(anchor);
      if (start == null) return;
      await _applyVoice(_tts!);
      await _tts!.setSpeechRate(_ttsRate());
      if (!mounted) return;
      setState(() => _playing = true);
      _speak(start);
    } catch (_) {
      // Text-to-speech unavailable on this device; leave playback off.
    }
  }

  void _speak(Chunk chunk) {
    _setHighlight(chunk);
    _pageCtrl.ensureVisible(chunk.$1, alignment: _autoFollowAlignment);
    // Speak the chunk's words joined by single spaces and record each word's
    // offset in that spoken string, so the progress callback can map back to
    // absolute document offsets for word-level highlighting.
    final words = _wordsInRange(chunk.$1, chunk.$2);
    _spokenWords.clear();
    final sb = StringBuffer();
    var pos = 0;
    for (var i = 0; i < words.length; i++) {
      final t = words[i].text;
      sb.write(t);
      _spokenWords.add((pos, pos + t.length, words[i].start, words[i].end));
      pos += t.length;
      if (i != words.length - 1) {
        sb.write(' ');
        pos += 1;
      }
    }
    final spoken = sb.toString();
    _tts?.speak(spoken.isEmpty ? _chunkText(chunk.$1, chunk.$2) : spoken);
  }

  /// Document words whose character range falls within [start, end).
  List<Word> _wordsInRange(int start, int end) {
    final out = <Word>[];
    for (final p in widget.document.paragraphs) {
      if (p.end <= start || p.start >= end) continue;
      for (final w in p.words) {
        if (w.start >= start && w.end <= end) out.add(w);
      }
    }
    return out;
  }

  /// TTS word-boundary callback (Google engine on Android). Highlights the word
  /// being spoken inside the current chunk band. Engines that don't emit
  /// progress events simply leave the chunk-level highlight in place.
  void _onProgress(String text, int start, int end, String word) {
    if (!mounted || !_playing || _spokenWords.isEmpty || _hlStart < 0) return;
    (int, int, int, int)? hit;
    for (final sw in _spokenWords) {
      if (start < sw.$2 && end > sw.$1) {
        hit = sw;
        break;
      }
    }
    if (hit == null) {
      for (final sw in _spokenWords) {
        if (start >= sw.$1 && start < sw.$2) {
          hit = sw;
          break;
        }
      }
    }
    if (hit == null) return;
    final accent = paletteFor(ref.read(readingPrefsProvider).themeId).accent;
    _highlight.value = ReadingHighlight(
      sentenceStart: _hlStart,
      sentenceEnd: _hlEnd,
      sentenceColor: accent.withValues(alpha: 0.18),
      wordStart: hit.$3,
      wordEnd: hit.$4,
      wordColor: accent.withValues(alpha: 0.5),
    );
    _pageCtrl.ensureVisible(hit.$3, alignment: _autoFollowAlignment);
  }

  /// Called when the engine finishes a chunk: advance to the next one.
  void _onSpoken() {
    if (!mounted || !_playing) return;
    final next = _pageCtrl.nextChunkAfter(_hlStart);
    if (next == null) {
      _pause();
      return;
    }
    _speak(next);
  }

  Future<void> _pause() async {
    await _tts?.stop();
    if (!mounted) return;
    setState(() => _playing = false);
    final entry = widget.entry;
    if (entry != null && _hlStart >= 0) {
      await ref
          .read(libraryControllerProvider.notifier)
          .saveTtsPosition(entry.id, _hlStart);
    }
  }

  /// Jump the read-aloud roughly [seconds] forward (positive) or back.
  Future<void> _skip(int seconds) async {
    if (!_playing || _hlStart < 0) return;
    await _tts?.stop();
    if (!mounted) return;
    final target = seconds >= 0
        ? _chunkAfterSeconds(seconds)
        : _chunkBeforeSeconds(-seconds);
    if (target != null) _speak(target);
  }

  Chunk? _chunkAfterSeconds(int seconds) {
    final wpm = ref.read(readingPrefsProvider).readingWpm.clamp(60.0, 400.0);
    var acc = 0.0;
    var cur = _pageCtrl.chunkAt(_hlStart);
    var start = _hlStart;
    while (acc < seconds) {
      final next = _pageCtrl.nextChunkAfter(start);
      if (next == null) break;
      acc += next.$3 / wpm * 60;
      cur = next;
      start = next.$1;
    }
    return cur;
  }

  Chunk? _chunkBeforeSeconds(int seconds) {
    final wpm = ref.read(readingPrefsProvider).readingWpm.clamp(60.0, 400.0);
    var acc = 0.0;
    var cur = _pageCtrl.chunkAt(_hlStart);
    var start = _hlStart;
    while (acc < seconds) {
      final prev = _pageCtrl.prevChunkBefore(start);
      if (prev == null) break;
      acc += prev.$3 / wpm * 60;
      cur = prev;
      start = prev.$1;
    }
    return cur;
  }

  // --- Reading focus: main line highlight (scroll-linked) ---

  /// True when the main reading-focus utility (the line highlight) is on. The
  /// optional band modes are drawn separately by [ReadingRulerOverlay].
  bool get _focusHighlight => ref.read(readingPrefsProvider).lineHighlight;

  void _onReadingChunk(Chunk chunk) {
    if (_playing || !_focusHighlight) return;
    if (chunk.$1 != _hlStart || chunk.$2 != _hlEnd) {
      _setHighlight(chunk);
    }
  }

  /// React to the line-highlight toggle: light up / clear the in-text highlight
  /// immediately (unless read-aloud is already driving the highlight).
  void _onLineHighlightChanged(bool on) {
    if (_playing) return;
    if (on) {
      _setHighlight(_pageCtrl.chunkAt(_pageCtrl.currentOffset));
    } else {
      _setHighlight(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readingPrefsProvider);
    final palette = paletteFor(prefs.themeId);
    // Keep the in-text highlight in step with the line-highlight toggle.
    ref.listen(readingPrefsProvider.select((p) => p.lineHighlight), (_, next) {
      _onLineHighlightChanged(next);
    });
    final entry = _liveEntry(ref.watch(libraryControllerProvider).valueOrNull);
    final notes = entry?.notes ?? const <Note>[];
    final canViewOriginal = entry?.pdfPath != null && entry!.pageCount > 0;
    final doc = _resolveDoc(prefs.sentencePacing);

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
        outline: _outline ??= entry?.pdfOutline.isNotEmpty == true
            ? entry!.pdfOutline
            : DocumentStructure.outline(widget.document),
        stats: _stats ??= DocumentStructure.stats(widget.document),
        onJump: _pageCtrl.jumpToOffset,
      ),
      floatingActionButton: doc.paragraphs.isEmpty
          ? null
          : Semantics(
              // liveRegion lets TalkBack announce the play/pause change (the
              // Android-supported alternative to push announcements).
              liveRegion: true,
              label: _playing ? 'Reading aloud' : 'Read aloud',
              child: FloatingActionButton(
                backgroundColor: palette.accent,
                foregroundColor: palette.background,
                tooltip: _playing ? 'Pause' : 'Read aloud',
                onPressed: _togglePlay,
                child: Icon(_playing ? Icons.pause : Icons.volume_up),
              ),
            ),
      appBar: _searching
          ? _searchAppBar(palette)
          : _readerAppBar(palette, entry, canViewOriginal),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PaginatedReader(
                    document: doc,
                    style: style,
                    maxColumnWidth: prefs.maxLineWidthPx,
                    paragraphSpacing: prefs.paragraphSpacingPx,
                    bionic: prefs.bionicEnabled,
                    initialOffset: entry?.readingCharOffset ?? 0,
                    controller: _pageCtrl,
                    highlight: _highlight,
                    readingHelper: _focusHighlight,
                    onReadingChunk: _onReadingChunk,
                    highlightMaxRows: prefs.highlightMaxRows,
                    noteRanges: [for (final n in notes) (n.start, n.end)],
                    noteColor: palette.accent,
                    onTextTap: entry == null ? null : _onTextTap,
                    onNoteTap: entry == null ? null : _onTextTap,
                    continuous: prefs.readerContinuous,
                  ),
                  if (prefs.rulerStyle.isBand)
                    Positioned.fill(
                      child: ReadingRulerOverlay(
                        style: prefs.rulerStyle,
                        palette: palette,
                        bandHeight:
                            prefs.fontSizeSp *
                                prefs.lineHeight *
                                prefs.rulerRows +
                            8,
                        center: prefs.rulerCenter,
                      ),
                    ),
                ],
              ),
            ),
            if (_playing) _ttsBar(palette),
            if (!prefs.readerContinuous)
              _PageBar(controller: _pageCtrl, palette: palette),
          ],
        ),
      ),
    );
  }

  Widget _ttsBar(ReadingPalette palette) {
    return Material(
      color: palette.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Reading speed',
              icon: const Icon(Icons.speed),
              onPressed: _quickSpeed,
            ),
            TextButton.icon(
              onPressed: () => _skip(-15),
              icon: const Icon(Icons.fast_rewind),
              label: const Text('15s'),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              onPressed: _pause,
              icon: const Icon(Icons.pause),
              tooltip: 'Pause',
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => _skip(15),
              icon: const Icon(Icons.fast_forward),
              label: const Text('15s'),
            ),
            IconButton(
              tooltip: 'Read-aloud voice',
              icon: const Icon(Icons.record_voice_over_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TtsVoiceScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// In-reader read-aloud speed control (applies live to the next chunk).
  void _quickSpeed() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final wpm = ref.watch(
            readingPrefsProvider.select((p) => p.readingWpm),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading speed: ${wpm.round()} words/min'),
                Slider(
                  value: wpm,
                  min: 60,
                  max: 400,
                  divisions: 34,
                  label: '${wpm.round()} wpm',
                  onChanged: (v) {
                    ref.read(readingPrefsProvider.notifier).setReadingWpm(v);
                    _tts?.setSpeechRate(_ttsRate());
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- App bars (normal + search) ---

  PreferredSizeWidget _readerAppBar(
    ReadingPalette palette,
    LibraryEntry? entry,
    bool canViewOriginal,
  ) {
    final focusOn =
        ref.read(readingPrefsProvider).rulerStyle != ReadingRulerStyle.off;
    return AppBar(
      backgroundColor: palette.background,
      foregroundColor: palette.onBackground,
      title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Search in document',
          icon: const Icon(Icons.search),
          onPressed: _openSearch,
        ),
        IconButton(
          tooltip: 'Text & display',
          icon: const Icon(Icons.text_fields),
          onPressed: _textSheet,
        ),
        IconButton(
          tooltip: 'Reading focus',
          icon: Icon(
            Icons.center_focus_strong,
            color: focusOn ? palette.accent : null,
          ),
          onPressed: _focusSheet,
        ),
        if (entry != null)
          IconButton(
            tooltip: 'Notes & bookmarks',
            icon: const Icon(Icons.edit_note),
            onPressed: () => _annotationsSheet(entry),
          ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) => _onMenu(v, entry),
          itemBuilder: (_) => [
            _menuItem('contents', Icons.toc, 'Contents'),
            if (canViewOriginal)
              _menuItem(
                'original',
                Icons.picture_as_pdf_outlined,
                'Original pages',
              ),
            _menuItem('settings', Icons.tune, 'Reading settings'),
            _menuItem('about', Icons.info_outline, 'About'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }

  void _onMenu(String value, LibraryEntry? entry) {
    switch (value) {
      case 'contents':
        _scaffoldKey.currentState?.openEndDrawer();
      case 'settings':
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      case 'about':
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
      case 'original':
        if (entry?.pdfPath != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OriginalPdfScreen(
                title: widget.document.title,
                pdfPath: entry!.pdfPath!,
                pageCount: entry.pageCount,
              ),
            ),
          );
        }
    }
  }

  PreferredSizeWidget _searchAppBar(ReadingPalette palette) {
    final q = _searchCtrl.text.trim();
    final status = _matches.isNotEmpty
        ? '${_matchIdx + 1}/${_matches.length}'
        : (q.length >= 2 ? 'None' : '');
    return AppBar(
      backgroundColor: palette.background,
      foregroundColor: palette.onBackground,
      leading: IconButton(
        tooltip: 'Close search',
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchCtrl,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: palette.onBackground),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          hintText: 'Search in document',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: palette.onBackground.withValues(alpha: 0.5),
          ),
        ),
        onChanged: _runSearch,
        onSubmitted: (_) {
          if (_matches.isNotEmpty) _gotoMatch(_matchIdx + 1);
        },
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(status, style: TextStyle(color: palette.onBackground)),
          ),
        ),
        IconButton(
          tooltip: 'Previous match',
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: _matches.isEmpty ? null : () => _gotoMatch(_matchIdx - 1),
        ),
        IconButton(
          tooltip: 'Next match',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: _matches.isEmpty ? null : () => _gotoMatch(_matchIdx + 1),
        ),
      ],
    );
  }

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    setState(() {
      _searching = false;
      _matches = const [];
      _matchIdx = -1;
      _searchCtrl.clear();
    });
    // Restore the reading highlight (or clear it) now the search flash is gone.
    if (!_playing) {
      if (_focusHighlight) {
        _setHighlight(_pageCtrl.chunkAt(_pageCtrl.currentOffset));
      } else {
        _highlight.value = ReadingHighlight.none;
        _hlStart = -1;
        _hlEnd = -1;
      }
    }
  }

  /// Find every case-insensitive occurrence of the query in the document text
  /// and jump to the first. Pure Dart, capped to keep huge documents snappy.
  void _runSearch(String raw) {
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _matches = const [];
        _matchIdx = -1;
      });
      return;
    }
    final found = findMatches(widget.document.text, q);
    setState(() {
      _matches = found;
      _matchIdx = found.isEmpty ? -1 : 0;
    });
    if (found.isNotEmpty) _gotoMatch(0);
  }

  void _gotoMatch(int i) {
    if (_matches.isEmpty) return;
    final n = _matches.length;
    final idx = ((i % n) + n) % n; // wrap around both directions
    setState(() => _matchIdx = idx);
    final off = _matches[idx];
    _pageCtrl.jumpToOffset(off);
    final accent = paletteFor(ref.read(readingPrefsProvider).themeId).accent;
    _highlight.value = ReadingHighlight(
      sentenceStart: off,
      sentenceEnd: off + _searchCtrl.text.trim().length,
      sentenceColor: accent.withValues(alpha: 0.55),
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
    ref
        .read(libraryControllerProvider.notifier)
        .addBookmark(
          entry.id,
          Bookmark(
            offset: offset,
            label: _snippet(offset),
            createdAt: DateTime.now(),
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark saved'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showBookmarks(String id) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final list =
              ref.watch(libraryControllerProvider).valueOrNull ?? const [];
          LibraryEntry? entry;
          for (final e in list) {
            if (e.id == id) entry = e;
          }
          final bookmarks = entry?.bookmarks ?? const <Bookmark>[];
          if (bookmarks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No bookmarks yet. Tap the bookmark icon to save your place.',
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final b in bookmarks)
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(
                    b.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

  // --- Notes (long-press a sentence to annotate it) ---

  void _onTextTap(int start, int end) {
    final entry = widget.entry;
    if (entry == null) return;
    final live =
        _liveEntry(ref.read(libraryControllerProvider).valueOrNull) ?? entry;
    Note? existing;
    for (final n in live.notes) {
      if (n.start == start && n.end == end) {
        existing = n;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(
          entryId: entry.id,
          start: start,
          end: end,
          snippet: _snippet(start),
          initialText: existing?.text ?? '',
          isEditing: existing != null,
        ),
      ),
    );
  }

  /// Add a note at the current reading position — a screen-reader-friendly
  /// alternative to long-pressing a sentence (which TalkBack users can't do).
  void _addNoteHere() {
    if (widget.entry == null) return;
    final chunk = _pageCtrl.chunkAt(_pageCtrl.currentOffset);
    if (chunk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to annotate here yet')),
      );
      return;
    }
    _onTextTap(chunk.$1, chunk.$2);
  }

  Future<void> _showNotes(String id) async {
    final offset = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => NotesListScreen(entryId: id, snippetFor: _snippet),
      ),
    );
    if (!mounted || offset == null) return;
    _pageCtrl.jumpToOffset(offset);
  }

  // --- Grouped quick-sheets (text · reading focus · annotations) ---

  void _openFullSettings(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  /// Text & display: the few most-used type controls, with a link to the rest.
  void _textSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final prefs = ref.watch(readingPrefsProvider);
          final c = ref.read(readingPrefsProvider.notifier);
          return _SheetBody(
            title: 'Text & display',
            children: [
              const _SheetLabel('Theme'),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ReadingThemeId.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: prefs.themeId == t,
                      onSelected: (_) => c.setTheme(t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const _SheetLabel('Font'),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in ReadingFontFamily.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: prefs.fontFamily == f,
                      onSelected: (_) => c.setFont(f),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _SheetSlider(
                label: 'Text size',
                value: prefs.fontSizeSp,
                min: 12,
                max: 40,
                divisions: 28,
                display: prefs.fontSizeSp.round().toString(),
                onChanged: c.setFontSize,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('All text settings'),
                  onPressed: () => _openFullSettings(sheetContext),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Reading focus: the unified line-focus aid (highlight + ruler bands).
  void _focusSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final prefs = ref.watch(readingPrefsProvider);
          final c = ref.read(readingPrefsProvider.notifier);
          return _SheetBody(
            title: 'Reading focus',
            children: [
              Text(
                'Pick one way to keep your place — it follows your reading. '
                'Highlight tints the current line; the bands rest a strip on it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in ReadingRulerStyle.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: prefs.rulerStyle == r,
                      onSelected: (_) => c.setRulerStyle(r),
                    ),
                ],
              ),
              if (prefs.rulerStyle != ReadingRulerStyle.off) ...[
                const SizedBox(height: 14),
                const _SheetLabel('Focus height'),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1 line')),
                      ButtonSegment(value: 2, label: Text('2 lines')),
                      ButtonSegment(value: 3, label: Text('3 lines')),
                    ],
                    selected: {prefs.rulerRows.clamp(1, 3)},
                    onSelectionChanged: (s) => c.setFocusRows(s.first),
                    showSelectedIcon: false,
                  ),
                ),
              ],
              if (prefs.rulerStyle.isBand) ...[
                const SizedBox(height: 12),
                _SheetSlider(
                  label: 'Band position',
                  value: prefs.rulerCenter,
                  min: 0.15,
                  max: 0.85,
                  divisions: 14,
                  display: '${(prefs.rulerCenter * 100).round()}%',
                  onChanged: c.setRulerCenter,
                ),
              ],
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sentence pacing'),
                subtitle: const Text('Show each sentence as its own block.'),
                value: prefs.sentencePacing,
                onChanged: c.setSentencePacing,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('More settings'),
                  onPressed: () => _openFullSettings(sheetContext),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Notes & bookmarks: add at the current spot, or open the full lists.
  void _annotationsSheet(LibraryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _SheetBody(
        title: 'Notes & bookmarks',
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('Add note here'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _addNoteHere();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_add_outlined),
            title: const Text('Bookmark this page'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _addBookmark(entry);
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notes_outlined),
            title: const Text('View notes'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _showNotes(entry.id);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmarks_outlined),
            title: const Text('View bookmarks'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _showBookmarks(entry.id);
            },
          ),
        ],
      ),
    );
  }
}

/// Standard padded body for the reader's grouped quick-sheets.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

class _SheetSlider extends StatelessWidget {
  const _SheetSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(display, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
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
