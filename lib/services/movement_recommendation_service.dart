import '../models/activity_recommendation.dart';

/// Rules-based movement recommendation engine.
///
/// Replaces fixed/linear movement scheduling with recommendations derived from
/// today's context (gym/work location/evening availability), weekly progress
/// against seeded targets, and the remaining opportunities in the day.
class MovementRecommendationService {
  /// Resolves the standing/walking/gym/mobility/zwift targets for one of the
  /// day contexts described by [context]. Location supplies the baseline;
  /// gym and evening availability then modify that baseline.
  static DayTypeTargets resolveDayTypeTargets(DayContext context) {
    var targets = _baseTargetsForLocation(context.workLocation);
    targets = _applyGymModifier(targets, context);
    targets = _applyEveningModifier(targets, context);
    return targets.copyWith(notes: _notesFor(context));
  }

  static DayTypeTargets _baseTargetsForLocation(WorkLocation location) {
    return location == WorkLocation.home
        ? const DayTypeTargets(
            standingMinutes: MinutesRange(180, 240),
            walkingMinutes: MinutesRange(60, 90),
            gym: RecommendationLevel.no,
            mobility: RecommendationLevel.optional,
            zwift: RecommendationLevel.no,
            notes: '',
          )
        : const DayTypeTargets(
            standingMinutes: MinutesRange(120, 180),
            walkingMinutes: MinutesRange(30, 45),
            gym: RecommendationLevel.no,
            mobility: RecommendationLevel.no,
            zwift: RecommendationLevel.no,
            notes: '',
          );
  }

  static DayTypeTargets _applyGymModifier(
    DayTypeTargets targets,
    DayContext context,
  ) {
    if (!context.gymMorning) return targets;

    final walkingMinutes = context.workLocation == WorkLocation.home
        ? context.eveningAvailable
              ? const MinutesRange(45, 60)
              : const MinutesRange(30, 60)
        : context.eveningAvailable
        ? const MinutesRange(30, 45)
        : const MinutesRange(20, 40);
    return targets.copyWith(
      walkingMinutes: walkingMinutes,
      gym: RecommendationLevel.yes,
      mobility: RecommendationLevel.yes,
    );
  }

  static DayTypeTargets _applyEveningModifier(
    DayTypeTargets targets,
    DayContext context,
  ) {
    if (!context.eveningAvailable) return targets;

    return targets.copyWith(
      walkingMinutes:
          context.workLocation == WorkLocation.office && !context.gymMorning
          ? const MinutesRange(30, 60)
          : null,
      mobility: context.gymMorning ? null : RecommendationLevel.optional,
      zwift: context.gymMorning
          ? RecommendationLevel.optional
          : RecommendationLevel.recommended,
    );
  }

  static String _notesFor(DayContext context) {
    if (context.gymMorning) {
      if (context.workLocation == WorkLocation.home) {
        return context.eveningAvailable
            ? 'Gym provides the main training stimulus. Focus the rest of the day on movement accumulation.'
            : 'Typical family-heavy day. Walking pad should be prioritised.';
      }
      return context.eveningAvailable
          ? 'Walking comes from walking breaks, walking meetings and a lunch walk.'
          : 'Lower target due to office + commute + family demands.';
    }
    if (context.workLocation == WorkLocation.home) {
      return context.eveningAvailable
          ? 'One of the best days for aerobic volume.'
          : 'Walking pad should replace evening exercise.';
    }
    return context.eveningAvailable
        ? 'Ideal Zwift day.'
        : 'Most constrained day. Success is measured by standing and walking accumulation.';
  }

  /// Compares this week's totals against [targets] for every pillar.
  static Map<ActivityPillar, ActivityProgress> calculateWeeklyProgress(
    WeeklyActivityTotals totals, [
    WeeklyTargets targets = const WeeklyTargets(),
  ]) {
    return {
      for (final pillar in ActivityPillar.values)
        pillar: ActivityProgress.calculate(
          pillar: pillar,
          current: totals.forPillar(pillar),
          target: targets.forPillar(pillar),
        ),
    };
  }

