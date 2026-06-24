import 'package:flutter/services.dart';

import '../../domain/models/reading_document.dart';

/// One structured text block from the native extractor, plus the source page
/// used to map PDF outline destinations into reader offsets.
class PdfTextBlock {
  const PdfTextBlock({required this.block, required this.pageIndex});

  final TextBlock block;

  /// Zero-based PDF page index. `-1` when the native side did not report it.
  final int pageIndex;
}

/// One native PDF outline/table-of-contents entry before offset mapping.
class PdfOutlineDestination {
  const PdfOutlineDestination({
    required this.title,
    required this.level,
    required this.pageIndex,
  });

  final String title;
  final int level;

  /// Zero-based target page index, or `-1` when the destination cannot be
  /// resolved to a page.
  final int pageIndex;
}

/// Result of extracting structured text from a PDF on the native side.
class PdfExtractionResult {
  const PdfExtractionResult({
    required this.pdfBlocks,
    required this.pageCount,
    required this.hasText,
    this.outline = const [],
  });

  /// Typed blocks (headings/paragraphs) reconstructed by the native extractor.
  final List<PdfTextBlock> pdfBlocks;
  final int pageCount;

  /// False for image-only / scanned PDFs (no selectable text layer).
  final bool hasText;

  /// Embedded PDF outline/bookmarks, if the document has any.
  final List<PdfOutlineDestination> outline;

  List<TextBlock> get blocks => [for (final b in pdfBlocks) b.block];
}

class PdfException implements Exception {
  const PdfException(this.message);
  final String message;
  @override
  String toString() => 'PdfException: $message';
}

/// Dart side of the native PDF bridge. Structured text extraction uses a
/// PdfBox-Android subclass (coordinate + font heuristics → typed blocks); page
/// rendering uses Android's built-in `PdfRenderer`. See MainActivity.kt /
/// StructuredTextStripper.kt and docs/ARCHITECTURE.md.
class PdfTextChannel {
  const PdfTextChannel();

  static const MethodChannel _channel = MethodChannel(
    'dyslexic_reader/pdf_text',
  );

  Future<PdfExtractionResult> extractText(
    String path, {
    String? password,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'extractText',
        {'path': path, 'password': password},
      );
      if (res == null) throw const PdfException('Extractor returned no data.');

      final raw = (res['blocks'] as List?) ?? const [];
      final blocks = <PdfTextBlock>[];
      for (final item in raw) {
        final m = (item as Map).cast<String, dynamic>();
        final text = (m['text'] as String?) ?? '';
        if (text.trim().isEmpty) continue;
        blocks.add(
          PdfTextBlock(
            block: TextBlock(
              role: _roleFromType(m['type'] as String?),
              text: text,
            ),
            pageIndex: (m['page'] as num?)?.toInt() ?? -1,
          ),
        );
      }
      final rawOutline = (res['outline'] as List?) ?? const [];
      final outline = <PdfOutlineDestination>[];
      for (final item in rawOutline) {
        final m = (item as Map).cast<String, dynamic>();
        final title = (m['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) continue;
        outline.add(
          PdfOutlineDestination(
            title: title,
            level: ((m['level'] as num?)?.toInt() ?? 1).clamp(1, 3),
            pageIndex: (m['page'] as num?)?.toInt() ?? -1,
          ),
        );
      }
      return PdfExtractionResult(
        pdfBlocks: blocks,
        pageCount: (res['pageCount'] as num?)?.toInt() ?? 0,
        hasText: res['hasText'] as bool? ?? blocks.isNotEmpty,
        outline: outline,
      );
    } on PlatformException catch (e) {
      throw PdfException(e.message ?? 'PDF extraction failed.');
    }
  }

  /// Render a single page to a PNG bitmap (for the original page view).
  Future<Uint8List?> renderPage(
    String path,
    int pageIndex, {
    int targetWidth = 1080,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('renderPage', {
        'path': path,
        'pageIndex': pageIndex,
        'targetWidth': targetWidth,
      });
    } on PlatformException catch (e) {
      throw PdfException(e.message ?? 'PDF render failed.');
    }
  }

  static BlockRole _roleFromType(String? type) {
    switch (type) {
      case 'h1':
        return BlockRole.h1;
      case 'h2':
        return BlockRole.h2;
      case 'h3':
        return BlockRole.h3;
      default:
        return BlockRole.body;
    }
  }
}
