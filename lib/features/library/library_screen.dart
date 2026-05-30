import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/incoming_file_channel.dart';
import '../../domain/models/library_entry.dart';
import '../../domain/reflow/tokenizer.dart';
import '../reader/original_pdf_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import 'library_controller.dart';
import 'paste_text_screen.dart';
import 'sample_text.dart';

/// Opens a library entry: reflow view when it has a text layer, otherwise the
/// original page view (scanned PDFs).
Future<void> openLibraryEntry(
  BuildContext context,
  WidgetRef ref,
  LibraryEntry entry,
) async {
  if (entry.hasTextLayer) {
    final doc = await ref.read(libraryControllerProvider.notifier).open(entry);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(document: doc, entry: entry),
      ),
    );
  } else if (entry.pdfPath != null) {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OriginalPdfScreen(
          title: entry.title,
          pdfPath: entry.pdfPath!,
          pageCount: entry.pageCount,
        ),
      ),
    );
  }
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  bool _checkingIncoming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_checkIncoming()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkIncoming());
  }

  /// Handle a file the app was opened with (open-with / share intent).
  Future<void> _checkIncoming() async {
    if (_checkingIncoming) return;
    _checkingIncoming = true;
    try {
      final incoming = await const IncomingFileChannel().consume();
      if (incoming == null || !mounted) return;
      if (incoming.isError) {
        _snack("Couldn't open that file: ${incoming.error}");
        return;
      }
      if (!incoming.hasFile) return;
      await _runImport(
        () => ref
            .read(libraryControllerProvider.notifier)
            .importFromPath(incoming.path!, incoming.name!),
      );
    } finally {
      _checkingIncoming = false;
    }
  }

  Future<void> _pickAndImport() async {
    final controller = ref.read(libraryControllerProvider.notifier);
    XFile? file;
    try {
      file = await controller.pickFile();
    } catch (_) {
      if (mounted) _snack('Could not open the file picker.');
      return;
    }
    if (file == null) return; // cancelled
    final picked = file;
    await _runImport(() => controller.importPicked(picked));
  }

  /// Run [doImport] with a progress spinner, then open the result.
  Future<void> _runImport(Future<LibraryEntry> Function() doImport) async {
    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));

    LibraryEntry? entry;
    Object? failure;
    try {
      entry = await doImport();
    } catch (e) {
      failure = e;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss progress

    if (failure != null) {
      _snack('Import failed: $failure');
      return;
    }
    if (entry != null) {
      if (!entry.hasTextLayer) {
        _snack(
            'No text layer found — showing the original pages. OCR is coming later.');
      }
      await openLibraryEntry(context, ref, entry);
    }
  }

  void _openSample() {
    final doc = Tokenizer.parse(kSampleText, title: kSampleTitle);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(document: doc)),
    );
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
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
            onTap: _pickAndImport,
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
            onTap: _openSample,
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
    final detail = entry.source == DocSource.pdf
        ? (entry.hasTextLayer
            ? '${entry.source.label} · ${entry.pageCount} pages · ${entry.wordCount} words'
            : '${entry.source.label} · ${entry.pageCount} pages · scanned (original view)')
        : '${entry.source.label} · ${entry.wordCount} words';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detail),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(libraryControllerProvider.notifier).delete(entry),
        ),
        onTap: () => openLibraryEntry(context, ref, entry),
      ),
    );
  }
}
