import 'package:flutter/material.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/paginator.dart';
import 'paragraph_span.dart';

/// Lets the screen observe and drive the paginated reader (page N/M, jumps).
class PageReaderController extends ChangeNotifier {
  int pageIndex = 0;
  int pageCount = 1;
  int currentOffset = 0;

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

  void _update({int? pageIndex, int? pageCount, int? currentOffset}) {
    if (pageIndex != null) this.pageIndex = pageIndex;
    if (pageCount != null) this.pageCount = pageCount;
    if (currentOffset != null) this.currentOffset = currentOffset;
    notifyListeners();
  }
}

/// Splits a [ReadingDocument] into screen-fit pages and shows them in a swipeable
/// [PageView]. Re-paginates when the style or available size changes, preserving
/// the reading position (a character offset).
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

  final PageController _pageController = PageController();
  List<ReaderPage> _pages = const [];
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
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToOffset(int offset) {
    _targetOffset = offset;
    _animateToPage(Paginator.pageForOffset(_pages, offset));
  }

  void _animateToPage(int page) {
    if (!_pageController.hasClients || _pages.isEmpty) return;
    final clamped = page.clamp(0, _pages.length - 1);
    _pageController.animateToPage(
      clamped,
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
          _pages = Paginator.paginate(
            doc: widget.document,
            maxHeight: pageHeight,
            paragraphSpacing: widget.paragraphSpacing,
            measure: (text) => _measure(text, colWidth, scaler),
          );
          final targetPage = Paginator.pageForOffset(_pages, _targetOffset);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_pageController.hasClients) _pageController.jumpToPage(targetPage);
            _notify(targetPage);
          });
        }

        return PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (i) {
            _targetOffset = _pages[i].start;
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
