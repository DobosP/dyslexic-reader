import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/paginator.dart';
import '../../../domain/reflow/sentences.dart';
import 'paragraph_span.dart';

/// A highlight chunk: (startOffset, endOffset, wordCount).
typedef Chunk = (int, int, int);

/// The currently-highlighted run (read-along pacer / reading guide). Driven via
/// a [ValueListenable] so updates repaint only the visible paragraphs.
class ReadingHighlight {
  const ReadingHighlight({
    this.sentenceStart = -1,
    this.sentenceEnd = -1,
    this.sentenceColor,
  });

  final int sentenceStart;
  final int sentenceEnd;
  final Color? sentenceColor;

  static const none = ReadingHighlight();
}

/// Lets the screen observe and drive the reader (page N/M, jumps, chunks).
class PageReaderController extends ChangeNotifier {
  int pageIndex = 0;
  int pageCount = 1;
  int currentOffset = 0;
  bool complete = false;

  void Function(int offset)? _jumpToOffset;
  void Function(int page)? _goToPage;
  void Function(int offset)? _ensureVisibleFn;
  Chunk? Function(int offset)? _chunkAtFn;
  Chunk? Function(int offset)? _nextChunkFn;
  Chunk? Function(int offset)? _prevChunkFn;

  void jumpToOffset(int offset) => _jumpToOffset?.call(offset);
  void goToPage(int page) => _goToPage?.call(page);
  void next() => _goToPage?.call(pageIndex + 1);
  void prev() => _goToPage?.call(pageIndex - 1);
  void ensureVisible(int offset) => _ensureVisibleFn?.call(offset);
  Chunk? chunkAt(int offset) => _chunkAtFn?.call(offset);
  Chunk? nextChunkAfter(int offset) => _nextChunkFn?.call(offset);
  Chunk? prevChunkBefore(int offset) => _prevChunkFn?.call(offset);

  void _bind({
    required void Function(int) jumpToOffset,
    required void Function(int) goToPage,
    required void Function(int) ensureVisible,
    required Chunk? Function(int) chunkAt,
    required Chunk? Function(int) nextChunkAfter,
    required Chunk? Function(int) prevChunkBefore,
  }) {
    _jumpToOffset = jumpToOffset;
    _goToPage = goToPage;
    _ensureVisibleFn = ensureVisible;
    _chunkAtFn = chunkAt;
    _nextChunkFn = nextChunkAfter;
    _prevChunkFn = prevChunkBefore;
  }

