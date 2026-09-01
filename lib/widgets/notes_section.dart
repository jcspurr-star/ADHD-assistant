import 'package:flutter/material.dart';

import '../models/note_entry.dart';
import 'notes_view.dart';

class NotesSection extends StatelessWidget {
  const NotesSection({
    super.key,
    required this.wideContentWidth,
    required this.noteEntries,
    required this.selectedNoteId,
    required this.inboxEntries,
    required this.displayNoteTitle,
    required this.notePreview,
    required this.noteTitleController,
    required this.noteContentController,
    required this.noteIngredientsController,
    required this.noteInstructionsController,
    required this.onCreateNoteWithTitle,
    required this.onCreateRecipeWithTitle,
    required this.onSelectNote,
    required this.onEditNote,
    required this.onConvertNoteToTask,
    required this.onDeleteNote,
    required this.onEditInboxEntry,
    required this.onConvertInboxEntryToNote,
    required this.onConvertInboxEntryToTask,
    required this.onRemoveInboxEntry,
  });

  final double wideContentWidth;
  final List<NoteEntry> noteEntries;
  final String? selectedNoteId;
  final List<String> inboxEntries;
  final String Function(NoteEntry entry) displayNoteTitle;
  final String Function(NoteEntry entry) notePreview;
  final TextEditingController noteTitleController;
  final TextEditingController noteContentController;
  final TextEditingController noteIngredientsController;
  final TextEditingController noteInstructionsController;
  final Future<void> Function(String title) onCreateNoteWithTitle;
  final Future<void> Function(String title) onCreateRecipeWithTitle;
  final Future<void> Function(String noteId) onSelectNote;
  final Future<void> Function(NoteEntry entry) onEditNote;
  final Future<void> Function(String noteId) onConvertNoteToTask;
  final Future<void> Function(String noteId) onDeleteNote;
  final Future<void> Function(int index) onEditInboxEntry;
  final Future<void> Function(int index) onConvertInboxEntryToNote;
  final Future<void> Function(int index) onConvertInboxEntryToTask;
  final Future<void> Function(int index) onRemoveInboxEntry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : wideContentWidth.clamp(0, constraints.maxWidth).toDouble();
        final useTwoPaneLayout = constraints.maxWidth >= 1100;

        return NotesView(
          contentWidth: contentWidth,
          useTwoPaneLayout: useTwoPaneLayout,
          noteEntries: noteEntries,
          selectedNoteId: selectedNoteId,
          inboxEntries: inboxEntries,
          displayNoteTitle: displayNoteTitle,
          notePreview: notePreview,
          noteTitleController: noteTitleController,
          noteContentController: noteContentController,
          noteIngredientsController: noteIngredientsController,
          noteInstructionsController: noteInstructionsController,
          onCreateNoteWithTitle: onCreateNoteWithTitle,
          onCreateRecipeWithTitle: onCreateRecipeWithTitle,
          onSelectNote: onSelectNote,
          onEditNote: onEditNote,
          onConvertNoteToTask: onConvertNoteToTask,
          onDeleteNote: onDeleteNote,
          onEditInboxEntry: onEditInboxEntry,
          onConvertInboxEntryToNote: onConvertInboxEntryToNote,
          onConvertInboxEntryToTask: onConvertInboxEntryToTask,
          onRemoveInboxEntry: onRemoveInboxEntry,
        );
      },
    );
  }
}
