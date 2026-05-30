import '../models/reading_document.dart';
import '../reflow/sentences.dart';

/// One entry in the chapter outline, built from a heading paragraph.
class OutlineItem {
  const OutlineItem({required this.title, required this.level, required this.offset});

  final String title;

  /// 1 = h1, 2 = h2, 3 = h3 (for indentation).
  final int level;

  /// Character offset of the heading — used to jump there.
  final int offset;
}

/// Readability/pacing stats for a document.
class ReadingStats {
  const ReadingStats({
    required this.words,
    required this.sentences,
    required this.avgWordsPerSentence,
    required this.readingMinutes,
  });

  final int words;
  final int sentences;
  final double avgWordsPerSentence;
  final int readingMinutes;
}

class DocumentStructure {
  DocumentStructure._();

  static int _levelOf(BlockRole role) => switch (role) {
        BlockRole.h1 => 1,
        BlockRole.h2 => 2,
        BlockRole.h3 => 3,
        BlockRole.body => 0,
      };

  /// Build the chapter outline from heading paragraphs.
  static List<OutlineItem> outline(ReadingDocument doc) {
    final items = <OutlineItem>[];
    for (final p in doc.paragraphs) {
      final level = _levelOf(p.role);
      if (level == 0) continue;
      items.add(OutlineItem(
        title: p.words.map((w) => w.text).join(' '),
        level: level,
        offset: p.start,
      ));
    }
    return items;
  }

  /// Compute word/sentence/pace stats (avg words per sentence over body text).
  static ReadingStats stats(ReadingDocument doc) {
    var totalWords = 0;
    var bodyWords = 0;
    var sentences = 0;
    for (final p in doc.paragraphs) {
      totalWords += p.words.length;
      if (p.role == BlockRole.body) {
        bodyWords += p.words.length;
        sentences += Sentences.split(p.words).length;
      }
    }
    final avg = sentences > 0 ? bodyWords / sentences : 0.0;
    final minutes = totalWords == 0 ? 0 : (totalWords / 200).ceil();
    return ReadingStats(
      words: totalWords,
      sentences: sentences,
      avgWordsPerSentence: avg,
      readingMinutes: minutes,
    );
  }
}
