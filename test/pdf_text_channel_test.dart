import 'package:dyslexic_reader/core/platform/pdf_text_channel.dart';
import 'package:dyslexic_reader/domain/models/reading_document.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'dyslexic_reader/pdf_text';
  const methodChannel = MethodChannel(channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('extractText parses blocks, page indexes, and PDF outline', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          expect(call.method, 'extractText');
          return {
            'pageCount': 3,
            'hasText': true,
            'blocks': [
              {'type': 'h1', 'text': 'Chapter One', 'page': 0},
              {'type': 'p', 'text': 'Body text', 'page': 1},
            ],
            'outline': [
              {'title': 'Chapter One', 'level': 1, 'page': 0},
              {'title': 'Deep Section', 'level': 5, 'page': 1},
              {'title': '  ', 'level': 1, 'page': 2},
            ],
          };
        });

    final result = await const PdfTextChannel().extractText('/tmp/book.pdf');

    expect(result.pageCount, 3);
    expect(result.hasText, true);
    expect(result.pdfBlocks, hasLength(2));
    expect(result.pdfBlocks.first.block.role, BlockRole.h1);
    expect(result.pdfBlocks.first.pageIndex, 0);
    expect(result.blocks.last.text, 'Body text');
    expect(result.outline, hasLength(2));
    expect(result.outline.first.title, 'Chapter One');
    expect(result.outline.last.level, 3);
    expect(result.outline.last.pageIndex, 1);
  });

  test('extractText keeps clean defaults when outline is absent', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          return {
            'pageCount': 1,
            'blocks': [
              {'type': 'p', 'text': 'Plain body'},
            ],
          };
        });

    final result = await const PdfTextChannel().extractText('/tmp/plain.pdf');

    expect(result.hasText, true);
    expect(result.pdfBlocks.single.pageIndex, -1);
    expect(result.outline, isEmpty);
  });
}
