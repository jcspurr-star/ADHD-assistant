import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
