import 'dart:convert';

/// Semantic role of a block of text, used to style headings vs body.
enum BlockRole { h1, h2, h3, body }

BlockRole blockRoleByName(Object? name) => BlockRole.values.firstWhere(
      (r) => r.name == name,
      orElse: () => BlockRole.body,
    );

/// A typed block of text produced by extraction (PDF structured extractor or a
/// plain-text splitter). This is what gets cached per document.
class TextBlock {
  const TextBlock({required this.role, required this.text});

  final BlockRole role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role.name, 'text': text};

  factory TextBlock.fromJson(Map<String, dynamic> j) => TextBlock(
        role: blockRoleByName(j['role']),
        text: j['text'] as String? ?? '',
      );

  static String encodeList(List<TextBlock> blocks) =>
      jsonEncode(blocks.map((b) => b.toJson()).toList());

  static List<TextBlock> decodeList(String s) => (jsonDecode(s) as List)
      .cast<Map<String, dynamic>>()
      .map(TextBlock.fromJson)
      .toList();
}

/// A document prepared for the reading surface: a title plus the original
/// [text] split into [paragraphs] of [Word] tokens (each paragraph carries a
/// [BlockRole] so headings can be styled).
class ReadingDocument {
  const ReadingDocument({
    required this.title,
    required this.text,
    required this.paragraphs,
  });

  final String title;
  final String text;
  final List<Paragraph> paragraphs;

  int get wordCount => paragraphs.fold(0, (sum, p) => sum + p.words.length);
}

class Paragraph {
  const Paragraph({
    required this.words,
    required this.start,
    required this.end,
    this.role = BlockRole.body,
  });

  final List<Word> words;
  final BlockRole role;

  /// Character offsets into [ReadingDocument.text] (inclusive start, exclusive end).
  final int start;
  final int end;
}

class Word {
  const Word({required this.text, required this.start, required this.end});

  final String text;

  /// Character offsets into [ReadingDocument.text].
  final int start;
  final int end;
}
