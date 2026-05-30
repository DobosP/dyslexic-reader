import 'package:flutter/material.dart';

import '../../../domain/structure/document_structure.dart';

/// A toggleable "Contents" panel: readability stats + the chapter outline
/// (tap a heading to jump there).
class OutlineDrawer extends StatelessWidget {
  const OutlineDrawer({
    super.key,
    required this.outline,
    required this.stats,
    required this.onJump,
  });

  final List<OutlineItem> outline;
  final ReadingStats stats;
  final void Function(int offset) onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contents', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(_statsLine(stats), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: outline.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No chapters detected in this document.'),
                    )
                  : ListView.builder(
                      itemCount: outline.length,
                      itemBuilder: (context, i) {
                        final item = outline[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: 16.0 + (item.level - 1) * 16.0,
                            right: 16,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: item.level == 1
                                ? theme.textTheme.titleSmall
                                : theme.textTheme.bodyMedium,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            onJump(item.offset);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _statsLine(ReadingStats s) {
    final avg = s.avgWordsPerSentence > 0 ? s.avgWordsPerSentence.toStringAsFixed(1) : '–';
    return '${s.words} words · ${s.sentences} sentences · '
        '$avg words/sentence · ~${s.readingMinutes} min';
  }
}
