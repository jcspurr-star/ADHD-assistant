import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildPlan places tasks around calendar events and adds breaks', () {
    final day = DateTime(2024, 1, 2);
    final task = Task(task: 'Write plan', priority: 'high');
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
}
