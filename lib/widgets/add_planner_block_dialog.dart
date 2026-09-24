import 'package:flutter/material.dart';

import '../models/task.dart';

Future<
  ({String category, Task? task, String title, TimeOfDay start, TimeOfDay end})?
>
showAddPlannerBlockDialog(
  BuildContext context, {
  required List<Task> tasks,
  required List<String> movementOptions,
}) {
  const categories = [
    'Work task',
    'Home task',
    'Personal',
    'Movement',
    'Break',
  ];
  const breakOptions = ['Recovery break', 'Lunch'];
  var selectedCategory = 'Personal';
  Task? selectedTask;
  String? selectedPreset;
  var title = '';
  var startTime = const TimeOfDay(hour: 9, minute: 0);
  var endTime = const TimeOfDay(hour: 10, minute: 0);

  String formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  return showDialog<
    ({
      String category,
      Task? task,
      String title,
      TimeOfDay start,
      TimeOfDay end,
    })
  >(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Add personal block'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Planner category'),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() {
                  selectedCategory = value;
                  selectedTask = null;
                  selectedPreset = null;
                  title = '';
                });
              },
            ),
            const SizedBox(height: 8),
            if (selectedCategory == 'Work task')
              DropdownButtonFormField<Task>(
                value: selectedTask,
                decoration: const InputDecoration(labelText: 'Work task'),
                items: tasks
                    .where(
                      (task) =>
                          task.done != true &&
                          (task.category.trim().toLowerCase() == 'work' ||
                              task.category.trim().toLowerCase() ==
                                  'work tasks'),
                    )
                    .map(
                      (task) =>
                          DropdownMenuItem(value: task, child: Text(task.task)),
                    )
                    .toList(),
                onChanged: (task) => setDialogState(() {
                  selectedTask = task;
                  title = task?.task ?? '';
                }),
              )
            else if (selectedCategory == 'Movement' ||
                selectedCategory == 'Break')
              DropdownButtonFormField<String>(
                value: selectedPreset,
                decoration: InputDecoration(
                  labelText: selectedCategory == 'Movement'
                      ? 'Movement'
                      : 'Break',
                ),
                items:
                    (selectedCategory == 'Movement'
                            ? movementOptions
                            : breakOptions)
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setDialogState(() {
                  selectedPreset = value;
                  title = value ?? '';
                }),
              )
            else
              TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (value) => title = value,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              trailing: Text(
                formatMinutes(startTime.hour * 60 + startTime.minute),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: dialogContext,
                  initialTime: startTime,
                );
                if (picked != null) setDialogState(() => startTime = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              trailing: Text(formatMinutes(endTime.hour * 60 + endTime.minute)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: dialogContext,
                  initialTime: endTime,
                );
                if (picked != null) setDialogState(() => endTime = picked);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmedTitle = title.trim();
              if (trimmedTitle.isEmpty ||
                  (selectedCategory == 'Work task' && selectedTask == null)) {
                return;
              }
              Navigator.of(dialogContext).pop((
                category: selectedCategory,
                task: selectedTask,
                title: trimmedTitle,
                start: startTime,
                end: endTime,
              ));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}
