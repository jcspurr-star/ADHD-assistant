import 'package:flutter/material.dart';

import '../services/note_formatting_service.dart';

/// Compact Bold/Italic/Bullet-list buttons for a note content field. Applies
/// lightweight markdown-style markers directly to [controller]'s text.
class NoteFormattingToolbar extends StatelessWidget {
  const NoteFormattingToolbar({
    super.key,
    required this.controller,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  void _apply(void Function() action) {
    action();
    focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: 'Bold',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.format_bold, size: 18),
          onPressed: () =>
              _apply(() => NoteFormattingService.toggleWrap(controller, '**')),
        ),
        IconButton(
          tooltip: 'Italic',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.format_italic, size: 18),
          onPressed: () =>
              _apply(() => NoteFormattingService.toggleWrap(controller, '*')),
        ),
        IconButton(
          tooltip: 'Bullet list',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.format_list_bulleted, size: 18),
          onPressed: () =>
              _apply(() => NoteFormattingService.toggleBulletLines(controller)),
        ),
      ],
    );
  }
}
