import 'package:flutter/material.dart';

import '../models/note_entry.dart';
import 'note_formatting_toolbar.dart';
import 'task_details_pane.dart';

class NotesView extends StatefulWidget {
  const NotesView({
    super.key,
    required this.contentWidth,
    required this.useTwoPaneLayout,
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

  final double contentWidth;
  final bool useTwoPaneLayout;
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
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  late final TextEditingController _newNoteTitleController;
  late final TextEditingController _newRecipeTitleController;
  final FocusNode _noteContentFocusNode = FocusNode();
  final FocusNode _noteIngredientsFocusNode = FocusNode();
  final FocusNode _noteInstructionsFocusNode = FocusNode();
  bool _creatingNote = false;
  bool _creatingRecipe = false;

  @override
  void initState() {
    super.initState();
    _newNoteTitleController = TextEditingController();
    _newRecipeTitleController = TextEditingController();
  }

  @override
  void dispose() {
    _newNoteTitleController.dispose();
    _newRecipeTitleController.dispose();
    _noteContentFocusNode.dispose();
    _noteIngredientsFocusNode.dispose();
    _noteInstructionsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitNewNote() async {
    if (_creatingNote) {
      return;
    }
    final title = _newNoteTitleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() {
      _creatingNote = true;
    });
    await widget.onCreateNoteWithTitle(title);
    _newNoteTitleController.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingNote = false;
    });
  }

  Future<void> _submitNewRecipe() async {
    if (_creatingRecipe) {
      return;
    }
    final title = _newRecipeTitleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() {
      _creatingRecipe = true;
    });
    await widget.onCreateRecipeWithTitle(title);
    _newRecipeTitleController.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingRecipe = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: widget.contentWidth,
            child: Row(
              children: [
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: widget.contentWidth,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _newNoteTitleController,
                    onSubmitted: (_) async {
                      await _submitNewNote();
                    },
                    decoration: InputDecoration(
                      hintText: 'New Note',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Create note',
                        icon: _creatingNote
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        onPressed: _creatingNote
                            ? null
                            : () async {
                                await _submitNewNote();
                              },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _newRecipeTitleController,
                    onSubmitted: (_) async {
                      await _submitNewRecipe();
                    },
                    decoration: InputDecoration(
                      hintText: 'New Recipe',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Create recipe',
                        icon: _creatingRecipe
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.restaurant_menu),
                        onPressed: _creatingRecipe
                            ? null
                            : () async {
                                await _submitNewRecipe();
                              },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: widget.contentWidth,
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
                  if (widget.inboxEntries.isEmpty)
                    Text(
                      'No captured items yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  if (widget.inboxEntries.isNotEmpty)
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        itemCount: widget.inboxEntries.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              widget.inboxEntries[index],
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
                                    await widget.onEditInboxEntry(index);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.post_add,
                                    size: 18,
                                    color: Colors.blueGrey,
                                  ),
                                  tooltip: 'Convert to note',
                                  onPressed: () async {
                                    await widget.onConvertInboxEntryToNote(
                                      index,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.playlist_add,
                                    size: 18,
                                  ),
                                  tooltip: 'Convert to task',
                                  onPressed: () async {
                                    await widget.onConvertInboxEntryToTask(
                                      index,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    await widget.onRemoveInboxEntry(index);
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
          // The two-pane split spans the FULL window width (50/50), unlike
          // the rest of the page which stays capped at contentWidth.
          child: widget.useTwoPaneLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildNotesListCard()),
                    const SizedBox(width: 12),
                    Expanded(child: buildNoteDetailsPane()),
                  ],
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: widget.contentWidth,
                    child: buildNotesListCard(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget buildNotesListCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: buildNotesList(),
      ),
    );
  }

  NoteEntry? get _selectedNote {
    for (final entry in widget.noteEntries) {
      if (entry.id == widget.selectedNoteId) return entry;
    }
    return null;
  }

  Widget _buildFormattedSection({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        NoteFormattingToolbar(controller: controller, focusNode: focusNode),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 6,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget buildNoteDetailsPane() {
    final note = _selectedNote;
    final isRecipe = note?.kind == 'recipe';
    return TaskDetailsPane(
      hasSelection: note != null,
      placeholderText: 'Select a note to show its contents here',
      child: note == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.noteTitleController,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Title',
                        ),
                      ),
                    ),
                    if (!isRecipe)
                      IconButton(
                        icon: const Icon(Icons.playlist_add),
                        tooltip: 'Convert note to task',
                        onPressed: () async {
                          await widget.onConvertNoteToTask(note.id);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: isRecipe ? 'Delete recipe' : 'Delete note',
                      onPressed: () async {
                        await widget.onDeleteNote(note.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isRecipe) ...[
                  _buildFormattedSection(
                    label: 'Ingredients',
                    controller: widget.noteIngredientsController,
                    focusNode: _noteIngredientsFocusNode,
                    hintText: 'List each ingredient...',
                  ),
                  const SizedBox(height: 12),
                  _buildFormattedSection(
                    label: 'Instructions',
                    controller: widget.noteInstructionsController,
                    focusNode: _noteInstructionsFocusNode,
                    hintText: 'Write the cooking steps...',
                  ),
                ] else
                  _buildFormattedSection(
                    label: 'Note',
                    controller: widget.noteContentController,
                    focusNode: _noteContentFocusNode,
                    hintText: 'Write your note...',
                  ),
              ],
            ),
    );
  }

  Widget buildNotesList() {
    if (widget.noteEntries.isEmpty) {
      return Center(
        child: Text(
          'No notes yet. Add a title above to create one.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      itemCount: widget.noteEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = widget.noteEntries[index];
        final isSelected = entry.id == widget.selectedNoteId;
        final isRecipe = entry.kind == 'recipe';
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await widget.onSelectNote(entry.id);
            if (!widget.useTwoPaneLayout) {
              await widget.onEditNote(entry);
            }
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
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.displayNoteTitle(entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRecipe
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isRecipe
                                    ? Colors.orange.shade200
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Text(
                              isRecipe ? 'Recipe' : 'Note',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isRecipe
                                    ? Colors.orange.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRecipe)
                      IconButton(
                        icon: const Icon(Icons.playlist_add, size: 18),
                        tooltip: 'Convert note to task',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await widget.onConvertNoteToTask(entry.id);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: isRecipe ? 'Delete recipe' : 'Delete note',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await widget.onDeleteNote(entry.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.notePreview(entry),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                if (isRecipe) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Recipes stay separate from task conversion.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
