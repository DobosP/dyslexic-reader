import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/paginator.dart';
import 'paragraph_span.dart';

/// Lets the screen observe and drive the reader (page N/M, jumps).
class PageReaderController extends ChangeNotifier {
  int pageIndex = 0;
  int pageCount = 1;
  int currentOffset = 0;

  /// False while pages are still being computed in the background.
  bool complete = false;

  void Function(int offset)? _jumpToOffset;
  void Function(int page)? _goToPage;
  void Function(int offset)? _ensureVisibleFn;

  void jumpToOffset(int offset) => _jumpToOffset?.call(offset);
  void goToPage(int page) => _goToPage?.call(page);
  void next() => _goToPage?.call(pageIndex + 1);
  void prev() => _goToPage?.call(pageIndex - 1);

  /// Scroll the offset into view only if it isn't already (for the read-along pacer).
  void ensureVisible(int offset) => _ensureVisibleFn?.call(offset);

  void _bind({
    required void Function(int) jumpToOffset,
    required void Function(int) goToPage,
    required void Function(int) ensureVisible,
  }) {
    _jumpToOffset = jumpToOffset;
    _goToPage = goToPage;
    _ensureVisibleFn = ensureVisible;
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

/// A vertically-scrolling, virtualized reader (lazy pagination + windowed
/// render). Optionally highlights the current read-along sentence/paragraph.
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
    this.highlightSentenceStart = -1,
    this.highlightSentenceEnd = -1,
    this.highlightParagraphStart = -1,
    this.highlightParagraphEnd = -1,
    this.sentenceColor,
    this.paragraphColor,
  });

  final ReadingDocument document;
  final TextStyle style;
  final double maxColumnWidth;
  final double paragraphSpacing;
  final bool bionic;
  final int initialOffset;
  final ValueChanged<int>? onOffsetChanged;
  final PageReaderController? controller;

  final int highlightSentenceStart;
  final int highlightSentenceEnd;
  final int highlightParagraphStart;
  final int highlightParagraphEnd;
  final Color? sentenceColor;
  final Color? paragraphColor;

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
  bool _complete = false;
  int _generation = 0;
  String _signature = '';
  int _targetOffset = 0;
  int _initialIndex = 0;
  int _topIndex = 0;

  @override
  void initState() {
    super.initState();
    _targetOffset = widget.initialOffset;
    widget.controller?._bind(
      jumpToOffset: _jumpToOffset,
      goToPage: _animateToPage,
      ensureVisible: _ensureVisible,
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
  }

  void _jumpToOffset(int offset) {
    _targetOffset = offset;
    _ensureComputedForOffset(offset);
    _animateToPage(Paginator.pageForOffset(_pages, offset));
  }

  /// Scroll [offset] into view only if its page isn't already visible.
  void _ensureVisible(int offset) {
    _ensureComputedForOffset(offset);
    final page = Paginator.pageForOffset(_pages, offset);
    final onScreen = _itemPositions.itemPositions.value.any(
      (p) => p.index == page && p.itemTrailingEdge > 0.08 && p.itemLeadingEdge < 0.92,
    );
    if (onScreen) return;
    _animateToPage(page);
  }

  void _animateToPage(int page) {
    _ensureComputedForPage(page);
    final target = page.clamp(0, _pages.length - 1);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScroll.isAttached) return;
      _itemScroll.scrollTo(
        index: target,
        alignment: 0.15,
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

        final signature = [
          identityHashCode(widget.document),
          widget.style.fontSize,
          widget.style.height,
          widget.style.letterSpacing,
          widget.style.wordSpacing,
          widget.style.fontFamily,
          widget.bionic,
          colWidth.floor(),
          pageHeight.floor(),
          widget.paragraphSpacing.floor(),
        ].join('|');

        if (signature != _signature) {
          _signature = signature;
          _generation++;
          final gen = _generation;
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
          _initialIndex = Paginator.pageForOffset(_pages, _targetOffset);
          _topIndex = _initialIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || gen != _generation) return;
            if (_itemScroll.isAttached) _itemScroll.jumpTo(index: _initialIndex);
            _notify(_initialIndex);
            _startBackgroundFill(gen);
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
            verticalPadding: _vPad,
            highlightSentenceStart: widget.highlightSentenceStart,
            highlightSentenceEnd: widget.highlightSentenceEnd,
            highlightParagraphStart: widget.highlightParagraphStart,
            highlightParagraphEnd: widget.highlightParagraphEnd,
            sentenceColor: widget.sentenceColor,
            paragraphColor: widget.paragraphColor,
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
    required this.highlightSentenceStart,
    required this.highlightSentenceEnd,
    required this.highlightParagraphStart,
    required this.highlightParagraphEnd,
    required this.sentenceColor,
    required this.paragraphColor,
  });

  final ReaderPage page;
  final TextStyle style;
  final double columnWidth;
  final double paragraphSpacing;
  final bool bionic;
  final double horizontalPadding;
  final double verticalPadding;
  final int highlightSentenceStart;
  final int highlightSentenceEnd;
  final int highlightParagraphStart;
  final int highlightParagraphEnd;
  final Color? sentenceColor;
  final Color? paragraphColor;

  bool _paraHighlighted(PageParagraph p) =>
      paragraphColor != null &&
      highlightParagraphEnd > highlightParagraphStart &&
      p.start < highlightParagraphEnd &&
      p.end > highlightParagraphStart;

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
                _paragraph(page.paragraphs[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _paragraph(PageParagraph p) {
    final text = Text.rich(
      buildParagraphSpan(
        p.words,
        styleForRole(p.role, style),
        bionic: bionic && p.role == BlockRole.body,
        highlightStart: highlightSentenceStart,
        highlightEnd: highlightSentenceEnd,
        highlightColor: sentenceColor,
      ),
      textAlign: TextAlign.start,
    );
    if (!_paraHighlighted(p)) return text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: paragraphColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: text,
    );
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
