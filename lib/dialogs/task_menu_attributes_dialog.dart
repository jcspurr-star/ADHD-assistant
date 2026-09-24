import 'package:flutter/material.dart';

import '../models/menu_planning.dart';

class TaskMenuAttributes {
  const TaskMenuAttributes({
    required this.category,
    required this.energyRequired,
    required this.focusRequired,
    required this.restorative,
  });

  final MenuCategory category;
  final EnergyRequirement energyRequired;
  final FocusRequirement focusRequired;
  final bool restorative;
}

/// Lets the user place a task on Today's Menu: pick its category and the
/// energy/focus it takes, so the recommendation engine can match it later.
Future<TaskMenuAttributes?> showTaskMenuAttributesDialog(
  BuildContext context, {
  required String taskTitle,
  MenuCategory? initialCategory,
  EnergyRequirement? initialEnergy,
  FocusRequirement? initialFocus,
  bool initialRestorative = false,
}) {
  var category = initialCategory ?? MenuCategory.sideDish;
  var energy = initialEnergy ?? EnergyRequirement.medium;
  var focus = initialFocus ?? FocusRequirement.medium;
  var restorative = initialRestorative;

  return showDialog<TaskMenuAttributes>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add to menu'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Menu section',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in MenuCategory.values)
                        Tooltip(
                          message: option.purpose,
                          child: ChoiceChip(
                            label: Text('${option.emoji} ${option.label}'),
                            selected: category == option,
                            onSelected: (_) =>
                                setState(() => category = option),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Energy required',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in EnergyRequirement.values)
                        Tooltip(
                          message: option.description,
                          child: ChoiceChip(
                            label: Text(option.label),
                            selected: energy == option,
                            onSelected: (_) => setState(() => energy = option),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Focus required',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in FocusRequirement.values)
                        Tooltip(
                          message: option.description,
                          child: ChoiceChip(
                            label: Text(option.label),
                            selected: focus == option,
                            onSelected: (_) => setState(() => focus = option),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: restorative,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('This is a restorative/recovery task'),
                    onChanged: (value) =>
                        setState(() => restorative = value ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  TaskMenuAttributes(
                    category: category,
                    energyRequired: energy,
                    focusRequired: focus,
                    restorative: restorative,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
