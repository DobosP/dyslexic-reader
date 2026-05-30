import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR (Google ML Kit, Latin script) for scanned/image PDFs.
class OcrService {
  OcrService() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Recognize text in an image file, returning each detected block's text
  /// (a block is a contiguous region — roughly a paragraph).
  Future<List<String>> recognizeBlocks(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final blocks = <String>[];
    for (final block in result.blocks) {
      final text = block.text.replaceAll('\n', ' ').trim();
      if (text.isNotEmpty) blocks.add(text);
    }
    return blocks;
  }

  Future<void> dispose() => _recognizer.close();
}
