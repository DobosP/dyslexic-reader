import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/library_entry.dart';
import '../../domain/models/reading_document.dart';
import '../../domain/reflow/tokenizer.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import 'library_controller.dart';
import 'paste_text_screen.dart';
import 'sample_text.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dyslexic Reader'),
        actions: [
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Read more comfortably', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Open a PDF or text file and re-render it with the spacing, font, and colours that suit you.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _ActionCard(
            icon: Icons.file_open_outlined,
            title: 'Open a PDF or text file',
            subtitle: 'Import a .pdf or .txt from your device',
            onTap: () => _import(context, ref),
          ),
          _ActionCard(
            icon: Icons.content_paste_outlined,
            title: 'Paste your own text',
            subtitle: 'Paste any text and read it your way',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PasteTextScreen()),
            ),
          ),
          _ActionCard(
            icon: Icons.menu_book_outlined,
            title: 'Read the sample',
            subtitle: 'Try the reading controls right away',
            onTap: () => _openSample(context),
          ),
          library.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (entries) {
              if (entries.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('Your documents', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final e in entries) _DocTile(entry: e),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openSample(BuildContext context) {
    final doc = Tokenizer.parse(kSampleText, title: kSampleTitle);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(document: doc)),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(libraryControllerProvider.notifier);

    XFile? file;
    try {
      file = await controller.pickFile();
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not open the file picker.');
      return;
    }
    if (file == null) return; // cancelled
    if (!context.mounted) return;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));

    ReadingDocument? doc;
    Object? failure;
    try {
      final entry = await controller.importPicked(file);
      doc = await controller.open(entry);
    } on ScannedPdfException {
      failure = const ScannedPdfException();
    } catch (e) {
      failure = e;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss progress

    if (failure is ScannedPdfException) {
      _showScannedDialog(context);
      return;
    }
    if (failure != null) {
      _snack(context, 'Import failed: $failure');
      return;
    }
    if (doc != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReaderScreen(document: doc!)),
      );
    }
  }

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _showScannedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No text found'),
        content: const Text(
          'This looks like a scanned PDF with no selectable text. Reading scanned '
          'PDFs needs OCR, which is coming in a later phase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DocTile extends ConsumerWidget {
  const _DocTile({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (entry.source) {
      DocSource.pdf => Icons.picture_as_pdf_outlined,
      DocSource.txt => Icons.description_outlined,
      _ => Icons.article_outlined,
    };
    final subtitle = entry.source == DocSource.pdf
        ? '${entry.source.label} · ${entry.pageCount} pages · ${entry.wordCount} words'
        : '${entry.source.label} · ${entry.wordCount} words';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(libraryControllerProvider.notifier).delete(entry),
        ),
        onTap: () => _open(context, ref),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final doc = await ref.read(libraryControllerProvider.notifier).open(entry);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(document: doc)),
    );
  }
}
