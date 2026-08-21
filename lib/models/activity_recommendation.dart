/// The five movement pillars tracked by the daily movement planner.
enum ActivityPillar { walking, standing, gym, zwift, mobility }

enum ActivitySource { recommendation, manual, plannerTimeline }

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.pillar,
    required this.completedAt,
    this.minutes,
    this.source = ActivitySource.recommendation,
  });

  final String id;
  final ActivityPillar pillar;
  final DateTime completedAt;
  final int? minutes;
  final ActivitySource source;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final pillarName = json['pillar']?.toString();
    final pillar = ActivityPillar.values.firstWhere(
      (value) => value.name == pillarName,
      orElse: () => ActivityPillar.walking,
    );
    final source = ActivitySource.values.firstWhere(
      (value) => value.name == json['source']?.toString(),
      orElse: () => ActivitySource.recommendation,
    );
    return ActivityLogEntry(
      id: json['id']?.toString() ?? '',
      pillar: pillar,
      completedAt:
          DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      minutes: (json['minutes'] as num?)?.toInt(),
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar': pillar.name,
      'completedAt': completedAt.toUtc().toIso8601String(),
      'minutes': minutes,
      'source': source.name,
    };
  }
}

/// Where the user is working today.
enum WorkLocation { home, office }

/// How strongly a pillar is recommended for a given day type.
enum RecommendationLevel { no, optional, recommended, yes }

/// The three variables that define a day's movement context.
class DayContext {
  const DayContext({
    required this.gymMorning,
    required this.workLocation,
    required this.eveningAvailable,
  });

  final bool gymMorning;
  final WorkLocation workLocation;
  final bool eveningAvailable;
}

/// An inclusive minute range used for daily walking/standing targets.
class MinutesRange {
  const MinutesRange(this.minMinutes, this.maxMinutes);

  final int minMinutes;
  final int maxMinutes;
}

/// The movement targets and notes for one of the 8 day-type combinations.
class DayTypeTargets {
  const DayTypeTargets({
    required this.standingMinutes,
    required this.walkingMinutes,
    required this.gym,
    required this.mobility,
    required this.zwift,
    required this.notes,
  });

  final MinutesRange standingMinutes;
  final MinutesRange walkingMinutes;
  final RecommendationLevel gym;
  final RecommendationLevel mobility;
  final RecommendationLevel zwift;
  final String notes;
}

/// A min/max weekly target for a single pillar.
class WeeklyTarget {
  const WeeklyTarget(this.min, this.max);

  final num min;
  final num max;
}

/// Seeded default weekly targets per pillar. Configurable in future.
class WeeklyTargets {
  const WeeklyTargets({
    this.walkingMinutes = const WeeklyTarget(420, 600),
    this.standingHours = const WeeklyTarget(15, 20),
    this.gymSessions = const WeeklyTarget(3, 3),
    this.zwiftSessions = const WeeklyTarget(2, 3),
    this.mobilitySessions = const WeeklyTarget(3, 5),
  });

  final WeeklyTarget walkingMinutes;
  final WeeklyTarget standingHours;
  final WeeklyTarget gymSessions;
  final WeeklyTarget zwiftSessions;
  final WeeklyTarget mobilitySessions;

  WeeklyTarget forPillar(ActivityPillar pillar) => switch (pillar) {
    ActivityPillar.walking => walkingMinutes,
    ActivityPillar.standing => standingHours,
    ActivityPillar.gym => gymSessions,
    ActivityPillar.zwift => zwiftSessions,
    ActivityPillar.mobility => mobilitySessions,
  };
}

/// This week's actual totals so far, per pillar.
class WeeklyActivityTotals {
  const WeeklyActivityTotals({
    this.walkingMinutes = 0,
    this.standingHours = 0,
    this.gymSessions = 0,
    this.zwiftSessions = 0,
    this.mobilitySessions = 0,
  });

  final num walkingMinutes;
  final num standingHours;
  final num gymSessions;
  final num zwiftSessions;
  final num mobilitySessions;

  num forPillar(ActivityPillar pillar) => switch (pillar) {
    ActivityPillar.walking => walkingMinutes,
    ActivityPillar.standing => standingHours,
    ActivityPillar.gym => gymSessions,
    ActivityPillar.zwift => zwiftSessions,
    ActivityPillar.mobility => mobilitySessions,
  };
}

/// Progress of one pillar against its weekly target.
class ActivityProgress {
  const ActivityProgress({
    required this.pillar,
    required this.current,
    required this.target,
    required this.percentComplete,
    required this.deficit,
    required this.surplus,
  });

  final ActivityPillar pillar;
  final num current;
  final num target;
  final double percentComplete;
  final num deficit;
  final num surplus;

  factory ActivityProgress.calculate({
    required ActivityPillar pillar,
    required num current,
    required WeeklyTarget target,
  }) {
    final percent = target.max <= 0
        ? 0.0
        : (current / target.max * 100).toDouble();
    final deficit = current < target.min ? (target.min - current) : 0;
    final surplus = current > target.max ? (current - target.max) : 0;
    return ActivityProgress(
      pillar: pillar,
      current: current,
      target: target.max,
      percentComplete: percent,
      deficit: deficit,
      surplus: surplus,
    );
  }
}

/// A single prioritized movement suggestion produced by the recommendation engine.
class ActivityRecommendation {
  const ActivityRecommendation({
    required this.title,
    required this.description,
    required this.pillar,
    required this.priority,
    required this.estimatedDuration,
  });

  final String title;
  final String description;
  final ActivityPillar pillar;
  final int priority;
  final Duration estimatedDuration;
}
