import 'package:flutter/material.dart';
import '../models/task.dart';

class SubtaskTile extends StatelessWidget {
  final Subtask subtask;
  final int index;
  final int reorderableIndex;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDate;

  final ValueChanged<bool?> onChanged;
  final String plannedDateText;

  const SubtaskTile({
    super.key,
    required this.subtask,
    required this.index,
    required this.reorderableIndex,
    required this.onEdit,
    required this.onDelete,
    required this.onDate,
    required this.onChanged,
    required this.plannedDateText,
  });

  @override
  Widget build(BuildContext context) {
    final subtaskSurfaceColor = index.isEven
        ? Colors.white
        : Colors.blueGrey.shade50.withAlpha(120);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: subtaskSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: Checkbox(
                        value: subtask.done,
                        onChanged: onChanged,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -3,
                          vertical: -3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$index.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtask.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: subtask.aiSuggested
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onDate,
                      child: Container(
                        height: 40,
                        width: 106,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              plannedDateText.trim().isEmpty
                                  ? Icons.event_available_outlined
                                  : Icons.event_available,
                              size: 14,
                              color: Colors.indigo.shade600,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                child: Text(
                                  plannedDateText.trim().isEmpty
                                      ? 'No plan'
                                      : plannedDateText,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: plannedDateText.trim().isEmpty
                                        ? Colors.grey.shade600
                                        : Colors.indigo.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.orange,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: reorderableIndex,
              child: Tooltip(
                message: 'Drag to reorder subtask',
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
