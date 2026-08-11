import 'package:adhd_assistant/models/task.dart';

class RecommendationService {
  static DateTime? _parseTaskDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static int getPriorityScore(String priority) {
    switch (priority) {
      case "high":
        return 3;
      case "medium":
        return 2;
      case "low":
        return 1;
      default:
        return 2;
    }
  }

  static int getDueDays(Task task) {
    final date = _parseTaskDate(task.dueDate);
    if (date == null) return 100000;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    return targetDate.difference(today).inDays;
  }

  static int getPlanningDays(Task task) {
    final date =
        _parseTaskDate(task.doDate) ??
        _parseTaskDate(task.dueDate) ??
        _firstPlannedIncompleteSubtaskDate(task);
    if (date == null) return 100000;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    return targetDate.difference(today).inDays;
  }

  static bool isTaskEligibleForToday(Task task, {DateTime? day}) {
    if (task.done == true) {
      return false;
    }

    final reference = day ?? DateTime.now();
    final targetDay = DateTime(reference.year, reference.month, reference.day);
    final doDate = _parseTaskDate(task.doDate);
    if (doDate != null) {
      final normalizedDoDate = DateTime(doDate.year, doDate.month, doDate.day);
      return !normalizedDoDate.isAfter(targetDay);
    }

    final currentSubtask = _currentNextSubtask(task, day: targetDay);
    if (currentSubtask != null &&
        _parseTaskDate(currentSubtask.doDate) != null) {
      final subtaskDate = _parseTaskDate(currentSubtask.doDate)!;
      final normalizedSubtaskDate = DateTime(
        subtaskDate.year,
        subtaskDate.month,
        subtaskDate.day,
      );
      return !normalizedSubtaskDate.isAfter(targetDay);
    }

    return _parseTaskDate(task.dueDate) != null;
  }

  static DateTime? _firstPlannedIncompleteSubtaskDate(Task task) {
    DateTime? earliest;
    for (final subtask in task.subtasks) {
      if (subtask.done == true) {
        continue;
      }

      final date = _parseTaskDate(subtask.doDate);
      if (date == null) {
        continue;
      }

      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }
    return earliest;
  }

  static Subtask? _currentNextSubtask(Task task, {DateTime? day}) {
    final reference = day ?? DateTime.now();
    final targetDay = DateTime(reference.year, reference.month, reference.day);
    Subtask? firstUndated;
    Subtask? firstFutureDated;

    for (final subtask in task.subtasks) {
      if (subtask.done == true) {
        continue;
      }

      final date = _parseTaskDate(subtask.doDate);
      if (date == null) {
        firstUndated ??= subtask;
        continue;
      }

      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!normalizedDate.isAfter(targetDay)) {
        return subtask;
      }

      firstFutureDated ??= subtask;
    }

    return firstUndated ?? firstFutureDated;
  }

  static double getTaskProgress(Task task) {
    if (task.subtasks.isEmpty) return task.done ? 1.0 : 0.0;

    final completed = task.subtasks.where((s) => s.done == true).length;

    return completed / task.subtasks.length;
  }

  static Task? getNextTask(List<Task> tasks) {
    final unfinishedTasks = tasks.where((t) => t.done != true).toList();

    if (unfinishedTasks.isEmpty) return null;

    unfinishedTasks.sort((a, b) {
      final dueA = getPlanningDays(a);
      final dueB = getPlanningDays(b);

      if (dueA != dueB) return dueA.compareTo(dueB);

      final priorityCompare = getPriorityScore(
        b.priority,
      ).compareTo(getPriorityScore(a.priority));

      if (priorityCompare != 0) return priorityCompare;

      final progA = getTaskProgress(a);
      final progB = getTaskProgress(b);

      return progA.compareTo(progB);
    });

    return unfinishedTasks.first;
  }

  static String getRecommendation(List<Task> tasks) {
    final task = getNextTask(tasks);

    if (task == null) return "🎉 Everything is complete!";

    String formatDueDate(String? dueDate) {
      final date = _parseTaskDate(dueDate);
      if (date == null) return "";
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      final difference = targetDate.difference(today).inDays;

      if (difference < 0) return "Overdue";
      if (difference == 0) return "Today";
      if (difference == 1) return "Tomorrow";
      if (difference <= 7) return "In $difference days";

      return "${date.day}/${date.month}/${date.year}";
    }

    final dueLabel = formatDueDate(task.dueDate);
    final doLabel = formatDueDate(task.doDate);
    final planningLine = doLabel.isNotEmpty ? "\nPlanned: $doLabel" : "";

    final currentSubtask = _currentNextSubtask(task);
    if (currentSubtask != null) {
      final dueLine = dueLabel.isNotEmpty ? "\nDue: $dueLabel" : "";
      return '''
Task:
${task.task}$planningLine$dueLine

Next step:
${currentSubtask.text}
''';
    }

    final dueLine = dueLabel.isNotEmpty ? "\nDue: $dueLabel" : "";
    final nextActionLine = task.starterTinyStep.trim().isNotEmpty
        ? '\nNext step:\n${task.starterTinyStep.trim()}\n'
        : '';

    return '''
Task:
${task.task}$planningLine$dueLine$nextActionLine
''';
  }
}
