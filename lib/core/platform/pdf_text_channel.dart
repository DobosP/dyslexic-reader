import 'package:flutter/services.dart';

/// Result of extracting text from a PDF on the native side.
class PdfExtractionResult {
  const PdfExtractionResult({
    required this.fullText,
    required this.pageCount,
    required this.hasText,
  });

  final String fullText;
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

/// Dart side of the native PDF text-extraction bridge (PdfBox-Android).
/// See `android/app/src/main/kotlin/.../MainActivity.kt` and
/// docs/ARCHITECTURE.md §5.1.
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
      return PdfExtractionResult(
        fullText: res['fullText'] as String? ?? '',
        pageCount: (res['pageCount'] as num?)?.toInt() ?? 0,
        hasText: res['hasText'] as bool? ?? false,
      );
    } on PlatformException catch (e) {
      throw PdfException(e.message ?? 'PDF extraction failed.');
    }
  }
}
