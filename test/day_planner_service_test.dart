import 'package:adhd_assistant/models/activity_recommendation.dart';
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _homeDayContext = DayContext(
  gymMorning: false,
  workLocation: WorkLocation.home,
  eveningAvailable: true,
);
const _officeDayContext = DayContext(
  gymMorning: false,
  workLocation: WorkLocation.office,
  eveningAvailable: false,
);

void main() {
  test('buildPlan places tasks around calendar events and adds breaks', () {
    final day = DateTime(2024, 1, 2);
    final task = Task(
      task: 'Write plan',
      priority: 'high',
      dueDate: '2024-01-02',
    );
    final calendarEvent = OutlookCalendarEvent(
      id: 'meeting-1',
      subject: 'Stand-up',
      start: DateTime(2024, 1, 2, 10, 0),
      end: DateTime(2024, 1, 2, 11, 0),
      isAllDay: false,
      calendarSource: 'work',
    );

    final result = DayPlannerService.buildPlan(
      tasks: [task],
      calendarEvents: [calendarEvent],
      day: day,
    );

    expect(result.entries.any((entry) => entry.type == 'calendar'), isTrue);
    expect(result.entries.any((entry) => entry.type == 'task'), isTrue);
    expect(result.summary, contains('focus block'));
  });

  test('buildPlan excludes tasks without due dates', () {
    final day = DateTime(2024, 1, 2);
    final undatedTask = Task(task: 'Write plan', priority: 'high');

    final result = DayPlannerService.buildPlan(
      tasks: [undatedTask],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: day,
    );

    expect(result.entries.any((entry) => entry.type == 'task'), isFalse);
    expect(result.summary, isNot(contains('focus block')));
  });

  test('buildPlan adds home movement blocks without overlapping meetings', () {
    final day = DateTime(2024, 1, 2);
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'meeting-1',
          subject: 'Meeting',
          start: DateTime(2024, 1, 2, 8),
          end: DateTime(2024, 1, 2, 10),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: day,
      dayContext: _homeDayContext,
    );

    final movement = result.entries
        .where((entry) => entry.type == 'movement')
        .toList();
    expect(movement, isNotEmpty);
    expect(movement.first.start, isNot(DateTime(2024, 1, 2, 8)));
    expect(result.summary, contains('movement'));
    for (final entry in movement) {
      expect(entry.start.hour, greaterThanOrEqualTo(8));
      expect(entry.end.hour, lessThanOrEqualTo(20));
    }
  });

  test('buildPlan uses shorter office walk breaks', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );

    final movement = result.entries.where((entry) => entry.type == 'movement');
    expect(movement, hasLength(3));
    expect(
      movement.every(
        (entry) => entry.end.difference(entry.start).inMinutes == 15,
      ),
      isTrue,
    );
  });

  test('buildPlan can place movement during a suitable meeting', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'call-1',
          subject: 'Client call',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 10),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );

    final movement = result.entries.firstWhere(
      (entry) => entry.type == 'movement' && entry.isConcurrent,
    );
    expect(movement.isConcurrent, isTrue);
    expect(movement.start, equals(DateTime(2024, 1, 2, 9)));
    expect(movement.subtitle, contains('Client call'));
  });

  test('buildPlan keeps entries inside the configured workday', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );

    expect(result.entries, isNotEmpty);
    expect(
      result.entries.every(
        (entry) =>
            !entry.start.isBefore(DateTime(2024, 1, 2, 9)) &&
            !entry.end.isAfter(DateTime(2024, 1, 2, 17)),
      ),
      isTrue,
    );
  });

  test('buildPlan spaces movement across the workday', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );
    final movement = result.entries
        .where((entry) => entry.type == 'movement' && !entry.isConcurrent)
        .toList();
    expect(movement.length, greaterThanOrEqualTo(3));
    expect(
      movement[1].start.difference(movement[0].end).inMinutes,
      greaterThan(20),
    );
  });

  test('buildPlan uses a selected event for concurrent movement', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'meeting-1',
          subject: 'Deep work review',
          start: DateTime(2024, 1, 2, 13),
          end: DateTime(2024, 1, 2, 14),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      preferredConcurrentEntryIds: const {'calendar-meeting-1'},
    );

    final movement = result.entries.firstWhere(
      (entry) => entry.type == 'movement' && entry.isConcurrent,
    );
    expect(movement.start, equals(DateTime(2024, 1, 2, 13)));
    expect(movement.subtitle, contains('Deep work review'));
  });

  test('buildPlan keeps events outside the workday in the day view', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'early-1',
          subject: 'Early meeting',
          start: DateTime(2024, 1, 2, 7),
          end: DateTime(2024, 1, 2, 8),
          isAllDay: false,
          calendarSource: 'work',
        ),
        OutlookCalendarEvent(
          id: 'late-1',
          subject: 'Late meeting',
          start: DateTime(2024, 1, 2, 18),
          end: DateTime(2024, 1, 2, 19),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    expect(
      result.entries
          .where((entry) => entry.type == 'calendar')
          .map((entry) => entry.title),
      containsAll(<String>['Early meeting', 'Late meeting']),
    );
  });

  test('buildPlan uses next-session effort instead of whole-task effort', () {
    final day = DateTime(2024, 1, 2);
    final task = Task(
      task: 'Deep work block',
      priority: 'high',
      dueDate: '2024-01-02',
      effortMinutes: 360,
      nextSessionEffortMinutes: 45,
    );

    final result = DayPlannerService.buildPlan(
      tasks: [task],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: day,
    );

    final plannedTask = result.entries.firstWhere(
      (entry) => entry.type == 'task',
    );
    expect(plannedTask.end.difference(plannedTask.start).inMinutes, equals(45));
  });

  test(
    'buildPlan includes task when an incomplete subtask is planned for today',
    () {
      final day = DateTime(2024, 1, 2);
      final task = Task(
        task: 'Prepare report',
        priority: 'medium',
        subtasks: [Subtask(text: 'Draft outline', doDate: '2024-01-02')],
      );

      final result = DayPlannerService.buildPlan(
        tasks: [task],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: day,
      );

      expect(result.entries.any((entry) => entry.type == 'task'), isTrue);
    },
  );
}