  void _update({int? pageIndex, int? pageCount, int? currentOffset, bool? complete}) {
    var changed = false;
    if (pageIndex != null && pageIndex != this.pageIndex) {
      this.pageIndex = pageIndex;
      changed = true;
    }
    if (pageCount != null && pageCount != this.pageCount) {
      this.pageCount = pageCount;
      changed = true;
    }
    if (currentOffset != null) this.currentOffset = currentOffset;
    if (complete != null && complete != this.complete) {
      this.complete = complete;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

/// Per-page measurements (cached): paragraph tops + each paragraph's ≤2-line
/// highlight chunks with their cumulative heights.
class _PageMetrics {
  _PageMetrics(this.paragraphTop, this.chunks, this.chunkCumHeight);

  final List<double> paragraphTop;
  final List<List<Chunk>> chunks;
  final List<List<double>> chunkCumHeight;
}

class PaginatedReader extends StatefulWidget {
  const PaginatedReader({
    super.key,
    required this.document,
    required this.style,
    required this.maxColumnWidth,
    required this.paragraphSpacing,
    required this.bionic,
    required this.initialOffset,
    this.onOffsetChanged,
    this.controller,
    this.highlight,
    this.readingHelper = false,
    this.onReadingChunk,
    this.highlightMaxRows = 2,
    this.noteRanges = const [],
    this.onTextTap,
    this.noteColor,
    this.continuous = false,
  });

  final ReadingDocument document;
  final TextStyle style;
  final double maxColumnWidth;
  final double paragraphSpacing;
  final bool bionic;
  final int initialOffset;
  final ValueChanged<int>? onOffsetChanged;
  final PageReaderController? controller;
  final ValueListenable<ReadingHighlight>? highlight;

  /// When true, reports the chunk at the reading line as the user scrolls.
  final bool readingHelper;
  final ValueChanged<Chunk>? onReadingChunk;

  /// How many rendered rows a highlight chunk spans at most (1, 2, or 3).
  final int highlightMaxRows;

  /// Character ranges the user has annotated (dotted-underlined in the text).
  final List<(int, int)> noteRanges;

  /// Called when the user long-presses text, with the sentence range hit.
  final void Function(int start, int end)? onTextTap;
  final Color? noteColor;

  /// Continuous scroll (one paragraph per item) instead of fixed pages.
  final bool continuous;

  @override
  State<PaginatedReader> createState() => _PaginatedReaderState();
}

class _PaginatedReaderState extends State<PaginatedReader> {
  static const double _hPad = 20;
  static const double _vPad = 16;
  static const int _lookahead = 4;

  final ItemScrollController _itemScroll = ItemScrollController();
  final ItemPositionsListener _itemPositions = ItemPositionsListener.create();

  LazyPaginator? _paginator;
  List<ReaderPage> _pages = [];
  final Map<int, _PageMetrics> _metricsCache = {};
  bool _complete = false;
  int _generation = 0;
  String _signature = '';
  int _targetOffset = 0;
  int _initialIndex = 0;
  int _topIndex = 0;

  double _vh = 0;
  double _cw = 1;
  double _itemVPad = _vPad;
  TextScaler _ts = const TextScaler.linear(1);

  @override
  void initState() {
    super.initState();
    _targetOffset = widget.initialOffset;
    widget.controller?._bind(
      jumpToOffset: _jumpToOffset,
      goToPage: _animateToPage,
      ensureVisible: _ensureVisible,
      chunkAt: _chunkAt,
      nextChunkAfter: _nextChunkAfter,
      prevChunkBefore: _prevChunkBefore,
    );
    _itemPositions.itemPositions.addListener(_onPositions);
  }

  @override
  void dispose() {
    _generation++;
    _itemPositions.itemPositions.removeListener(_onPositions);
    super.dispose();
  }

  void _onPositions() {
    final positions = _itemPositions.itemPositions.value;
    if (positions.isEmpty || _pages.isEmpty) return;
    final visible = positions.where((p) => p.itemTrailingEdge > 0);
    if (visible.isEmpty) return;
    final top = visible.reduce((a, b) => a.index < b.index ? a : b).index;
    final maxVisible = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);

    _topIndex = top.clamp(0, _pages.length - 1);
    _targetOffset = _pages[_topIndex].start;
    _notify(_topIndex);
    widget.onOffsetChanged?.call(_targetOffset);

    if (!_complete && maxVisible >= _pages.length - _lookahead) {
      _ensureComputedForPage(maxVisible + _lookahead);
      setState(() {});
    }

    if (widget.readingHelper && widget.onReadingChunk != null) {
      final chunk = _readingLineChunk(positions);
      if (chunk != null) widget.onReadingChunk!(chunk);
    }
  }

  /// The chunk whose vertical centre is nearest the reading line (~⅓ down the
  /// viewport), scanning every visible chunk so a page boundary never skips the
  /// last chunk of a page.
  Chunk? _readingLineChunk(Iterable<ItemPosition> positions) {
    const band = 0.3;
    if (_vh <= 0) return null;
    Chunk? best;
    var bestDist = double.infinity;
    for (final p in positions) {
      if (p.index < 0 || p.index >= _pages.length) continue;
      if (p.itemTrailingEdge <= 0 || p.itemLeadingEdge >= 1) continue;
      final m = _metricsFor(p.index, _pages[p.index]);
      for (var pi = 0; pi < m.chunks.length; pi++) {
        final chunks = m.chunks[pi];
        final cum = m.chunkCumHeight[pi];
        for (var k = 0; k < chunks.length; k++) {
          final topPx = m.paragraphTop[pi] + (k > 0 ? cum[k - 1] : 0.0);
          final botPx = m.paragraphTop[pi] + cum[k];
          final centerFrac = p.itemLeadingEdge + ((topPx + botPx) / 2) / _vh;
          final dist = (centerFrac - band).abs();
          if (dist < bestDist) {
            bestDist = dist;
            best = chunks[k];
          }
        }
      }
    }
    return best;
  }

  Chunk? _chunkAt(int offset) {
    _ensureComputedForOffset(offset);
    final pageIndex = Paginator.pageForOffset(_pages, offset);
    if (pageIndex < 0 || pageIndex >= _pages.length) return null;
    final m = _metricsFor(pageIndex, _pages[pageIndex]);
    Chunk? last;
    for (final pc in m.chunks) {
      for (final c in pc) {
        if (c.$1 <= offset && offset < c.$2) return c;
        if (c.$1 <= offset) last = c;
      }
    }
    if (last != null) return last;
    for (final pc in m.chunks) {
      if (pc.isNotEmpty) return pc.first;
    }
    return null;
  }

  Chunk? _nextChunkAfter(int offset) {
    _ensureComputedForOffset(offset);
    var pageIndex = Paginator.pageForOffset(_pages, offset);
    if (pageIndex < 0) pageIndex = 0;
    while (true) {
      if (pageIndex >= _pages.length) {
        if (!(_paginator?.hasMore ?? false)) return null;
        _ensureComputedForPage(pageIndex);
        if (pageIndex >= _pages.length) return null;
      }
      final m = _metricsFor(pageIndex, _pages[pageIndex]);
      for (final pc in m.chunks) {
        for (final c in pc) {
          if (c.$1 > offset) return c;
        }
      }
      pageIndex++;
    }
  }

  Chunk? _prevChunkBefore(int offset) {
    _ensureComputedForOffset(offset);
    var pageIndex = Paginator.pageForOffset(_pages, offset);
    if (pageIndex < 0) pageIndex = 0;
    for (var pi = pageIndex; pi >= 0; pi--) {
      if (pi >= _pages.length) continue;
      final m = _metricsFor(pi, _pages[pi]);
      Chunk? best;
      for (final pc in m.chunks) {
        for (final c in pc) {
          if (c.$1 < offset) best = c;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  _PageMetrics _metricsFor(int pageIndex, ReaderPage page) {
    return _metricsCache.putIfAbsent(pageIndex, () {
      final tops = <double>[];
      final chunks = <List<Chunk>>[];
      final cums = <List<double>>[];
      var acc = _itemVPad;
      for (var i = 0; i < page.paragraphs.length; i++) {
        final para = page.paragraphs[i];
        if (i > 0) {
          acc += para.role == BlockRole.body
              ? widget.paragraphSpacing
              : widget.paragraphSpacing * 1.8;
        }
        final pStyle = styleForRole(para.role, widget.style);
        tops.add(acc);
        final (pc, cum) = _paragraphChunks(para, pStyle);
        chunks.add(pc);
        cums.add(cum);
        acc += _measure(para.text, pStyle, _cw, _ts);
      }
      return _PageMetrics(tops, chunks, cums);
    });
  }

  /// Split a paragraph into chunks of at most ~2 rendered lines, preferring to
  /// end at a sentence boundary when one falls in the second half of the chunk.
  (List<Chunk>, List<double>) _paragraphChunks(PageParagraph para, TextStyle pStyle) {
    final words = para.words;
    final chunks = <Chunk>[];
    final cum = <double>[];
    if (words.isEmpty) return (chunks, cum);
    final lh = (pStyle.fontSize ?? 18.0) * (pStyle.height ?? 1.4);

    var i = 0;
    var acc = 0.0;
    while (i < words.length) {
      final remaining = words.length - i;
      var lo = 1, hi = remaining, fit = 1;
      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;
        final h = _measure(_joinWords(words, i, mid), pStyle, _cw, _ts);
        if (lh <= 0 || (h / lh).round() <= widget.highlightMaxRows) {
          fit = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      final end = (i + fit - 1).clamp(i, words.length - 1);
      var breakAt = end;
      final minBreak = i + (fit ~/ 2);
      for (var k = end; k >= minBreak && k >= i; k--) {
        if (Sentences.endsSentence(words[k].text)) {
          breakAt = k;
          break;
        }
      }
      chunks.add((words[i].start, words[breakAt].end, breakAt - i + 1));
      acc += _measure(_joinWords(words, i, breakAt - i + 1), pStyle, _cw, _ts);
      cum.add(acc);
      i = breakAt + 1;
    }
    return (chunks, cum);
  }

  String _joinWords(List<Word> words, int from, int count) =>
      words.sublist(from, from + count).map((w) => w.text).join(' ');

  void _jumpToOffset(int offset) {
    _targetOffset = offset;
    _ensureComputedForOffset(offset);
    _animateToPage(Paginator.pageForOffset(_pages, offset));
  }

  void _ensureVisible(int offset) {
    if (widget.continuous) {
      _ensureVisibleContinuous(offset);
      return;
    }
    _ensureComputedForOffset(offset);
    final page = Paginator.pageForOffset(_pages, offset);
    final onScreen = _itemPositions.itemPositions.value.any(
      (p) => p.index == page && p.itemTrailingEdge > 0.08 && p.itemLeadingEdge < 0.92,
    );
    if (onScreen) return;
    _animateToPage(page);
  }

  /// Keep the current chunk comfortably in view (also handles paragraphs taller
  /// than the viewport): scroll only when it drifts out of a comfort band.
  void _ensureVisibleContinuous(int offset) {
    if (_pages.isEmpty || _vh <= 0) return;
    final page = Paginator.pageForOffset(_pages, offset).clamp(0, _pages.length - 1);
    final top = _offsetTopInItem(page, offset);
    for (final p in _itemPositions.itemPositions.value) {
      if (p.index == page) {
        final frac = p.itemLeadingEdge + top / _vh;
        if (frac >= 0.12 && frac <= 0.82) return; // already comfortable
        break;
      }
    }
    final align = (0.18 - top / _vh).clamp(0.0, 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScroll.isAttached) return;
      _itemScroll.scrollTo(
        index: page,
        alignment: align,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Vertical px from an item's top to the chunk containing [offset].
  double _offsetTopInItem(int pageIndex, int offset) {
    final m = _metricsFor(pageIndex, _pages[pageIndex]);
    for (var pi = 0; pi < m.chunks.length; pi++) {
      final chunks = m.chunks[pi];
      final cum = m.chunkCumHeight[pi];
      for (var k = 0; k < chunks.length; k++) {
        if (offset < chunks[k].$2) {
          return m.paragraphTop[pi] + (k > 0 ? cum[k - 1] : 0.0);
        }
      }
    }
    return m.paragraphTop.isNotEmpty ? m.paragraphTop.first : _itemVPad;
  }

  void _animateToPage(int page) {
    _ensureComputedForPage(page);
    final target = page.clamp(0, _pages.length - 1);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScroll.isAttached) return;
      _itemScroll.scrollTo(
        index: target,
        alignment: widget.continuous ? 0.08 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  double _measure(String text, TextStyle style, double maxWidth, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth <= 0 ? 1 : maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  void _ensureComputedForOffset(int offset) {
    final p = _paginator;
    if (p == null) return;
    while (p.hasMore && !(_pages.length >= 2 && _pages.last.start > offset)) {
      final page = p.next();
      if (page == null) break;
      _pages.add(page);
    }
    if (!p.hasMore) _complete = true;
  }

  void _ensureComputedForPage(int pageIndex) {
    final p = _paginator;
    if (p == null) return;
    while (p.hasMore && _pages.length <= pageIndex + _lookahead) {
      final page = p.next();
      if (page == null) break;
      _pages.add(page);
    }
    if (!p.hasMore) _complete = true;
  }

  /// Continuous mode: one item per document paragraph (no fixed pages).
  List<ReaderPage> _continuousPages(ReadingDocument doc) => [
        for (final p in doc.paragraphs)
          ReaderPage(
            paragraphs: [
              PageParagraph(words: p.words, start: p.start, end: p.end, role: p.role),
            ],
            start: p.start,
            end: p.end,
          ),
      ];

  void _startBackgroundFill(int gen) {
    Future(() async {
      final p = _paginator;
      if (p == null) return;
      while (mounted && gen == _generation && p.hasMore) {
        for (var k = 0; k < 12 && p.hasMore; k++) {
          final page = p.next();
          if (page == null) break;
          _pages.add(page);
        }
        if (!p.hasMore) _complete = true;
        if (!mounted || gen != _generation) return;
        setState(() {});
        _notify(_topIndex);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth - 2 * _hPad;
        final colWidth =
            availWidth <= 1 ? 1.0 : widget.maxColumnWidth.clamp(1.0, availWidth);
        final pageHeight =
            (constraints.maxHeight - 2 * _vPad).clamp(1.0, double.infinity);
        final scaler = MediaQuery.textScalerOf(context);
        _vh = constraints.maxHeight;
        _cw = colWidth;
        _ts = scaler;
        _itemVPad = widget.continuous
            ? (widget.paragraphSpacing / 2).clamp(4.0, 20.0)
            : _vPad;

        final signature = [
          identityHashCode(widget.document),
          widget.style.fontSize,
          widget.style.height,
          widget.style.letterSpacing,
          widget.style.wordSpacing,
          widget.style.fontFamily,
          widget.bionic,
          colWidth.floor(),
          widget.continuous ? 0 : pageHeight.floor(),
          widget.paragraphSpacing.floor(),
          widget.highlightMaxRows,
          widget.continuous,
        ].join('|');

        if (signature != _signature) {
          _signature = signature;
          _generation++;
          _metricsCache.clear();
          final gen = _generation;
          if (widget.continuous) {
            _paginator = null;
            _pages = _continuousPages(widget.document);
            _complete = true;
          } else {
            _paginator = LazyPaginator(
              doc: widget.document,
              maxHeight: pageHeight,
              paragraphSpacing: widget.paragraphSpacing,
              measure: (text, role) =>
                  _measure(text, styleForRole(role, widget.style), colWidth, scaler),
            );
            _pages = [];
            _complete = false;
            _ensureComputedForOffset(_targetOffset);
          }
          _initialIndex = Paginator.pageForOffset(_pages, _targetOffset);
          _topIndex = _initialIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || gen != _generation) return;
            if (_itemScroll.isAttached) _itemScroll.jumpTo(index: _initialIndex);
            _notify(_initialIndex);
            if (!widget.continuous) _startBackgroundFill(gen);
          });
        }

        if (_pages.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No readable text in this document.'),
            ),
          );
        }

        return ScrollablePositionedList.builder(
          itemCount: _pages.length,
          itemScrollController: _itemScroll,
          itemPositionsListener: _itemPositions,
          initialScrollIndex: _initialIndex,
          itemBuilder: (context, i) => _PageBody(
            page: _pages[i],
            style: widget.style,
            columnWidth: colWidth,
            paragraphSpacing: widget.paragraphSpacing,
            bionic: widget.bionic,
            horizontalPadding: _hPad,
            verticalPadding: _itemVPad,
            highlight: widget.highlight,
            noteRanges: widget.noteRanges,
            noteColor: widget.noteColor,
            onTextTap: widget.onTextTap,
            textScaler: scaler,
          ),
        );
      },
    );
  }

  void _notify(int page) {
    final ctrl = widget.controller;
    if (ctrl == null || _pages.isEmpty) return;
    final clamped = page.clamp(0, _pages.length - 1);
    ctrl._update(
      pageIndex: clamped,
      pageCount: _pages.length,
      currentOffset: _pages[clamped].start,
      complete: _complete,
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.page,
    required this.style,
    required this.columnWidth,
    required this.paragraphSpacing,
    required this.bionic,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.highlight,
    required this.noteRanges,
    required this.noteColor,
    required this.onTextTap,
    required this.textScaler,
  });

  final ReaderPage page;
  final TextStyle style;
  final double columnWidth;
  final double paragraphSpacing;
  final bool bionic;
  final double horizontalPadding;
  final double verticalPadding;
  final ValueListenable<ReadingHighlight>? highlight;
  final List<(int, int)> noteRanges;
  final Color? noteColor;
  final void Function(int start, int end)? onTextTap;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: columnWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < page.paragraphs.length; i++) ...[
                if (i > 0)
                  SizedBox(
                    height: page.paragraphs[i].role == BlockRole.body
                        ? paragraphSpacing
                        : paragraphSpacing * 1.8,
                  ),
                _wrap(page.paragraphs[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrap(PageParagraph p) {
    final body = _paragraph(p);
    final cb = onTextTap;
    if (cb == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => _handleLongPress(p, d.localPosition),
      child: body,
    );
  }

  Widget _paragraph(PageParagraph p) {
    final listenable = highlight;
    if (listenable == null) return _styled(p, ReadingHighlight.none);
    return ValueListenableBuilder<ReadingHighlight>(
      valueListenable: listenable,
      builder: (_, h, _) => _styled(p, h),
    );
  }

  Widget _styled(PageParagraph p, ReadingHighlight h) {
    final ranges = noteRanges.isEmpty
        ? const <(int, int)>[]
        : [for (final r in noteRanges) if (p.start < r.$2 && p.end > r.$1) r];
    return Text.rich(
      buildParagraphSpan(
        p.words,
        styleForRole(p.role, style),
        bionic: bionic && p.role == BlockRole.body,
        highlightStart: h.sentenceStart,
        highlightEnd: h.sentenceEnd,
        highlightColor: h.sentenceColor,
        noteRanges: ranges,
        noteColor: noteColor,
      ),
      textAlign: TextAlign.start,
    );
  }

  /// Map a long-press location to the sentence under it and report its range.
  void _handleLongPress(PageParagraph p, Offset localPos) {
    final cb = onTextTap;
    if (cb == null || p.words.isEmpty) return;
    final painter = TextPainter(
      text: buildParagraphSpan(
        p.words,
        styleForRole(p.role, style),
        bionic: bionic && p.role == BlockRole.body,
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: columnWidth);
    final index = painter.getPositionForOffset(localPos).offset;
    painter.dispose();
    final range = _sentenceRangeAt(p, index);
    if (range != null) cb(range.$1, range.$2);
  }

  /// The character range of the sentence containing rendered-string [index]
  /// (words are joined by single spaces in the rendered text).
  (int, int)? _sentenceRangeAt(PageParagraph p, int index) {
    final words = p.words;
    if (words.isEmpty) return null;
    var cursor = 0;
    var wordIdx = words.length - 1;
    for (var i = 0; i < words.length; i++) {
      final wlen = words[i].text.length;
      if (index <= cursor + wlen) {
        wordIdx = i;
        break;
      }
      cursor += wlen + 1; // word + separator space
    }
    final target = words[wordIdx];
    for (final sentence in Sentences.split(words)) {
      if (sentence.isEmpty) continue;
      if (target.start >= sentence.first.start && target.end <= sentence.last.end) {
        return (sentence.first.start, sentence.last.end);
      }
    }
    return (target.start, target.end);
  }
}

/// Heading styles derived from the body [base] style.
TextStyle styleForRole(BlockRole role, TextStyle base) {
  final size = base.fontSize ?? 18.0;
  switch (role) {
    case BlockRole.h1:
      return base.copyWith(fontSize: size * 1.8, fontWeight: FontWeight.w700, height: 1.2);
    case BlockRole.h2:
      return base.copyWith(fontSize: size * 1.45, fontWeight: FontWeight.w700, height: 1.25);
    case BlockRole.h3:
      return base.copyWith(fontSize: size * 1.2, fontWeight: FontWeight.w600, height: 1.3);
    case BlockRole.body:
      return base;
  }
}
