import 'package:flutter/services.dart';

import '../../domain/models/reading_document.dart';

/// Result of extracting structured text from a PDF on the native side.
class PdfExtractionResult {
  const PdfExtractionResult({
    required this.blocks,
    required this.pageCount,
    required this.hasText,
  });

  /// Typed blocks (headings/paragraphs) reconstructed by the native extractor.
  final List<TextBlock> blocks;
  final int pageCount;

  /// False for image-only / scanned PDFs (no selectable text layer).
  final bool hasText;
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

  static const MethodChannel _channel = MethodChannel('dyslexic_reader/pdf_text');

  Future<PdfExtractionResult> extractText(String path, {String? password}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'extractText',
        {'path': path, 'password': password},
      );
      if (res == null) throw const PdfException('Extractor returned no data.');

      final raw = (res['blocks'] as List?) ?? const [];
      final blocks = <TextBlock>[];
      for (final item in raw) {
        final m = (item as Map).cast<String, dynamic>();
        final text = (m['text'] as String?) ?? '';
        if (text.trim().isEmpty) continue;
        blocks.add(TextBlock(role: _roleFromType(m['type'] as String?), text: text));
      }
      return PdfExtractionResult(
        blocks: blocks,
        pageCount: (res['pageCount'] as num?)?.toInt() ?? 0,
        hasText: res['hasText'] as bool? ?? blocks.isNotEmpty,
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
