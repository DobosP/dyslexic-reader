import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_ocr/mobile_ocr.dart' as mo;

/// On-device OCR for scanned/image PDFs. Two interchangeable engines sit behind
/// [OcrEngine] so the caller can prefer the more accurate PaddleOCR (PP-OCRv5)
/// and fall back to the always-available, bundled ML Kit recognizer.
abstract class OcrEngine {
  /// Ensure any models are ready (may download on first use). Returns false if
  /// the engine is unavailable, so the caller can fall back.
  Future<bool> prepare();

  /// Recognize an image file into paragraph-ish text blocks.
  Future<List<String>> recognizeBlocks(String imagePath);

  Future<void> dispose();
}

/// Google ML Kit, Latin script. Bundled and offline; the safe fallback.
class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<bool> prepare() async => true;

  @override
  Future<List<String>> recognizeBlocks(String imagePath) async {
    final result =
        await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final blocks = <String>[];
    for (final block in result.blocks) {
      final text = block.text.replaceAll('\n', ' ').trim();
      if (text.isNotEmpty) blocks.add(text);
    }
    return blocks;
  }

  @override
  Future<void> dispose() => _recognizer.close();
}

/// PaddleOCR PP-OCRv5 via the `mobile_ocr` plugin (ONNX). Models (~20 MB) are
/// downloaded once on first use and cached for fully-offline runs after that.
/// Detected line boxes are regrouped into paragraphs by their geometry.
class PaddleOcrEngine implements OcrEngine {
  final mo.MobileOcr _ocr = mo.MobileOcr();

  @override
  Future<bool> prepare() async {
    final status = await _ocr.prepareModels();
    return status.isReady;
  }

  @override
  Future<List<String>> recognizeBlocks(String imagePath) async {
    final result = await _ocr.detectText(imagePath: imagePath);
    return _groupParagraphs(result.blocks);
  }

  @override
  Future<void> dispose() async {}

  /// Merge detected line boxes (top-to-bottom, left-to-right) into paragraphs,
  /// starting a new paragraph on a vertical gap or a fresh left indent.
  static List<String> _groupParagraphs(List<mo.TextBlock> boxes) {
    final items = [
      for (final b in boxes)
        if (b.text.trim().isNotEmpty) b,
    ]..sort((a, b) {
        final c = a.boundingBox.top.compareTo(b.boundingBox.top);
        return c != 0 ? c : a.boundingBox.left.compareTo(b.boundingBox.left);
      });
    if (items.isEmpty) return const [];

    final heights = [for (final b in items) b.boundingBox.height]..sort();
    final medianH = heights[heights.length ~/ 2];

    final paragraphs = <String>[];
    final buffer = StringBuffer();
    mo.TextBlock? prev;
    for (final b in items) {
      if (prev != null) {
        final gap = b.boundingBox.top - prev.boundingBox.bottom;
        final indent = b.boundingBox.left - prev.boundingBox.left;
        if (gap > medianH * 0.8 || indent > medianH * 1.5) {
          final p = buffer.toString().trim();
          if (p.isNotEmpty) paragraphs.add(p);
          buffer.clear();
        } else {
          buffer.write(' ');
        }
      }
      buffer.write(b.text.trim());
      prev = b;
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) paragraphs.add(tail);
    return paragraphs;
  }
}
