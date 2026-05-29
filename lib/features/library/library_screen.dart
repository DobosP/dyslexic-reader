import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reflow/tokenizer.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import 'paste_text_screen.dart';
import 'sample_text.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _openSample(BuildContext context) {
    final doc = Tokenizer.parse(kSampleText, title: kSampleTitle);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(document: doc)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
            'Open text and re-render it with the spacing, font, and colours that suit you.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _ActionCard(
            icon: Icons.menu_book_outlined,
            title: 'Read the sample',
            subtitle: 'Try the reading controls right away',
            onTap: () => _openSample(context),
          ),
          _ActionCard(
            icon: Icons.content_paste_outlined,
            title: 'Paste your own text',
            subtitle: 'Paste any text and read it your way',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PasteTextScreen()),
            ),
          ),
          const _ActionCard(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Open a PDF',
            subtitle: 'Coming soon',
            enabled: false,
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
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
