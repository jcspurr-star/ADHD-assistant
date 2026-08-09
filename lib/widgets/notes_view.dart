import 'package:flutter/material.dart';

import '../models/note_entry.dart';

class NotesView extends StatelessWidget {
  const NotesView({
    super.key,
    required this.contentWidth,
    required this.noteEntries,
    required this.selectedNoteId,
    required this.inboxEntries,
    required this.displayNoteTitle,
    required this.notePreview,
    required this.onAddNote,
    required this.onDeleteSelectedNote,
    required this.onSelectNote,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onEditInboxEntry,
    required this.onConvertInboxEntryToTask,
    required this.onRemoveInboxEntry,
  });

  final double contentWidth;
  final List<NoteEntry> noteEntries;
  final String? selectedNoteId;
  final List<String> inboxEntries;
  final String Function(NoteEntry entry) displayNoteTitle;
  final String Function(NoteEntry entry) notePreview;
  final VoidCallback onAddNote;
  final VoidCallback onDeleteSelectedNote;
  final Future<void> Function(String noteId) onSelectNote;
  final Future<void> Function(NoteEntry entry) onEditNote;
  final Future<void> Function(String noteId) onDeleteNote;
  final Future<void> Function(int index) onEditInboxEntry;
  final Future<void> Function(int index) onConvertInboxEntryToTask;
  final Future<void> Function(int index) onRemoveInboxEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: contentWidth,
            child: Row(
              children: [
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add note',
                  visualDensity: VisualDensity.compact,
                  onPressed: onAddNote,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete note',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDeleteSelectedNote,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: contentWidth,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Capture',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (inboxEntries.isEmpty)
                    Text(
                      'No captured items yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  if (inboxEntries.isNotEmpty)
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        itemCount: inboxEntries.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              inboxEntries[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: 'Edit',
                                  onPressed: () async {
                                    await onEditInboxEntry(index);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.playlist_add,
                                    size: 18,
                                  ),
                                  tooltip: 'Convert to task',
                                  onPressed: () async {
                                    await onConvertInboxEntryToTask(index);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    await onRemoveInboxEntry(index);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: contentWidth,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: buildNotesList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildNotesList() {
    if (noteEntries.isEmpty) {
      return Center(
        child: Text(
          'No notes yet. Tap + to create one.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      itemCount: noteEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = noteEntries[index];
        final isSelected = entry.id == selectedNoteId;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await onSelectNote(entry.id);
            await onEditNote(entry);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayNoteTitle(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit note',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await onSelectNote(entry.id);
                        await onEditNote(entry);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Delete note',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await onDeleteNote(entry.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notePreview(entry),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
