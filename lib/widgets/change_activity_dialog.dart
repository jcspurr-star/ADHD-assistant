import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/day_planner_service.dart';

class ChangeActivityOption {
  const ChangeActivityOption.preset(this.label) : task = null;
  const ChangeActivityOption.task(this.task) : label = null;

  final String? label;
  final Task? task;

  String get displayLabel => label ?? task!.task;
}

Future<({Task? task, String? title})?> showChangeActivityDialog(
  BuildContext context, {
  required DayPlannerEntry entry,
  required List<Task> tasks,
  required List<String> presets,
}) async {
  final options = <ChangeActivityOption>[
    const ChangeActivityOption.preset('Focus Time'),
    ...tasks.where((task) => task.done != true).map(ChangeActivityOption.task),
    ...presets.map(ChangeActivityOption.preset),
  ];
  Task? selectedTask = entry.task;
  var typedTitle = entry.task == null ? entry.title : '';

  return showDialog<({Task? task, String? title})>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Change "${entry.title}"'),
      content: SizedBox(
        width: 360,
        child: Autocomplete<ChangeActivityOption>(
          initialValue: TextEditingValue(text: entry.title),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return options;
            return options.where(
              (option) => option.displayLabel.toLowerCase().contains(query),
            );
          },
          displayStringForOption: (option) => option.displayLabel,
          onSelected: (option) {
            selectedTask = option.task;
            typedTitle = option.task == null ? option.displayLabel : '';
          },
          fieldViewBuilder:
              (context, fieldController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Activity',
                    hintText: 'Pick a task, choose a preset, or type a name',
                  ),
                  onSubmitted: (_) => onFieldSubmitted(),
                  onChanged: (value) {
                    selectedTask = null;
                    typedTitle = value;
                  },
                );
              },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final trimmedTitle = typedTitle.trim();
            if (selectedTask == null && trimmedTitle.isEmpty) return;
            Navigator.of(dialogContext).pop((
              task: selectedTask,
              title: selectedTask == null ? trimmedTitle : null,
            ));
          },
          child: const Text('Change'),
        ),
      ],
    ),
  );
}
