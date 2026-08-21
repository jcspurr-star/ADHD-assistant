import 'package:flutter/material.dart';

class _MondayMaterialLocalizations extends DefaultMaterialLocalizations {
  const _MondayMaterialLocalizations();

  @override
  int get firstDayOfWeekIndex => DateTime.monday;
}

class _MondayMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MondayMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const _MondayMaterialLocalizations();
  }

  @override
  bool shouldReload(_MondayMaterialLocalizationsDelegate old) => false;
}

enum TaskDateDialogAction { set, remove }

class TaskDateDialogResult {
  const TaskDateDialogResult._({required this.action, this.isoDate});

  final TaskDateDialogAction action;
  final String? isoDate;

  const TaskDateDialogResult.set(String isoDate)
    : this._(action: TaskDateDialogAction.set, isoDate: isoDate);

  const TaskDateDialogResult.remove()
    : this._(action: TaskDateDialogAction.remove);
}

class TaskFieldDialogs {
  static Future<TaskDateDialogResult?> showTaskDateDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String? currentValue,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDate = DateTime.tryParse(currentValue ?? '');
    final initialDate = currentDate != null && currentDate.isAfter(today)
        ? currentDate
        : today;

    final hasCurrentValue =
        currentValue != null && currentValue.trim().isNotEmpty;

    if (hasCurrentValue) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop('remove');
                },
                child: const Text('Remove date'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop('cancel');
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop('pick');
                },
                child: const Text('Choose date'),
              ),
            ],
          );
        },
      );

      if (action == 'remove') {
        return const TaskDateDialogResult.remove();
      }
      if (action != 'pick') {
        return null;
      }
    }

    if (!context.mounted) {
      return null;
    }

    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return Localizations.override(
          context: dialogContext,
          locale: const Locale('en', 'GB'),
          delegates: const [_MondayMaterialLocalizationsDelegate()],
          child: DatePickerDialog(
            initialDate: initialDate,
            firstDate: today,
            lastDate: DateTime(2100),
          ),
        );
      },
    );

    if (pickedDate == null) {
      return null;
    }

    return TaskDateDialogResult.set(
      pickedDate.toIso8601String().split('T').first,
    );
  }

  static Future<int?> showEffortDialog({
    required BuildContext context,
    required String title,
    required String description,
    required List<int> options,
    required String Function(int? minutes) formatEffortLabel,
    required bool allowClear,
  }) async {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in options)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(minutes);
                      },
                      child: Text(formatEffortLabel(minutes)),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            if (allowClear)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(-1);
                },
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