  /// Generates prioritized movement recommendations for today.
  static List<ActivityRecommendation> generateRecommendations({
    required DayContext dayContext,
    WeeklyActivityTotals weeklyTotals = const WeeklyActivityTotals(),
    WeeklyTargets weeklyTargets = const WeeklyTargets(),
    bool gymCompletedToday = false,
    int daysSinceLastMobility = 0,
  }) {
    final targets = resolveDayTypeTargets(dayContext);
    final progress = calculateWeeklyProgress(weeklyTotals, weeklyTargets);
    final isHome = dayContext.workLocation == WorkLocation.home;
    final recommendations = <ActivityRecommendation>[];

    var walkingPriority = 50;
    if (isHome) walkingPriority += 10;
    if (!isHome) walkingPriority += 10;
    if (progress[ActivityPillar.walking]!.deficit > 0) walkingPriority += 20;
    final walkingMid =
        ((targets.walkingMinutes.minMinutes +
                    targets.walkingMinutes.maxMinutes) /
                2)
            .round()
            .clamp(10, 30);
    recommendations.add(
      ActivityRecommendation(
        title: isHome ? 'Walking pad session' : 'Walking break',
        description: isHome
            ? 'Walk while you work toward today\'s ${targets.walkingMinutes.minMinutes}-${targets.walkingMinutes.maxMinutes} min target.'
            : 'Take a walking break or walking meeting toward today\'s ${targets.walkingMinutes.minMinutes}-${targets.walkingMinutes.maxMinutes} min target.',
        pillar: ActivityPillar.walking,
        priority: walkingPriority,
        estimatedDuration: Duration(minutes: walkingMid),
      ),
    );

    var standingPriority = 50;
    if (!isHome) standingPriority += 10;
    if (progress[ActivityPillar.standing]!.deficit > 0) standingPriority += 20;
    recommendations.add(
      ActivityRecommendation(
        title: 'Standing desk block',
        description:
            'Stand for a block toward today\'s ${(targets.standingMinutes.minMinutes / 60).toStringAsFixed(0)}-${(targets.standingMinutes.maxMinutes / 60).toStringAsFixed(0)}h target.',
        pillar: ActivityPillar.standing,
        priority: standingPriority,
        estimatedDuration: const Duration(minutes: 30),
      ),
    );

    if (targets.gym == RecommendationLevel.yes) {
      final gymPriority = progress[ActivityPillar.gym]!.deficit > 0 ? 70 : 40;
      recommendations.add(
        ActivityRecommendation(
          title: 'Gym session',
          description: 'Gym provides today\'s main training stimulus.',
          pillar: ActivityPillar.gym,
          priority: gymPriority,
          estimatedDuration: Duration(minutes: 60),
        ),
      );
    }

    if (targets.mobility != RecommendationLevel.no) {
      var mobilityPriority = targets.mobility == RecommendationLevel.yes
          ? 55
          : 35;
      if (gymCompletedToday) mobilityPriority += 15;
      if (daysSinceLastMobility >= 2) mobilityPriority += 20;
      recommendations.add(
        ActivityRecommendation(
          title: 'Mobility session',
          description: 'Short mobility/stretch session to support recovery.',
          pillar: ActivityPillar.mobility,
          priority: mobilityPriority,
          estimatedDuration: const Duration(minutes: 10),
        ),
      );
    }

    if (dayContext.eveningAvailable &&
        targets.zwift != RecommendationLevel.no) {
      var zwiftPriority = targets.zwift == RecommendationLevel.recommended
          ? 45
          : 25;
      if (gymCompletedToday) zwiftPriority -= 15;
      if (progress[ActivityPillar.zwift]!.deficit > 0) zwiftPriority += 15;
      recommendations.add(
        ActivityRecommendation(
          title: 'Zwift ride',
          description: 'Evening Zwift ride to build aerobic volume.',
          pillar: ActivityPillar.zwift,
          priority: zwiftPriority,
          estimatedDuration: const Duration(minutes: 45),
        ),
      );
    }

    recommendations.sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations;
  }
}
