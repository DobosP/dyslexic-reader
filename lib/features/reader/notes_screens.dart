import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/library_entry.dart';
import '../library/library_controller.dart';

/// Full-screen editor for a note anchored to a sentence range. Pushed as a
/// route so it's always reachable (no bottom-sheet / dialog placement issues).
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.entryId,
    required this.start,
    required this.end,
    required this.snippet,
    this.initialText = '',
    this.isEditing = false,
  });

  final String entryId;
  final int start;
  final int end;
  final String snippet;
  final String initialText;
  final bool isEditing;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    final notifier = ref.read(libraryControllerProvider.notifier);
    if (text.isEmpty) {
      if (widget.isEditing) _remove(notifier);
    } else {
      notifier.upsertNote(
        widget.entryId,
        Note(start: widget.start, end: widget.end, text: text, createdAt: DateTime.now()),
      );
    }
    Navigator.of(context).pop();
  }

  void _remove(LibraryController notifier) {
    notifier.removeNote(
      widget.entryId,
      Note(start: widget.start, end: widget.end, text: '', createdAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _remove(ref.read(libraryControllerProvider.notifier));
                Navigator.of(context).pop();
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.snippet,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write a note for this sentence…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen list of a document's notes. Tapping a note pops with its
/// character offset so the reader can jump to it.
class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({
    super.key,
    required this.entryId,
    required this.snippetFor,
  });

  final String entryId;
  final String Function(int offset) snippetFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(libraryControllerProvider).valueOrNull ?? const [];
    LibraryEntry? entry;
    for (final e in list) {
      if (e.id == entryId) entry = e;
    }
    final notes = entry?.notes ?? const <Note>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: notes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No notes yet. Long-press a sentence in the reader to add one.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final n in notes)
                  ListTile(
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: Text(n.text),
                    subtitle: Text(
                      '"${snippetFor(n.start)}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(libraryControllerProvider.notifier)
                          .removeNote(entryId, n),
                    ),
                    onTap: () => Navigator.of(context).pop(n.start),
                  ),
              ],
            ),
    );
  }
}
