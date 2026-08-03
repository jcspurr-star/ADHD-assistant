import 'package:flutter/material.dart';

class SubtaskTile extends StatelessWidget {
  final Map<String, dynamic> subtask;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  final ValueChanged<bool?> onChanged;

  const SubtaskTile({
    super.key,
    required this.subtask,
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

      leading: Checkbox(value: subtask["done"], onChanged: onChanged),

      title: Text(subtask["text"]),

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
