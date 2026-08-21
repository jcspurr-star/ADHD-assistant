import 'package:adhd_assistant/models/activity_recommendation.dart';
import 'package:adhd_assistant/services/activity_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final weekReference = DateTime(2026, 8, 19, 12);

  test('ActivityLogEntry round trips through JSON', () {
    final entry = ActivityLogEntry(
      id: 'walking-1',
      pillar: ActivityPillar.walking,
      completedAt: DateTime.utc(2026, 8, 19, 10),
      minutes: 25,
    );

    final decoded = ActivityLogEntry.fromJson(entry.toJson());

    expect(decoded.id, entry.id);
    expect(decoded.pillar, entry.pillar);
    expect(decoded.completedAt, entry.completedAt);
    expect(decoded.minutes, 25);
    expect(decoded.source, ActivitySource.recommendation);
  });

  test('old activity entries default to recommendation source', () {
    final entry = ActivityLogEntry.fromJson({
      'id': 'legacy',
      'pillar': 'gym',
      'completedAt': '2026-08-19T10:00:00Z',
    });

    expect(entry.source, ActivitySource.recommendation);
  });

  test('groupByDay sorts days and entries newest first', () {
    final grouped = ActivityTrackingService.groupByDay([
      ActivityLogEntry(
        id: 'older',
        pillar: ActivityPillar.walking,
        completedAt: DateTime(2026, 8, 18, 8),
        minutes: 10,
      ),
      ActivityLogEntry(
        id: 'newer',
        pillar: ActivityPillar.gym,
        completedAt: DateTime(2026, 8, 19, 10),
      ),
      ActivityLogEntry(
        id: 'same-day-later',
        pillar: ActivityPillar.mobility,
        completedAt: DateTime(2026, 8, 18, 20),
      ),
    ]);

    expect(grouped.keys.first, DateTime(2026, 8, 19));
    expect(grouped[DateTime(2026, 8, 18)]!.first.id, 'same-day-later');
  });

  test('deleting an activity recalculates totals from remaining logs', () {
    final logs = [
      ActivityLogEntry(
        id: 'keep',
        pillar: ActivityPillar.walking,
        completedAt: weekReference,
        minutes: 20,
      ),
      ActivityLogEntry(
        id: 'remove',
        pillar: ActivityPillar.walking,
        completedAt: weekReference,
        minutes: 30,
      ),
    ];
    final remaining = ActivityTrackingService.withoutId(logs, 'remove');
    final totals = ActivityTrackingService.calculateWeeklyTotals(
      remaining,
      now: weekReference,
    );

    expect(totals.walkingMinutes, 20);
  });

  test('insights explain deficits and achieved activity', () {
    final insights = ActivityTrackingService.generateInsights(
      const WeeklyActivityTotals(
        walkingMinutes: 325,
        mobilitySessions: 3,
        gymSessions: 4,
      ),
    );

    expect(insights, contains('You are 95 minutes from your walking target.'));
    expect(insights, contains('You completed 3 mobility sessions this week.'));
    expect(insights, contains('You have exceeded your gym target.'));
  });

  test('manual activity creation applies source and duration rules', () {
    final walking = ActivityTrackingService.createManualEntry(
      pillar: ActivityPillar.walking,
      minutes: 30,
      completedAt: weekReference,
      id: 'manual-walk',
    );
    final gym = ActivityTrackingService.createManualEntry(
      pillar: ActivityPillar.gym,
      minutes: 999,
      completedAt: weekReference,
      id: 'manual-gym',
    );
    final invalidStanding = ActivityTrackingService.createManualEntry(
      pillar: ActivityPillar.standing,
      minutes: 0,
    );

    expect(walking!.source, ActivitySource.manual);
    expect(walking.minutes, 30);
    expect(gym!.minutes, isNull);
    expect(invalidStanding, isNull);
  });

  test(
    'weekly rollup includes Monday through Sunday and excludes other weeks',
    () {
      final logs = [
        ActivityLogEntry(
          id: 'walking',
          pillar: ActivityPillar.walking,
          completedAt: DateTime(2026, 8, 17, 9),
          minutes: 30,
        ),
        ActivityLogEntry(
          id: 'standing',
          pillar: ActivityPillar.standing,
          completedAt: DateTime(2026, 8, 19, 9),
          minutes: 90,
        ),
        ActivityLogEntry(
          id: 'gym',
          pillar: ActivityPillar.gym,
          completedAt: DateTime(2026, 8, 23, 9),
        ),
        ActivityLogEntry(
          id: 'old',
          pillar: ActivityPillar.walking,
          completedAt: DateTime(2026, 8, 16, 23),
          minutes: 100,
        ),
      ];

      final totals = ActivityTrackingService.calculateWeeklyTotals(
        logs,
        now: weekReference,
      );

      expect(totals.walkingMinutes, 30);
      expect(totals.standingHours, 1.5);
      expect(totals.gymSessions, 1);
    },
  );

  test('session pillars count entries while duration pillars use minutes', () {
    final totals = ActivityTrackingService.calculateWeeklyTotals([
      ActivityLogEntry(
        id: 'gym-1',
        pillar: ActivityPillar.gym,
        completedAt: weekReference,
        minutes: 60,
      ),
      ActivityLogEntry(
        id: 'gym-2',
        pillar: ActivityPillar.gym,
        completedAt: weekReference,
      ),
      ActivityLogEntry(
        id: 'zwift-1',
        pillar: ActivityPillar.zwift,
        completedAt: weekReference,
      ),
      ActivityLogEntry(
        id: 'mobility-1',
        pillar: ActivityPillar.mobility,
        completedAt: weekReference,
      ),
    ], now: weekReference);

    expect(totals.gymSessions, 2);
    expect(totals.zwiftSessions, 1);
    expect(totals.mobilitySessions, 1);
    expect(totals.walkingMinutes, 0);
  });
}
