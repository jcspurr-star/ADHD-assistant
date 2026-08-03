import 'package:flutter/material.dart';

class TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;

  final bool isGenerating;
  final double progress;
  final ValueChanged<bool?> onToggle;
  final Widget? dragHandle;
  final VoidCallback onExpand;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;
  final VoidCallback onAddSubtask;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPriority;
  final VoidCallback onDueDate;
  final String dueDateText;

  const TaskTile({
    super.key,
    required this.task,
    required this.isGenerating,
    required this.onToggle,
    required this.onExpand,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onAddSubtask,
    required this.onEdit,
    required this.onDelete,
    required this.progress,
    required this.onPriority,
    this.dragHandle,
    required this.onDueDate,
    required this.dueDateText,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(value: task["done"], onChanged: onToggle),

      title: Row(
        children: [
          if (task.containsKey("subtasks"))
            IconButton(
              icon: Icon(
                task["expanded"] == true
                    ? Icons.expand_more
                    : Icons.chevron_right,
              ),
              onPressed: onExpand,
            ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,

                      decoration: BoxDecoration(
                        color: task["priority"] == "high"
                            ? Colors.red
                            : task["priority"] == "medium"
                            ? Colors.orange
                            : Colors.green,

                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task["task"]),

                          if (dueDateText.isNotEmpty)
                            Text(
                              "📅 $dueDateText",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (task.containsKey("subtasks")) ...[
                  const SizedBox(height: 4),

                  LinearProgressIndicator(value: progress),

                  const SizedBox(height: 2),

                  Text(
                    "${(progress * 100).round()}%",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),

      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.psychology,
              color: isGenerating ? Colors.grey : Colors.blue,
            ),
            onPressed: isGenerating ? null : onGenerate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.purple),
            onPressed: onRegenerate,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            onPressed: onAddSubtask,
          ),
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.amber),
            onPressed: onPriority,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.teal),
            onPressed: onDueDate,
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange),
            onPressed: onEdit,
          ),

          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          ),
          ?dragHandle,
        ],
      ),
    );
  }
}
