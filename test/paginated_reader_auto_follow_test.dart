import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/features/reader/widgets/paginated_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String paragraph(int i) =>
      'Paragraph $i keeps enough unique readable words in this line so the '
      'continuous reader has real height to scroll through during tests.';

  final text = List.generate(45, paragraph).join('\n\n');
  final doc = Tokenizer.parse(text, title: 'Auto follow');
  final paragraph32Offset = text.indexOf('Paragraph 32');

  Widget host(PageReaderController controller) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 420,
          child: PaginatedReader(
            document: doc,
            style: const TextStyle(fontSize: 20, height: 1.5),
            maxColumnWidth: 300,
            paragraphSpacing: 24,
            bionic: false,
            initialOffset: 0,
            controller: controller,
            continuous: true,
          ),
        ),
      ),
    );
  }

  testWidgets('controller auto-follow scrolls a spoken offset into view', (
    tester,
  ) async {
    final controller = PageReaderController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paragraph 0'), findsOneWidget);
    expect(find.textContaining('Paragraph 32'), findsNothing);

    controller.ensureVisible(paragraph32Offset, alignment: 0.62);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(controller.currentOffset, greaterThan(0));
    expect(controller.currentOffset, lessThanOrEqualTo(paragraph32Offset));
  });
}
