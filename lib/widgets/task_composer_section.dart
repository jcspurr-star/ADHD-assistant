import 'package:flutter/material.dart';

class TaskComposerSection extends StatelessWidget {
  const TaskComposerSection({
    super.key,
    required this.taskController,
    required this.onAddTask,
    required this.onAddTaskWithSubtask,
  });

  final TextEditingController taskController;
  final Future<void> Function() onAddTask;
  final Future<void> Function() onAddTaskWithSubtask;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final useTwoPaneComposer = outerConstraints.maxWidth >= 1350;
        final composerWidth = useTwoPaneComposer
            ? ((outerConstraints.maxWidth - 12) * (5.0 / 11.0))
            : outerConstraints.maxWidth;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: composerWidth,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB7CCF6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, composerConstraints) {
                  final narrowComposer = composerConstraints.maxWidth < 640;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add new task',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capture it quickly, then plan it out below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: const Icon(Icons.playlist_add, size: 16),
                          label: const Text('Add task with subtask'),
                          onPressed: onAddTaskWithSubtask,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (narrowComposer) ...[
                        TextField(
                          controller: taskController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) async {
                            await onAddTask();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Task title',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onAddTask,
                            icon: const Icon(Icons.add_task),
                            label: const Text('Add task'),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: taskController,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) async {
                                  await onAddTask();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Task title',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: onAddTask,
                              icon: const Icon(Icons.add_task),
                              label: const Text('Add task'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
