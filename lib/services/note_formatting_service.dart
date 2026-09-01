import 'package:flutter/material.dart';

/// Lightweight markdown-style formatting helpers for note content: bold
/// (`**text**`), italic (`*text*`), and bullet list lines (`• `). Notes are
/// stored as plain text, so formatting is applied directly to the
/// [TextEditingController]'s text/selection rather than a rich document.
class NoteFormattingService {
  const NoteFormattingService._();

  /// Wraps the current selection with [marker] on both sides, or removes it
  /// if the selection is already wrapped with [marker]. With no selection,
  /// inserts an empty marker pair and places the cursor between them.
  static void toggleWrap(TextEditingController controller, String marker) {
    final selection = controller.selection;
    if (!selection.isValid) return;
    final text = controller.text;
    final start = selection.start;
    final end = selection.end;
    final markerLen = marker.length;

    if (start == end) {
      final newText = text.replaceRange(start, start, '$marker$marker');
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + markerLen),
      );
      return;
    }

    final selectedText = text.substring(start, end);
    final alreadyWrapped =
        selectedText.length >= markerLen * 2 &&
        selectedText.startsWith(marker) &&
        selectedText.endsWith(marker);

    final replacement = alreadyWrapped
        ? selectedText.substring(markerLen, selectedText.length - markerLen)
        : '$marker$selectedText$marker';
    final newText = text.replaceRange(start, end, replacement);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + replacement.length,
      ),
    );
  }

  /// Toggles a leading bullet ("• ") on every line touched by the current
  /// selection. Adds bullets if any touched non-blank line lacks one,
  /// otherwise removes them from all touched lines.
  static void toggleBulletLines(TextEditingController controller) {
    const bullet = '• ';
    final selection = controller.selection;
    if (!selection.isValid) return;
    final text = controller.text;

    final lineStart =
        text.lastIndexOf('\n', (selection.start - 1).clamp(0, text.length)) + 1;
    var lineEnd = text.indexOf('\n', selection.end);
    if (lineEnd == -1) lineEnd = text.length;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    final nonBlankLines = lines.where((line) => line.trim().isNotEmpty);
    final allBulleted =
        nonBlankLines.isNotEmpty &&
        nonBlankLines.every((line) => line.startsWith(bullet));

    final newLines = lines.map((line) {
      if (line.trim().isEmpty) return line;
      if (allBulleted) {
        return line.startsWith(bullet) ? line.substring(bullet.length) : line;
      }
      return line.startsWith(bullet) ? line : '$bullet$line';
    }).toList();
    final newBlock = newLines.join('\n');

    final newText = text.replaceRange(lineStart, lineEnd, newBlock);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + newBlock.length,
      ),
    );
  }

  /// Strips the lightweight markers for a clean plain-text preview snippet.
  static String stripForPreview(String text) {
    return text.replaceAll('**', '').replaceAll('*', '').replaceAll('• ', '');
  }
}
