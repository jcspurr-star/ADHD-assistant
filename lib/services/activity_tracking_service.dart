import '../models/activity_recommendation.dart';
import 'storage_service.dart';

class ActivityTrackingService {
  static const WeeklyTargets defaultTargets = WeeklyTargets();

  static ActivityLogEntry? createManualEntry({
    required ActivityPillar pillar,
    required int? minutes,
    DateTime? completedAt,
    String? id,
  }) {
    final requiresMinutes =
        pillar == ActivityPillar.walking || pillar == ActivityPillar.standing;
    if (requiresMinutes && (minutes == null || minutes <= 0)) return null;
    return ActivityLogEntry(
      id: id ?? 'activity-${DateTime.now().microsecondsSinceEpoch}',
      pillar: pillar,
      completedAt: completedAt ?? DateTime.now(),
      minutes: requiresMinutes ? minutes : null,
      source: ActivitySource.manual,
    );
  }

  static DateTime dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static Map<DateTime, List<ActivityLogEntry>> groupByDay(
    List<ActivityLogEntry> logs,
  ) {
    final grouped = <DateTime, List<ActivityLogEntry>>{};
    for (final log in logs) {
      final key = dateOnly(log.completedAt);
      grouped.putIfAbsent(key, () => <ActivityLogEntry>[]).add(log);
    }
    for (final entries in grouped.values) {
      entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  static List<String> generateInsights(
    WeeklyActivityTotals totals, {
    WeeklyTargets targets = defaultTargets,
  }) {
    final insights = <String>[];
    if (totals.walkingMinutes >= targets.walkingMinutes.max) {
      insights.add('You have reached your walking target this week.');
    } else {
      insights.add(
        'You are ${targets.walkingMinutes.min - totals.walkingMinutes} minutes from your walking target.',
      );
    }
    if (totals.mobilitySessions >= targets.mobilitySessions.min) {
      insights.add(
        'You completed ${totals.mobilitySessions} mobility sessions this week.',
      );
    }
    if (totals.gymSessions > targets.gymSessions.max) {
      insights.add('You have exceeded your gym target.');
    }
    return insights;
  }

  static List<ActivityLogEntry> withoutId(
    List<ActivityLogEntry> logs,
    String id,
  ) {
    return logs.where((entry) => entry.id != id).toList();
  }

  static List<ActivityLogEntry> withoutPlannerItem(
    List<ActivityLogEntry> logs,
    String plannerItemId,
  ) {
    return logs.where((entry) => entry.plannerItemId != plannerItemId).toList();
  }

  static Future<List<ActivityLogEntry>> loadLogs() {
    return StorageService.loadActivityLogs();
  }

  static Future<WeeklyActivityTotals> loadWeeklyTotals({DateTime? now}) async {
    final logs = await loadLogs();
    return calculateWeeklyTotals(logs, now: now);
  }

  static WeeklyActivityTotals calculateWeeklyTotals(
    List<ActivityLogEntry> logs, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    var walkingMinutes = 0;
    var standingMinutes = 0;
    var gymSessions = 0;
    var zwiftSessions = 0;
    var mobilitySessions = 0;

    for (final log in logs) {
      final completedAt = log.completedAt.toLocal();
      if (completedAt.isBefore(weekStart) || !completedAt.isBefore(weekEnd)) {
        continue;
      }
      switch (log.pillar) {
        case ActivityPillar.walking:
          walkingMinutes += log.minutes ?? 0;
        case ActivityPillar.standing:
          standingMinutes += log.minutes ?? 0;
        case ActivityPillar.gym:
          gymSessions++;
        case ActivityPillar.zwift:
          zwiftSessions++;
        case ActivityPillar.mobility:
          mobilitySessions++;
      }
    }

    return WeeklyActivityTotals(
      walkingMinutes: walkingMinutes,
      standingMinutes: standingMinutes,
      gymSessions: gymSessions,
      zwiftSessions: zwiftSessions,
      mobilitySessions: mobilitySessions,
    );
  }

  static DailyActivityTotals calculateDailyTotals(
    List<ActivityLogEntry> logs, {
    DateTime? day,
  }) {
    final target = dateOnly(day ?? DateTime.now());
    var walking = 0;
    var standing = 0;
    var gym = 0;
    var zwift = 0;
    var mobility = 0;
    for (final log in logs) {
      if (dateOnly(log.completedAt) != target) continue;
      switch (log.pillar) {
        case ActivityPillar.walking:
          walking += log.minutes ?? 0;
        case ActivityPillar.standing:
          standing += log.minutes ?? 0;
        case ActivityPillar.gym:
          gym++;
        case ActivityPillar.zwift:
          zwift++;
        case ActivityPillar.mobility:
          mobility++;
      }
    }
    return DailyActivityTotals(
      walkingMinutes: walking,
      standingMinutes: standing,
      gymSessions: gym,
      zwiftSessions: zwift,
      mobilitySessions: mobility,
    );
  }
}
