import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskListItemCard extends StatelessWidget {
  const TaskListItemCard({
    super.key,
    required this.task,
    required this.gutterWidth,
    required this.gutterColor,
    required this.cardColor,
    required this.borderColor,
    required this.baseAccentColor,
    required this.isSelected,
    required this.priorityLabel,
    required this.progressPercent,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.showReorderDrag,
    required this.reorderIndex,
    this.categoryLabel,
    this.planDateLabel,
    this.dueDateLabel,
    this.expandedContent,
  });

  final Task task;
  final double gutterWidth;
  final Color gutterColor;
  final Color cardColor;
  final Color borderColor;
  final Color baseAccentColor;
  final bool isSelected;
  final String priorityLabel;
  final int progressPercent;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showReorderDrag;
  final int reorderIndex;
  final String? categoryLabel;
  final String? planDateLabel;
  final String? dueDateLabel;
  final Widget? expandedContent;

  Widget _buildMetaChip({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isSelected ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: gutterWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 8,
                decoration: BoxDecoration(
                  color: gutterColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: borderColor,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: task.done,
                            onChanged: onToggle,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                task.task,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  decoration: task.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.done
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Edit task',
                            visualDensity: VisualDensity.compact,
                            onPressed: onEdit,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            tooltip: 'Delete task',
                            visualDensity: VisualDensity.compact,
                            onPressed: onDelete,
                          ),
                          if (showReorderDrag)
                            ReorderableDragStartListener(
                              index: reorderIndex,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4, top: 4),
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildMetaChip(
                            label: priorityLabel,
                            color: baseAccentColor.withAlpha(38),
                            textColor: baseAccentColor,
                          ),
                          if (categoryLabel != null &&
                              categoryLabel!.isNotEmpty)
                            _buildMetaChip(
                              label: categoryLabel!,
                              color: Colors.blueGrey.shade50,
                              textColor: Colors.blueGrey.shade700,
                            ),
                          if (planDateLabel != null &&
                              planDateLabel!.isNotEmpty)
                            _buildMetaChip(
                              label: 'Plan $planDateLabel',
                              color: Colors.indigo.shade50,
                              textColor: Colors.indigo.shade700,
                            ),
                          if (dueDateLabel != null && dueDateLabel!.isNotEmpty)
                            _buildMetaChip(
                              label: dueDateLabel!,
                              color: Colors.orange.shade50,
                              textColor: Colors.orange.shade800,
                            ),
                          if (task.subtasks.isNotEmpty)
                            _buildMetaChip(
                              label: '$progressPercent%',
                              color: Colors.green.shade50,
                              textColor: Colors.green.shade700,
                            ),
                        ],
                      ),
                      if (expandedContent != null) ...[
                        const SizedBox(height: 8),
                        expandedContent!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
