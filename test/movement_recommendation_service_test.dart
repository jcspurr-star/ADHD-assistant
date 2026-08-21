import 'package:adhd_assistant/models/activity_recommendation.dart';
import 'package:adhd_assistant/services/movement_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDayTypeTargets', () {
    test('gym + WFH + evening available', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: true,
          workLocation: WorkLocation.home,
          eveningAvailable: true,
        ),
      );
      expect(targets.standingMinutes.minMinutes, 180);
      expect(targets.standingMinutes.maxMinutes, 240);
      expect(targets.walkingMinutes.minMinutes, 45);
      expect(targets.walkingMinutes.maxMinutes, 60);
      expect(targets.gym, RecommendationLevel.yes);
      expect(targets.mobility, RecommendationLevel.yes);
      expect(targets.zwift, RecommendationLevel.optional);
    });

    test('gym + WFH + evening unavailable', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: true,
          workLocation: WorkLocation.home,
          eveningAvailable: false,
        ),
      );
      expect(targets.walkingMinutes.minMinutes, 30);
      expect(targets.walkingMinutes.maxMinutes, 60);
      expect(targets.zwift, RecommendationLevel.no);
    });

    test('gym + office + evening available', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: true,
          workLocation: WorkLocation.office,
          eveningAvailable: true,
        ),
      );
      expect(targets.standingMinutes.minMinutes, 120);
      expect(targets.standingMinutes.maxMinutes, 180);
      expect(targets.walkingMinutes.minMinutes, 30);
      expect(targets.walkingMinutes.maxMinutes, 45);
      expect(targets.zwift, RecommendationLevel.optional);
    });

    test('gym + office + evening unavailable', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: true,
          workLocation: WorkLocation.office,
          eveningAvailable: false,
        ),
      );
      expect(targets.walkingMinutes.minMinutes, 20);
      expect(targets.walkingMinutes.maxMinutes, 40);
      expect(targets.zwift, RecommendationLevel.no);
    });

    test('no gym + WFH + evening available', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: false,
          workLocation: WorkLocation.home,
          eveningAvailable: true,
        ),
      );
      expect(targets.walkingMinutes.minMinutes, 60);
      expect(targets.walkingMinutes.maxMinutes, 90);
      expect(targets.gym, RecommendationLevel.no);
      expect(targets.mobility, RecommendationLevel.optional);
      expect(targets.zwift, RecommendationLevel.recommended);
    });

    test('no gym + WFH + evening unavailable', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: false,
          workLocation: WorkLocation.home,
          eveningAvailable: false,
        ),
      );
      expect(targets.walkingMinutes.minMinutes, 60);
      expect(targets.walkingMinutes.maxMinutes, 90);
      expect(targets.zwift, RecommendationLevel.no);
      expect(targets.mobility, RecommendationLevel.optional);
    });

    test('no gym + office + evening available', () {
      final targets = MovementRecommendationService.resolveDayTypeTargets(
        const DayContext(
          gymMorning: false,
          workLocation: WorkLocation.office,
          eveningAvailable: true,
        ),
      );
      expect(targets.walkingMinutes.minMinutes, 30);
      expect(targets.walkingMinutes.maxMinutes, 60);
      expect(targets.zwift, RecommendationLevel.recommended);
    });

    test(
      'no gym + office + evening unavailable is the most constrained day',
      () {
        final targets = MovementRecommendationService.resolveDayTypeTargets(
          const DayContext(
            gymMorning: false,
            workLocation: WorkLocation.office,
            eveningAvailable: false,
          ),
        );
        expect(targets.standingMinutes.minMinutes, 120);
        expect(targets.standingMinutes.maxMinutes, 180);
        expect(targets.walkingMinutes.minMinutes, 30);
        expect(targets.walkingMinutes.maxMinutes, 45);
        expect(targets.gym, RecommendationLevel.no);
        expect(targets.mobility, RecommendationLevel.no);
        expect(targets.zwift, RecommendationLevel.no);
      },
    );
  });

  group('calculateWeeklyProgress', () {
    test('reports deficit when behind the minimum target', () {
      final progress = MovementRecommendationService.calculateWeeklyProgress(
        const WeeklyActivityTotals(walkingMinutes: 200),
      );
      final walking = progress[ActivityPillar.walking]!;
      expect(walking.current, 200);
      expect(walking.target, 600);
      expect(walking.deficit, 220);
      expect(walking.surplus, 0);
      expect(walking.percentComplete, closeTo(33.33, 0.1));
    });

    test('reports surplus when above the maximum target', () {
      final progress = MovementRecommendationService.calculateWeeklyProgress(
        const WeeklyActivityTotals(gymSessions: 5),
      );
      final gym = progress[ActivityPillar.gym]!;
      expect(gym.deficit, 0);
      expect(gym.surplus, 2);
      expect(gym.percentComplete, closeTo(166.67, 0.1));
    });

    test('reports no deficit or surplus within the target range', () {
      final progress = MovementRecommendationService.calculateWeeklyProgress(
        const WeeklyActivityTotals(mobilitySessions: 4),
      );
      final mobility = progress[ActivityPillar.mobility]!;
      expect(mobility.deficit, 0);
      expect(mobility.surplus, 0);
    });
  });

  group('generateRecommendations', () {
    const homeEveningContext = DayContext(
      gymMorning: false,
      workLocation: WorkLocation.home,
      eveningAvailable: true,
    );

    test('sorts recommendations by descending priority', () {
      final recommendations =
          MovementRecommendationService.generateRecommendations(
            dayContext: homeEveningContext,
          );
      for (var i = 1; i < recommendations.length; i++) {
        expect(
          recommendations[i - 1].priority,
          greaterThanOrEqualTo(recommendations[i].priority),
        );
      }
    });

    test('omits gym recommendation on non-gym days', () {
      final recommendations =
          MovementRecommendationService.generateRecommendations(
            dayContext: homeEveningContext,
          );
      expect(
        recommendations.any((r) => r.pillar == ActivityPillar.gym),
        isFalse,
      );
    });

    test('includes gym recommendation on gym days', () {
      final recommendations =
          MovementRecommendationService.generateRecommendations(
            dayContext: const DayContext(
              gymMorning: true,
              workLocation: WorkLocation.home,
              eveningAvailable: true,
            ),
          );
      expect(
        recommendations.any((r) => r.pillar == ActivityPillar.gym),
        isTrue,
      );
    });

    test('lowers gym priority after the weekly gym target is reached', () {
      final behind = MovementRecommendationService.generateRecommendations(
        dayContext: const DayContext(
          gymMorning: true,
          workLocation: WorkLocation.home,
          eveningAvailable: false,
        ),
        weeklyTotals: const WeeklyActivityTotals(gymSessions: 0),
      );
      final complete = MovementRecommendationService.generateRecommendations(
        dayContext: const DayContext(
          gymMorning: true,
          workLocation: WorkLocation.home,
          eveningAvailable: false,
        ),
        weeklyTotals: const WeeklyActivityTotals(gymSessions: 3),
      );

      expect(
        complete.firstWhere((r) => r.pillar == ActivityPillar.gym).priority,
        lessThan(
          behind.firstWhere((r) => r.pillar == ActivityPillar.gym).priority,
        ),
      );
    });

    test('omits zwift recommendation when evening is unavailable', () {
      final recommendations =
          MovementRecommendationService.generateRecommendations(
            dayContext: const DayContext(
              gymMorning: false,
              workLocation: WorkLocation.home,
              eveningAvailable: false,
            ),
          );
      expect(
        recommendations.any((r) => r.pillar == ActivityPillar.zwift),
        isFalse,
      );
    });

    test(
      'gym completed today reduces zwift priority and raises mobility priority',
      () {
        final baseline = MovementRecommendationService.generateRecommendations(
          dayContext: homeEveningContext,
        );
        final withGymDone =
            MovementRecommendationService.generateRecommendations(
              dayContext: homeEveningContext,
              gymCompletedToday: true,
            );

        final baselineZwift = baseline.firstWhere(
          (r) => r.pillar == ActivityPillar.zwift,
        );
        final adjustedZwift = withGymDone.firstWhere(
          (r) => r.pillar == ActivityPillar.zwift,
        );
        expect(adjustedZwift.priority, lessThan(baselineZwift.priority));

        final baselineMobility = baseline.firstWhere(
          (r) => r.pillar == ActivityPillar.mobility,
        );
        final adjustedMobility = withGymDone.firstWhere(
          (r) => r.pillar == ActivityPillar.mobility,
        );
        expect(
          adjustedMobility.priority,
          greaterThan(baselineMobility.priority),
        );
      },
    );

    test('mobility priority increases after 2+ days without a session', () {
      final recent = MovementRecommendationService.generateRecommendations(
        dayContext: homeEveningContext,
        daysSinceLastMobility: 0,
      );
      final neglected = MovementRecommendationService.generateRecommendations(
        dayContext: homeEveningContext,
        daysSinceLastMobility: 3,
      );

      final recentMobility = recent.firstWhere(
        (r) => r.pillar == ActivityPillar.mobility,
      );
      final neglectedMobility = neglected.firstWhere(
        (r) => r.pillar == ActivityPillar.mobility,
      );
      expect(neglectedMobility.priority, greaterThan(recentMobility.priority));
    });

    test('walking priority increases when behind the weekly target', () {
      final onTrack = MovementRecommendationService.generateRecommendations(
        dayContext: homeEveningContext,
        weeklyTotals: const WeeklyActivityTotals(walkingMinutes: 600),
      );
      final behind = MovementRecommendationService.generateRecommendations(
        dayContext: homeEveningContext,
        weeklyTotals: const WeeklyActivityTotals(walkingMinutes: 100),
      );

      final onTrackWalking = onTrack.firstWhere(
        (r) => r.pillar == ActivityPillar.walking,
      );
      final behindWalking = behind.firstWhere(
        (r) => r.pillar == ActivityPillar.walking,
      );
      expect(behindWalking.priority, greaterThan(onTrackWalking.priority));
    });

    test('zwift priority increases when weekly zwift target is behind', () {
      final onTrack = MovementRecommendationService.generateRecommendations(
        dayContext: homeEveningContext,
        weeklyTotals: const WeeklyActivityTotals(zwiftSessions: 3),
      );
      final behind = MovementRecommendationService.generateRecommendations(
        dayContext: homeEveningContext,
        weeklyTotals: const WeeklyActivityTotals(zwiftSessions: 0),
      );

      final onTrackZwift = onTrack.firstWhere(
        (r) => r.pillar == ActivityPillar.zwift,
      );
      final behindZwift = behind.firstWhere(
        (r) => r.pillar == ActivityPillar.zwift,
      );
      expect(behindZwift.priority, greaterThan(onTrackZwift.priority));
    });
  });
}
