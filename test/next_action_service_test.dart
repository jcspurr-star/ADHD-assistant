import 'package:adhd_assistant/models/activity_recommendation.dart';
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/services/next_action_service.dart';
import 'package:adhd_assistant/services/planner_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

DayPlannerEntry _entry(
  String id,
  String title,
  DateTime start,
  DateTime end, {
  String type = 'task',
  ExecutionState state = ExecutionState.pending,
}) {
  return DayPlannerEntry(
    id: id,
    title: title,
    type: type,
    start: start,
    end: end,
    executionState: state,
  );
}

void main() {
  final now = DateTime(2026, 8, 21, 10);

  test('prefers the current pending planner entry', () {
    final recommendation = NextActionService.recommend(
      plannerResult: DayPlannerResult(
        entries: [
          _entry(
            'current',
            'Write update',
            DateTime(2026, 8, 21, 9),
            DateTime(2026, 8, 21, 11),
          ),
          _entry(
            'next',
            'Review notes',
            DateTime(2026, 8, 21, 11),
            DateTime(2026, 8, 21, 12),
          ),
        ],
        summary: '',
      ),
      tasks: const [],
      now: now,
    );

    expect(recommendation!.title, 'Write update');
    expect(recommendation.reason, contains('current'));
  });

  test('prefers next pending planner entry over overdue task', () {
    final overdue = Task(task: 'Overdue task', dueDate: '2026-08-20');
    final recommendation = NextActionService.recommend(
      plannerResult: DayPlannerResult(
        entries: [
          _entry(
            'next',
            'Upcoming break',
            DateTime(2026, 8, 21, 11),
            DateTime(2026, 8, 21, 11, 10),
            type: 'break',
          ),
        ],
        summary: '',
      ),
      tasks: [overdue],
      now: now,
    );

    expect(recommendation!.title, 'Upcoming break');
  });

  test('falls back to overdue then due-today task', () {
    final overdue = Task(task: 'Overdue task', dueDate: '2026-08-20');
    final today = Task(task: 'Today task', dueDate: '2026-08-21');
    final recommendation = NextActionService.recommend(
      plannerResult: DayPlannerResult(entries: const [], summary: ''),
      tasks: [today, overdue],
      now: now,
    );

    expect(recommendation!.title, 'Overdue task');
    expect(recommendation.reason, contains('overdue'));
  });

  test('falls back to the highest ranked movement recommendation', () {
    final movement = const ActivityRecommendation(
      title: 'Walking break',
      description: 'Walk for a reset.',
      pillar: ActivityPillar.walking,
      priority: 60,
      estimatedDuration: Duration(minutes: 15),
    );
    final recommendation = NextActionService.recommend(
      plannerResult: DayPlannerResult(
        entries: const [],
        summary: '',
        recommendations: [movement],
      ),
      tasks: const [],
      now: now,
    );

    expect(recommendation!.title, 'Walking break');
    expect(recommendation.estimatedMinutes, 15);
  });
}
