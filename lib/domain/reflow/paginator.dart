import '../models/reading_document.dart';

/// Returns the rendered height of a paragraph fragment's [text] at the reader's
/// fixed column width and current text style.
typedef MeasureHeight = double Function(String text);

/// A run of words rendered together on one page (a whole paragraph, or the part
/// of one that fits before a page break).
class PageParagraph {
  const PageParagraph({required this.words, required this.start, required this.end});

  final List<Word> words;
  final int start;
  final int end;

  String get text => words.map((w) => w.text).join(' ');
}

/// One screen-fit page.
class ReaderPage {
  const ReaderPage({required this.paragraphs, required this.start, required this.end});

  final List<PageParagraph> paragraphs;

  /// Character offsets (into the full text) of the first/last content on the page.
  final int start;
  final int end;
}

/// Produces pages one at a time from a cursor, so the reader can show the first
/// page(s) immediately and compute the rest lazily / in the background instead
/// of paginating the whole document up front.
class LazyPaginator {
  LazyPaginator({
    required this.doc,
    required this.maxHeight,
    required this.paragraphSpacing,
    required this.measure,
  });

  final ReadingDocument doc;
  final double maxHeight;
  final double paragraphSpacing;
  final MeasureHeight measure;

  int _pi = 0; // paragraph index
  int _wi = 0; // word index within the current paragraph

  /// Whether any content remains to be paginated.
  bool get hasMore {
    var pi = _pi, wi = _wi;
    while (pi < doc.paragraphs.length) {
      if (wi < doc.paragraphs[pi].words.length) return true;
      pi++;
      wi = 0;
    }
    return false;
  }

  /// Computes and returns the next page, advancing the cursor. Null when done.
  ReaderPage? next() {
    final cur = <PageParagraph>[];
    var curHeight = 0.0;

    while (_pi < doc.paragraphs.length) {
      final words = doc.paragraphs[_pi].words;
      if (_wi >= words.length) {
        _pi++;
        _wi = 0;
        continue;
      }
      final spacing = cur.isEmpty ? 0.0 : paragraphSpacing;
      final avail = maxHeight - curHeight - spacing;
      final take = _fitWords(words, _wi, avail, measure);

      if (take == 0) {
        if (cur.isEmpty) {
          // One word won't fit even an empty page — force one to make progress.
          _append(cur, words, _wi, 1);
          _advance(words, 1);
          return _page(cur);
        }
        return _page(cur); // page full; resumes on the next call
      }

      _append(cur, words, _wi, take);
      curHeight += spacing + measure(_join(words, _wi, take));
      final spilled = (_wi + take) < words.length;
      _advance(words, take);
      if (spilled) return _page(cur); // paragraph spilled; page ends here
    }
    return cur.isEmpty ? null : _page(cur);
  }

  void _advance(List<Word> words, int count) {
    _wi += count;
    if (_wi >= words.length) {
      _pi++;
      _wi = 0;
    }
  }

  ReaderPage _page(List<PageParagraph> cur) =>
      ReaderPage(paragraphs: cur, start: cur.first.start, end: cur.last.end);
}

class Paginator {
  Paginator._();

  /// Eagerly paginates the whole document (used in tests and small docs).
  static List<ReaderPage> paginate({
    required ReadingDocument doc,
    required double maxHeight,
    required double paragraphSpacing,
    required MeasureHeight measure,
  }) {
    final lp = LazyPaginator(
      doc: doc,
      maxHeight: maxHeight,
      paragraphSpacing: paragraphSpacing,
      measure: measure,
    );
    final pages = <ReaderPage>[];
    var p = lp.next();
    while (p != null) {
      pages.add(p);
      p = lp.next();
    }
    if (pages.isEmpty) {
      pages.add(const ReaderPage(paragraphs: [], start: 0, end: 0));
    }
    return pages;
  }

  /// Index of the page that should be shown for a saved [offset]: the last page
  /// that starts at or before it.
  static int pageForOffset(List<ReaderPage> pages, int offset) {
    var result = 0;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].start <= offset) {
        result = i;
      } else {
        break;
      }
    }
    return result;
  }
}

void _append(List<PageParagraph> cur, List<Word> words, int from, int count) {
  final slice = words.sublist(from, from + count);
  cur.add(PageParagraph(words: slice, start: slice.first.start, end: slice.last.end));
}

String _join(List<Word> words, int from, int count) =>
    words.sublist(from, from + count).map((w) => w.text).join(' ');

/// How many words starting at [from] fit within [avail] height (binary search,
/// since height is monotonic in word count). 0 if not even one word fits.
int _fitWords(List<Word> words, int from, double avail, MeasureHeight measure) {
  final remaining = words.length - from;
  if (remaining <= 0 || avail <= 0) return 0;
  if (measure(words[from].text) > avail) return 0;

  var lo = 1, hi = remaining, best = 1;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    if (measure(_join(words, from, mid)) <= avail) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best;
}
