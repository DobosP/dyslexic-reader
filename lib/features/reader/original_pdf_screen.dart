import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/platform/pdf_text_channel.dart';

/// Shows the original PDF pages (rendered natively via Android's PdfRenderer).
/// Used for scanned/image PDFs and as a layout-faithful fallback.
class OriginalPdfScreen extends StatefulWidget {
  const OriginalPdfScreen({
    super.key,
    required this.title,
    required this.pdfPath,
    required this.pageCount,
  });

  final String title;
  final String pdfPath;
  final int pageCount;

  @override
  State<OriginalPdfScreen> createState() => _OriginalPdfScreenState();
}

class _OriginalPdfScreenState extends State<OriginalPdfScreen> {
  final _pages = <int, Future<Uint8List?>>{};

  Future<Uint8List?> _page(int index) => _pages.putIfAbsent(index, () async {
        try {
          return await const PdfTextChannel().renderPage(widget.pdfPath, index);
        } catch (_) {
          return null;
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      backgroundColor: Colors.grey.shade800,
      body: widget.pageCount <= 0
          ? const Center(child: Text('No pages to display'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.pageCount,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: _PageView(future: _page(index), index: index),
              ),
            ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.future, required this.index});

  final Future<Uint8List?> future;
  final int index;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 1 / 1.414, // A4-ish placeholder
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Could not render page ${index + 1}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.fitWidth, gaplessPlayback: true);
      },
    );
  }
}
