import '../models/activity_recommendation.dart';
import '../models/task.dart';
import 'day_planner_service.dart';
import 'planner_execution_service.dart';
import 'recommendation_service.dart';

class NextActionRecommendation {
  const NextActionRecommendation({
    required this.title,
    required this.description,
    required this.source,
    required this.estimatedMinutes,
    required this.reason,
    this.plannerEntry,
    this.task,
    this.movementRecommendation,
  });

  final String title;
  final String description;
  final String source;
  final int estimatedMinutes;
  final String reason;
  final DayPlannerEntry? plannerEntry;
  final Task? task;
  final ActivityRecommendation? movementRecommendation;
}

class NextActionService {
  static NextActionRecommendation? recommend({
    required DayPlannerResult plannerResult,
    required List<Task> tasks,
    DateTime? now,
    DateTime? plannerDay,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final selectedDay = plannerDay ?? today;
    final isToday =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day) == today;
    final pendingEntries = plannerResult.entries.where((entry) {
      return entry.type != 'calendar' &&
          entry.type != 'buffer' &&
          entry.executionState == ExecutionState.pending &&
          _isSameDay(entry.start, today);
    }).toList();

    final current = pendingEntries.where((entry) {
      return !reference.isBefore(entry.start) && reference.isBefore(entry.end);
    }).toList();
    if (current.isNotEmpty) {
      return _fromPlannerEntry(
        current.first,
        reason: 'This is the current pending planner entry.',
      );
    }

    final upcoming =
        pendingEntries.where((entry) => entry.start.isAfter(reference)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    if (upcoming.isNotEmpty) {
      return _fromPlannerEntry(
        upcoming.first,
        reason: 'This is the next pending planner entry.',
      );
    }

    final todayTasks = tasks
        .where(
          (task) => RecommendationService.isTaskEligibleForToday(
            task,
            day: reference,
          ),
        )
        .toList();
    final overdue = todayTasks.where((task) {
      return RecommendationService.getDueDays(task) < 0;
    }).toList();
    if (overdue.isNotEmpty) {
      final task = RecommendationService.getNextTask(overdue);
      if (task != null) {
        return _fromTask(task, reason: 'This task is overdue.');
      }
    }

    final dueToday = todayTasks.where((task) {
      return RecommendationService.getDueDays(task) == 0;
    }).toList();
    if (dueToday.isNotEmpty) {
      final task = RecommendationService.getNextTask(dueToday);
      if (task != null) {
        return _fromTask(task, reason: 'This task is due today.');
      }
    }

    final task = RecommendationService.getNextTask(todayTasks);
    if (task != null) {
      return _fromTask(
        task,
        reason: 'This is the highest-ranked task recommendation.',
      );
    }

    final movement = !isToday || plannerResult.recommendations.isEmpty
        ? null
        : plannerResult.recommendations.first;
    if (movement != null) {
      return NextActionRecommendation(
        title: movement.title,
        description: movement.description,
        source: 'Movement recommendation',
        estimatedMinutes: movement.estimatedDuration.inMinutes,
        reason: 'This is the highest-ranked movement recommendation.',
        movementRecommendation: movement,
      );
    }

    return null;
  }

  static bool _isSameDay(DateTime value, DateTime day) {
    final local = value.toLocal();
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  static NextActionRecommendation _fromPlannerEntry(
    DayPlannerEntry entry, {
    required String reason,
  }) {
    return NextActionRecommendation(
      title: entry.title,
      description: entry.subtitle ?? 'Scheduled planner entry',
      source: 'Planner timeline',
      estimatedMinutes: entry.end.difference(entry.start).inMinutes,
      reason: reason,
      plannerEntry: entry,
      task: entry.task,
    );
  }

  static NextActionRecommendation _fromTask(
    Task task, {
    required String reason,
  }) {
    final estimatedMinutes =
        task.nextSessionEffortMinutes ?? task.effortMinutes ?? 60;
    return NextActionRecommendation(
      title: task.task,
      description: task.nextAction.trim().isEmpty
          ? task.starterTinyStep
          : task.nextAction,
      source: 'Task recommendation',
      estimatedMinutes: estimatedMinutes,
      reason: reason,
      task: task,
    );
  }
}
