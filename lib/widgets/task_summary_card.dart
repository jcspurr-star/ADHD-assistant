import 'package:flutter/material.dart';

import '../models/task.dart';

// Small square summary card used by the task list's "Card view" — shows just
// enough to identify a task (title, priority, subtask count, due date).
class TaskSummaryCard extends StatelessWidget {
  const TaskSummaryCard({
    super.key,
    required this.task,
    required this.priorityColor,
    required this.priorityLabel,
    required this.dueDateText,
    required this.isSelected,
    required this.onTap,
  });

  final Task task;
  final Color priorityColor;
  final String priorityLabel;
  final String dueDateText;
  final bool isSelected;
  final VoidCallback onTap;

  static const double size = 150;

  @override
  Widget build(BuildContext context) {
    final subtaskCount = task.subtasks.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: task.done ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blue.shade400
                : priorityColor.withAlpha(150),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    priorityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                task.task,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$subtaskCount subtask${subtaskCount == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            if (dueDateText.isNotEmpty)
              Text(
                dueDateText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
          ],
        ),
      ),
    );
  }
}
