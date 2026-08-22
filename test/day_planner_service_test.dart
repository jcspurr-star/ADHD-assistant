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

  test('buildPlan lets activities start at zero-duration calendar events', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Start on time',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'instant-1',
          subject: 'Reminder',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 9),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    final task = result.entries.firstWhere((entry) => entry.type == 'task');
    expect(task.start, DateTime(2024, 1, 2, 9));
  });

  test('buildPlan can show a Home event without using it for planning', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Plan through appointment',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'home-appointment',
          subject: 'Personal appointment',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 10),
          isAllDay: false,
          calendarSource: 'home',
        ),
      ],
      day: DateTime(2024, 1, 2),
      nonBlockingCalendarEventIds: const {'calendar-home-appointment'},
    );

    expect(
      result.entries.any((entry) => entry.id == 'calendar-home-appointment'),
      isTrue,
    );
    final task = result.entries.firstWhere((entry) => entry.type == 'task');
    expect(task.start, DateTime(2024, 1, 2, 9));
  });

  test('buildPlan schedules tasks until capacity is exhausted', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        for (var index = 0; index < 6; index++)
          Task(
            task: 'Task $index',
            priority: 'high',
            dueDate: '2024-01-02',
            nextSessionEffortMinutes: 30,
          ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );

    expect(result.entries.where((entry) => entry.type == 'task'), hasLength(6));
  });

  test('buildPlan reserves capacity for fixed calendar time', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        for (var index = 0; index < 6; index++)
          Task(
            task: 'Task $index',
            priority: 'high',
            dueDate: '2024-01-02',
            nextSessionEffortMinutes: 30,
          ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'fixed-half-day',
          subject: 'Fixed event',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 13),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );

    expect(result.entries.where((entry) => entry.type == 'task'), hasLength(4));
  });

  test('buildPlan uses the focus session duration policy', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Long focus task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 90,
        ),
        Task(
          task: 'Short focus task',
          priority: 'low',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 5,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );
    final longTask = result.entries.firstWhere(
      (entry) => entry.title == 'Long focus task',
    );
    final adminBlock = result.entries.firstWhere(
      (entry) => entry.type == 'admin',
    );
    expect(longTask.end.difference(longTask.start).inMinutes, 90);
    expect(adminBlock.end.difference(adminBlock.start).inMinutes, 25);
  });

  test('buildPlan splits tasks longer than 90 minutes into sessions', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Long project',
          priority: 'high',
          dueDate: '2024-01-02',
          effortMinutes: 150,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );
    final sessions = result.entries
        .where((entry) => entry.title.startsWith('Long project (Session'))
        .toList();

    expect(sessions, hasLength(3));
    expect(
      sessions.every(
        (session) =>
            session.end.difference(session.start).inMinutes >= 25 &&
            session.end.difference(session.start).inMinutes <= 60,
      ),
      isTrue,
    );
  });

  test('buildPlan groups short tasks into an Admin Block', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        for (var index = 0; index < 3; index++)
          Task(
            task: 'Admin task $index',
            priority: 'medium',
            dueDate: '2024-01-02',
            nextSessionEffortMinutes: 10,
          ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );

    final admin = result.entries.firstWhere((entry) => entry.type == 'admin');
    expect(admin.title, 'Admin Block');
    expect(admin.end.difference(admin.start).inMinutes, 30);
    expect(admin.subtitle, contains('Admin task 0'));
  });

  test('buildPlan inserts a recovery break from cumulative focus time', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        for (var index = 0; index < 3; index++)
          Task(
            task: 'Focus $index',
            priority: 'high',
            dueDate: '2024-01-02',
            nextSessionEffortMinutes: 30,
          ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );

    final recoveryBreaks = result.entries.where(
      (entry) => entry.title == 'Recovery break',
    );
    expect(recoveryBreaks, isNotEmpty);
    expect(
      recoveryBreaks.first.end.difference(recoveryBreaks.first.start).inMinutes,
      5,
    );
  });

  test(
    'buildPlan reports tasks that do not fit capacity as rollover tasks',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          for (var index = 0; index < 10; index++)
            Task(
              id: 'large-$index',
              task: 'Large task $index',
              priority: 'high',
              dueDate: '2024-01-02',
              nextSessionEffortMinutes: 90,
            ),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      expect(result.rolloverTasks, isNotEmpty);
      expect(result.summary, contains('rolled over'));
    },
  );

  test(
    'buildPlan shows weekend calendar items without planning activities',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [Task(task: 'Weekend task', dueDate: '2024-01-06')],
        calendarEvents: [
          OutlookCalendarEvent(
            id: 'weekend-event',
            subject: 'Weekend lunch',
            start: DateTime(2024, 1, 6, 12),
            end: DateTime(2024, 1, 6, 13),
            isAllDay: false,
            calendarSource: 'home',
          ),
        ],
        day: DateTime(2024, 1, 6),
        dayContext: _homeDayContext,
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.type, 'calendar');
      expect(result.entries.single.title, 'Weekend lunch');
      expect(result.entries.any((entry) => entry.type != 'calendar'), isFalse);
      expect(result.recommendations, isEmpty);
      expect(result.summary, contains('Weekend'));
    },
  );

  test('buildPlan places a recommended Zwift ride at 6pm', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );

    final zwift = result.entries.firstWhere(
      (entry) => entry.title == 'Zwift ride',
    );
    expect(zwift.start, DateTime(2024, 1, 2, 18));
    expect(zwift.end, DateTime(2024, 1, 2, 18, 45));
  });

  test('buildPlan moves Zwift after a busy 6pm slot', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'evening-1',
          subject: 'Dinner',
          start: DateTime(2024, 1, 2, 18),
          end: DateTime(2024, 1, 2, 19),
          isAllDay: false,
          calendarSource: 'home',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );

    final zwift = result.entries.firstWhere(
      (entry) => entry.title == 'Zwift ride',
    );
    expect(zwift.start, DateTime(2024, 1, 2, 19));
  });

  test('buildPlan includes personal blocks as fixed entries', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      personalBlocks: const [
        PersonalPlannerBlock(
          id: 'personal-leave',
          title: 'Annual leave',
          startMinutes: 11 * 60,
          endMinutes: 15 * 60,
        ),
      ],
    );

    final block = result.entries.firstWhere(
      (entry) => entry.id == 'personal-leave',
    );
    expect(block.type, 'personal');
    expect(block.title, 'Annual leave');
    expect(block.isLocked, isTrue);
    expect(
      result.entries
          .where((entry) => entry.type == 'movement')
          .every(
            (movement) =>
                !movement.end.isAfter(block.start) ||
                !movement.start.isBefore(block.end),
          ),
      isTrue,
    );
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

  test('buildPlan pairs an office Work event with Walk while you work', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'work-call',
          subject: 'Planning call',
          start: DateTime(2024, 1, 2, 10),
          end: DateTime(2024, 1, 2, 11),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
      preferredConcurrentEntryIds: const {'calendar-work-call'},
    );

    final paired = result.entries.firstWhere(
      (entry) => entry.type == 'movement' && entry.isConcurrent,
    );
    expect(paired.title, 'Walk while you work');
    expect(paired.start, DateTime(2024, 1, 2, 10));
    expect(paired.end.difference(paired.start).inMinutes, 15);
  });

  test('buildPlan allows home movement during a meeting', () {
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

    expect(
      result.entries.any(
        (entry) => entry.type == 'movement' && entry.isConcurrent,
      ),
      isTrue,
    );
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
            entry.title == 'Zwift ride' ||
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

  test('buildPlan allows home movement during a selected event', () {
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

    expect(
      result.entries.any(
        (entry) => entry.type == 'movement' && entry.isConcurrent,
      ),
      isTrue,
    );
  });

  test('buildPlan keeps breaks and open blocks non-overlapping', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Focus task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 60,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'meeting-1',
          subject: 'Meeting',
          start: DateTime(2024, 1, 2, 10),
          end: DateTime(2024, 1, 2, 11),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );
    final protectedEntries = result.entries
        .where((entry) => entry.type == 'break' || entry.type == 'buffer')
        .toList();

    for (var index = 0; index < protectedEntries.length; index++) {
      for (
        var otherIndex = index + 1;
        otherIndex < protectedEntries.length;
        otherIndex++
      ) {
        final first = protectedEntries[index];
        final second = protectedEntries[otherIndex];
        expect(
          !first.end.isAfter(second.start) || !second.end.isAfter(first.start),
          isTrue,
        );
      }
    }
    expect(
      protectedEntries.every((protectedEntry) {
        return result.entries
            .where((entry) => entry.type == 'calendar')
            .every(
              (calendarEntry) =>
                  !protectedEntry.end.isAfter(calendarEntry.start) ||
                  !calendarEntry.end.isAfter(protectedEntry.start),
            );
      }),
      isTrue,
    );
    final tasks = result.entries.where((entry) => entry.type == 'task');
    expect(
      protectedEntries.every((protectedEntry) {
        return tasks.every(
          (task) =>
              !protectedEntry.start.isBefore(task.end) ||
              !protectedEntry.end.isAfter(task.start),
        );
      }),
      isTrue,
    );
  });

  test('buildPlan fills the work window with open blocks', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );
    final openBlocks = result.entries
        .where((entry) => entry.type == 'buffer')
        .toList();

    expect(openBlocks, isNotEmpty);
    expect(
      openBlocks.every(
        (block) =>
            !block.start.isBefore(DateTime(2024, 1, 2, 9)) &&
            !block.end.isAfter(DateTime(2024, 1, 2, 17)),
      ),
      isTrue,
    );
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
