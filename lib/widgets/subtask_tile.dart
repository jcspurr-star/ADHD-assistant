import 'package:flutter/material.dart';
import '../models/task.dart';

class SubtaskTile extends StatelessWidget {
  final Subtask subtask;
  final int index;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  final ValueChanged<bool?> onChanged;

  const SubtaskTile({
    super.key,
    required this.subtask,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 4,
      minLeadingWidth: 24,
      tileColor: subtask.aiSuggested ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

      leading: SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: subtask.done,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        ),
      ),

      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index.',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              subtask.text,
              style: TextStyle(
                fontWeight: subtask.aiSuggested
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),

      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            onPressed: onMoveUp,
          ),

          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: onMoveDown,
          ),

          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
            onPressed: onEdit,
          ),

          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
