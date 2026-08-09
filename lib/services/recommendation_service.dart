import 'package:adhd_assistant/models/task.dart';

class RecommendationService {
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
    if (task.dueDate == null) return 100000;

    try {
      final date = DateTime.parse(task.dueDate!);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return date.difference(today).inDays;
    } catch (_) {
      return 100000;
    }
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
      final dueA = getDueDays(a);
      final dueB = getDueDays(b);

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
      if (dueDate == null) return "";

      final date = DateTime.parse(dueDate);
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

    if (task.subtasks.isNotEmpty) {
      final incomplete = task.subtasks.where((s) => s.done != true).toList();

      if (incomplete.isNotEmpty) {
        final dueLine = dueLabel.isNotEmpty ? "\nDue: $dueLabel" : "";
        return '''
Task:
${task.task}$dueLine

Next step:
${incomplete.first.text}
''';
      }
    }

    final dueLine = dueLabel.isNotEmpty ? "\nDue: $dueLabel" : "";

    return '''
Task:
${task.task}$dueLine
''';
  }
}
