import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/paginator.dart';
import 'paragraph_span.dart';

/// Lets the screen observe and drive the paginated reader (page N/M, jumps).
class PageReaderController extends ChangeNotifier {
  int pageIndex = 0;
  int pageCount = 1;
  int currentOffset = 0;

  /// False while pages are still being computed in the background.
  bool complete = false;

  void Function(int offset)? _jumpToOffset;
  void Function(int page)? _goToPage;

  void jumpToOffset(int offset) => _jumpToOffset?.call(offset);
  void goToPage(int page) => _goToPage?.call(page);
  void next() => _goToPage?.call(pageIndex + 1);
  void prev() => _goToPage?.call(pageIndex - 1);

  void _bind({
    required void Function(int) jumpToOffset,
    required void Function(int) goToPage,
  }) {
    _jumpToOffset = jumpToOffset;
    _goToPage = goToPage;
  }

  void _update({int? pageIndex, int? pageCount, int? currentOffset, bool? complete}) {
    if (pageIndex != null) this.pageIndex = pageIndex;
    if (pageCount != null) this.pageCount = pageCount;
    if (currentOffset != null) this.currentOffset = currentOffset;
    if (complete != null) this.complete = complete;
    notifyListeners();
  }
}

/// Splits a [ReadingDocument] into screen-fit pages **incrementally**: the first
/// page(s) are computed immediately, the rest fill in the background and
/// just-in-time as the reader swipes. Re-paginates when the style or available
/// size changes, preserving the reading position (a character offset).
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
  });

  final ReadingDocument document;
  final TextStyle style;
  final double maxColumnWidth;
  final double paragraphSpacing;
  final bool bionic;
  final int initialOffset;
  final ValueChanged<int>? onOffsetChanged;
  final PageReaderController? controller;

  @override
  State<PaginatedReader> createState() => _PaginatedReaderState();
}

class _PaginatedReaderState extends State<PaginatedReader> {
  static const double _hPad = 20;
  static const double _vPad = 20;
  static const int _lookahead = 2; // keep this many pages ready ahead of the user

  final PageController _pageController = PageController();
  LazyPaginator? _paginator;
  List<ReaderPage> _pages = [];
  bool _complete = false;
  int _generation = 0;
  String _signature = '';
  int _targetOffset = 0;

  @override
  void initState() {
    super.initState();
    _targetOffset = widget.initialOffset;
    widget.controller?._bind(jumpToOffset: _jumpToOffset, goToPage: _animateToPage);
  }

  @override
  void dispose() {
    _generation++; // stop any in-flight background fill
    _pageController.dispose();
    super.dispose();
  }

  int _currentPage() => _pageController.hasClients && _pageController.page != null
      ? _pageController.page!.round()
      : 0;

  void _jumpToOffset(int offset) {
    _targetOffset = offset;
    _ensureComputedForOffset(offset);
    _animateToPage(Paginator.pageForOffset(_pages, offset));
  }

  void _animateToPage(int page) {
    _ensureComputedForPage(page);
    if (!_pageController.hasClients || _pages.isEmpty) return;
    _pageController.animateToPage(
      page.clamp(0, _pages.length - 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  double _measure(String text, double maxWidth, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth <= 0 ? 1 : maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// Compute pages until the page containing [offset] (plus a small buffer) exists.
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
        _notify(_currentPage());
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
            measure: (text) => _measure(text, colWidth, scaler),
          );
          _pages = [];
          _complete = false;
          _ensureComputedForOffset(_targetOffset); // first page(s) only — fast
          final targetPage = Paginator.pageForOffset(_pages, _targetOffset);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || gen != _generation) return;
            if (_pageController.hasClients) _pageController.jumpToPage(targetPage);
            _notify(targetPage);
            _startBackgroundFill(gen);
          });
        }

        return PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (i) {
            _targetOffset = _pages[i].start;
            if (!_complete) {
              _ensureComputedForPage(i);
              setState(() {});
            }
            _notify(i);
            widget.onOffsetChanged?.call(_pages[i].start);
          },
          itemBuilder: (context, i) => _PageBody(
            page: _pages[i],
            style: widget.style,
            columnWidth: colWidth,
            paragraphSpacing: widget.paragraphSpacing,
            bionic: widget.bionic,
            horizontalPadding: _hPad,
            verticalPadding: _vPad,
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
  });

  final ReaderPage page;
  final TextStyle style;
  final double columnWidth;
  final double paragraphSpacing;
  final bool bionic;
  final double horizontalPadding;
  final double verticalPadding;

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
            children: [
              for (var i = 0; i < page.paragraphs.length; i++) ...[
                if (i > 0) SizedBox(height: paragraphSpacing),
                Text.rich(
                  buildParagraphSpan(page.paragraphs[i].words, style, bionic: bionic),
                  textAlign: TextAlign.start,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
