import 'package:flutter/material.dart';

import '../../domain/reflow/tokenizer.dart';
import '../reader/reader_screen.dart';

class PasteTextScreen extends StatefulWidget {
  const PasteTextScreen({super.key});

  @override
  State<PasteTextScreen> createState() => _PasteTextScreenState();
}

class _PasteTextScreenState extends State<PasteTextScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final doc = Tokenizer.parse(text, title: 'Pasted text');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(document: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paste text')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste or type the text you want to read…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Open in reader'),
            ),
          ],
        ),
      ),
    );
  }
}
