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

class Paginator {
  Paginator._();

  /// Splits [doc] into pages that each fit within [maxHeight]. [measure] returns
  /// the height of a fragment's text at the fixed column width/style;
  /// [paragraphSpacing] is the gap added before a paragraph that is not first
  /// on its page.
  static List<ReaderPage> paginate({
    required ReadingDocument doc,
    required double maxHeight,
    required double paragraphSpacing,
    required MeasureHeight measure,
  }) {
    final pages = <ReaderPage>[];
    var cur = <PageParagraph>[];
    var curHeight = 0.0;

    void flush() {
      if (cur.isEmpty) return;
      pages.add(ReaderPage(paragraphs: cur, start: cur.first.start, end: cur.last.end));
      cur = <PageParagraph>[];
      curHeight = 0.0;
    }

    for (final p in doc.paragraphs) {
      final words = p.words;
      var i = 0;
      while (i < words.length) {
        final spacing = cur.isEmpty ? 0.0 : paragraphSpacing;
        final avail = maxHeight - curHeight - spacing;
        final take = _fitWords(words, i, avail, measure);

        if (take == 0) {
          if (cur.isEmpty) {
            // One word won't fit even an empty page (huge font / tiny screen) —
            // force one word so we always make progress.
            _append(cur, words, i, 1);
            i += 1;
            flush();
          } else {
            flush();
          }
          continue;
        }

        _append(cur, words, i, take);
        curHeight += spacing + measure(_join(words, i, take));
        i += take;
        if (i < words.length) flush(); // paragraph spilled onto the next page
      }
    }
    flush();

    if (pages.isEmpty) {
      pages.add(const ReaderPage(paragraphs: [], start: 0, end: 0));
    }
    return pages;
  }

  /// Index of the page that should be shown for a saved [offset]: the last page
  /// that starts at or before it (so a position in inter-page whitespace maps to
  /// the page just begun).
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

  static void _append(List<PageParagraph> cur, List<Word> words, int from, int count) {
    final slice = words.sublist(from, from + count);
    cur.add(PageParagraph(words: slice, start: slice.first.start, end: slice.last.end));
  }

  static String _join(List<Word> words, int from, int count) =>
      words.sublist(from, from + count).map((w) => w.text).join(' ');

  /// How many words starting at [from] fit within [avail] height (binary search,
  /// since height is monotonic in word count). 0 if not even one word fits.
  static int _fitWords(List<Word> words, int from, double avail, MeasureHeight measure) {
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
}
