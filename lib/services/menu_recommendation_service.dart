import '../models/menu_planning.dart';
import '../models/task.dart';

/// A task paired with its recommendation score and a short human-readable
/// reason, produced by [MenuRecommendationService].
class TaskRecommendation {
  const TaskRecommendation({
    required this.task,
    required this.score,
    required this.reason,
  });

  final Task task;
  final double score;
  final String reason;
}

/// Menu-Based Planning's recommendation engine. Matches tasks to the user's
/// current capacity (energy state) rather than ranking by urgency alone.
class MenuRecommendationService {
  static const double energyMatchWeight = 40;
  static const double priorityWeight = 20;
  static const double urgencyWeight = 20;
  static const double momentumWeight = 10;
  static const double historyWeight = 10;

  /// Categories to prioritize/avoid per energy state, used as a bonus/penalty
  /// layered on top of the raw energy-requirement match.
  static const Map<EnergyState, List<MenuCategory>> _prioritized = {
    EnergyState.burntOut: [MenuCategory.dessert, MenuCategory.appetizer],
    EnergyState.lowEnergy: [
      MenuCategory.appetizer,
      MenuCategory.sideDish,
      MenuCategory.snack,
    ],
    EnergyState.moderateEnergy: [
      MenuCategory.snack,
      MenuCategory.sideDish,
      MenuCategory.mainCourse,
    ],
    EnergyState.highEnergy: [MenuCategory.mainCourse],
    EnergyState.hyperfocused: [MenuCategory.mainCourse],
  };

  static const Map<EnergyState, List<MenuCategory>> _avoided = {
    EnergyState.burntOut: [MenuCategory.mainCourse],
    EnergyState.lowEnergy: [MenuCategory.mainCourse],
    EnergyState.moderateEnergy: [],
    EnergyState.highEnergy: [],
    EnergyState.hyperfocused: [],
  };

  static EnergyRequirement _effectiveEnergyRequired(Task task) =>
      task.energyRequired ?? EnergyRequirement.medium;

  static MenuCategory _effectiveCategory(Task task) =>
      task.menuCategory ?? MenuCategory.sideDish;

  /// How well [task] fits [state], on the same 0..energyMatchWeight*1.2
  /// scale used internally by [scoreTask]. Exposed for callers (like the day
  /// planner) that want to nudge their own scheduling by energy fit without
  /// pulling in urgency/momentum/history weighting.
  static double energyMatchScore(Task task, EnergyState state) =>
      _energyMatchScore(task, state);

  static double _energyMatchScore(Task task, EnergyState state) {
    final preferredOrder = state.preferredEnergyOrder;
    final required = _effectiveEnergyRequired(task);
    final index = preferredOrder.indexOf(required);
    final base = index == -1
        ? 0.0
        : energyMatchWeight * (1 - (index / preferredOrder.length));

    final category = _effectiveCategory(task);
    var bonus = 0.0;
    if (_prioritized[state]?.contains(category) ?? false) {
      bonus += energyMatchWeight * 0.15;
    }
    if (_avoided[state]?.contains(category) ?? false) {
      bonus -= energyMatchWeight * 0.6;
    }

    // Long deep-focus main courses are specifically discouraged when
    // burnt out or low on energy, even if the task wasn't tagged high energy.
    final isLongMainCourse =
        category == MenuCategory.mainCourse &&
        task.estimatedDuration().inMinutes > 30;
    if (isLongMainCourse &&
        (state == EnergyState.burntOut || state == EnergyState.lowEnergy)) {
      bonus -= energyMatchWeight * 0.4;
    }

    return (base + bonus).clamp(0, energyMatchWeight * 1.2);
  }

  static double _priorityScore(Task task) {
    switch (task.priority) {
      case 'high':
        return priorityWeight;
      case 'low':
        return priorityWeight * 0.3;
      default:
        return priorityWeight * 0.6;
    }
  }

  static int? _dueInDays(Task task, DateTime today) {
    final raw = task.doDate ?? task.dueDate;
    if (raw == null || raw.trim().isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  static double _urgencyScore(Task task, DateTime today) {
    final daysUntilDue = _dueInDays(task, today);
    if (daysUntilDue == null) return 0;
    if (daysUntilDue <= 0) return urgencyWeight; // overdue or due today
    if (daysUntilDue <= 2) return urgencyWeight * 0.7;
    if (daysUntilDue <= 7) return urgencyWeight * 0.4;
    return urgencyWeight * 0.1;
  }

  static double _momentumScore(Task task) {
    final category = _effectiveCategory(task);
    final minutes = task.estimatedDuration().inMinutes;
    // Short, low-friction tasks build momentum fastest.
    final durationScore = minutes <= 0
        ? momentumWeight * 0.5
        : (momentumWeight * (30 / minutes)).clamp(0, momentumWeight);
    final categoryBonus =
        (category == MenuCategory.appetizer || category == MenuCategory.snack)
        ? momentumWeight * 0.3
        : 0.0;
    return (durationScore + categoryBonus).clamp(0, momentumWeight);
  }

  static double _historyScore(Task task, List<Task> allTasks) {
    final category = _effectiveCategory(task);
    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(days: 14));

    final recentCompletions = allTasks.where((t) {
      if (t.completedAtUtc == null) return false;
      final completedAt = DateTime.tryParse(t.completedAtUtc!);
      return completedAt != null && completedAt.isAfter(recentCutoff);
    }).toList();

    if (recentCompletions.isEmpty) return historyWeight * 0.5;

    final matching = recentCompletions
        .where((t) => _effectiveCategory(t) == category)
        .length;
    final ratio = matching / recentCompletions.length;
    return (historyWeight * ratio).clamp(0, historyWeight);
  }

  /// Scores a single task against the user's current [state].
  static double scoreTask(Task task, EnergyState state, List<Task> allTasks) {
    return _energyMatchScore(task, state) +
        _priorityScore(task) +
        _urgencyScore(task, DateTime.now()) +
        _momentumScore(task) +
        _historyScore(task, allTasks);
  }

  static String _reasonFor(Task task, EnergyState state) {
    final category = _effectiveCategory(task);
    if (_avoided[state]?.contains(category) ?? false) {
      return 'Not a great match for how you feel right now, but still an option.';
    }
    if (_prioritized[state]?.contains(category) ?? false) {
      return 'Matches your ${state.label.toLowerCase()} energy right now.';
    }
    final daysUntilDue = _dueInDays(task, DateTime.now());
    if (daysUntilDue != null && daysUntilDue <= 0) {
      return 'Due soon.';
    }
    return 'A reasonable fit for your current capacity.';
  }

  /// Returns incomplete tasks ranked by recommendation score (highest first).
  static List<TaskRecommendation> recommend(
    List<Task> tasks,
    EnergyState state, {
    int? limit,
  }) {
    final incomplete = tasks
        .where((task) => task.done != true && task.hasCompletePlanningMetadata)
        .toList();
    final scored =
        incomplete
            .map(
              (task) => TaskRecommendation(
                task: task,
                score: scoreTask(task, state, tasks),
                reason: _reasonFor(task, state),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    if (limit != null && scored.length > limit) {
      return scored.sublist(0, limit);
    }
    return scored;
  }

  /// Whether a "take a recovery break afterwards" reminder should be shown.
  static bool shouldShowHyperfocusReminder(EnergyState state) =>
      state == EnergyState.hyperfocused;
}

extension on Task {
  Duration estimatedDuration() =>
      Duration(minutes: effortMinutes ?? nextSessionEffortMinutes ?? 15);
}
