import 'package:adhd_assistant/models/activity_recommendation.dart';
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:adhd_assistant/services/planner_break_policy.dart';
import 'package:adhd_assistant/services/planner_execution_service.dart';
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
  test('deleted lunch breaks are not recreated during replanning', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      excludedPlannerEntryIds: const {'break-lunch'},
    );

    expect(result.entries.any((entry) => entry.id == 'break-lunch'), isFalse);
  });

  test('deleted planner entries are excluded from a current-time rebuild', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          id: 'deleted-task',
          task: 'Deleted activity',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      excludedPlannerEntryIds: const {'task-deleted-task'},
      planningStart: DateTime(2024, 1, 2, 13),
    );

    expect(
      result.entries.where((entry) => entry.id == 'task-deleted-task'),
      isEmpty,
    );
    expect(
      result.entries
          .where((entry) => entry.type == 'focus')
          .every((entry) => !entry.start.isBefore(DateTime(2024, 1, 2, 13))),
      isTrue,
    );
  });

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

  test('rounds Work calendar events up to 15-minute durations', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'short-work-event',
          subject: 'Short meeting',
          start: DateTime(2024, 1, 2, 10),
          end: DateTime(2024, 1, 2, 10, 25),
          isAllDay: false,
          calendarSource: 'work',
        ),
        OutlookCalendarEvent(
          id: 'longer-work-event',
          subject: 'Longer meeting',
          start: DateTime(2024, 1, 2, 11),
          end: DateTime(2024, 1, 2, 11, 55),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    final shortEvent = result.entries.firstWhere(
      (entry) => entry.id == 'calendar-short-work-event',
    );
    final longerEvent = result.entries.firstWhere(
      (entry) => entry.id == 'calendar-longer-work-event',
    );
    expect(shortEvent.end, DateTime(2024, 1, 2, 10, 30));
    expect(longerEvent.end, DateTime(2024, 1, 2, 12));
  });

  test('work window starts with up to 60 minutes of focus time', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );

    final openingFocus = result.entries.firstWhere(
      (entry) => entry.type == 'focus',
    );
    expect(openingFocus.start, DateTime(2024, 1, 2, 9));
    expect(openingFocus.subtitle, 'Opening focus session');
    expect(openingFocus.end.difference(openingFocus.start).inMinutes, 60);
  });

  test('single-day all-day events do not carry into the following day', () {
    final sunday = DateTime(2024, 1, 7);
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'sunday-bins',
          subject: 'Black & Brown bins',
          start: sunday,
          end: sunday.add(const Duration(days: 1)),
          isAllDay: true,
          calendarSource: 'home',
        ),
      ],
      day: sunday.add(const Duration(days: 1)),
    );

    expect(
      result.entries.any((entry) => entry.id == 'calendar-sunday-bins'),
      isFalse,
    );
  });

  test('office work window also starts with focus time', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );

    final openingFocus = result.entries.firstWhere(
      (entry) => entry.type == 'focus',
    );
    expect(openingFocus.start, DateTime(2024, 1, 2, 9));
  });

  test('work event during the first hour reduces opening focus time', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'morning-work-event',
          subject: 'Work meeting',
          start: DateTime(2024, 1, 2, 9, 30),
          end: DateTime(2024, 1, 2, 10, 30),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    final openingFocus = result.entries.firstWhere(
      (entry) => entry.type == 'focus',
    );
    expect(openingFocus.start, DateTime(2024, 1, 2, 9));
    expect(openingFocus.end, DateTime(2024, 1, 2, 9, 30));
  });

  test('work event at the work-window start prevents opening focus time', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'opening-work-event',
          subject: 'Work meeting',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 10),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    expect(
      result.entries.where(
        (entry) =>
            entry.type == 'focus' && entry.start == DateTime(2024, 1, 2, 9),
      ),
      isEmpty,
    );
  });

  test('lunch reset break is never scheduled before midday', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'morning-block',
          subject: 'Morning block',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 10),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 13 * 60,
    );

    final lunch = result.entries.firstWhere(
      (entry) => entry.id == 'break-lunch',
    );
    expect(lunch.start.isBefore(DateTime(2024, 1, 2, 12)), isFalse);
  });

  test('lunch reset break remains within the midday window', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      workdayStartMinutes: 10 * 60,
      workdayEndMinutes: 18 * 60,
    );

    final lunch = result.entries.firstWhere(
      (entry) => entry.id == 'break-lunch',
    );
    expect(lunch.start.isBefore(DateTime(2024, 1, 2, 12)), isFalse);
    expect(lunch.end.isAfter(DateTime(2024, 1, 2, 14)), isFalse);
  });

  test(
    'three-hour window keeps its break out of the first hour and final 30 minutes',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: const <Task>[],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
        dayContext: _officeDayContext,
        workdayStartMinutes: 9 * 60,
        workdayEndMinutes: 12 * 60,
      );
      final walkingBreak = result.entries.firstWhere(
        (entry) => entry.type == 'movement',
      );

      expect(walkingBreak.start.isBefore(DateTime(2024, 1, 2, 10)), isFalse);
      expect(walkingBreak.end.isAfter(DateTime(2024, 1, 2, 11, 30)), isFalse);
    },
  );

  test('five-hour window keeps Lunch out of the final 30 minutes', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 14 * 60,
    );
    final lunch = result.entries.firstWhere(
      (entry) => entry.id == 'break-lunch',
    );

    expect(lunch.end.isAfter(DateTime(2024, 1, 2, 13, 30)), isFalse);
  });

  test('eight-hour window keeps final-window breaks out of the final hour', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );
    final finalWindowBreaks = result.entries.where(
      (entry) =>
          (entry.type == 'break' || entry.type == 'movement') &&
          !entry.start.isBefore(DateTime(2024, 1, 2, 14)),
    );

    expect(
      finalWindowBreaks.every(
        (entry) => !entry.end.isAfter(DateTime(2024, 1, 2, 16)),
      ),
      isTrue,
    );
  });

  test('eight-hour WFH window keeps Recovery breaks out of the final hour', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Long WFH project',
          priority: 'high',
          dueDate: '2024-01-02',
          effortMinutes: 480,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );
    final recoveryBreaks = result.entries.where(
      (entry) => entry.title == 'Recovery break',
    );

    expect(
      recoveryBreaks.every(
        (entry) => !entry.end.isAfter(DateTime(2024, 1, 2, 16)),
      ),
      isTrue,
    );
  });

  test('breaks do not overlap planning calendar events', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Office work',
          priority: 'high',
          dueDate: '2024-01-02',
          effortMinutes: 180,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'fixed-call',
          subject: 'Fixed call',
          start: DateTime(2024, 1, 2, 11),
          end: DateTime(2024, 1, 2, 12),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );
    final calendar = result.entries.firstWhere(
      (entry) => entry.id == 'calendar-fixed-call',
    );
    final breaks = result.entries.where(
      (entry) =>
          entry.type == 'break' ||
          (entry.type == 'movement' && entry.title == 'Walk break'),
    );

    expect(
      breaks.every(
        (entry) =>
            !entry.start.isBefore(calendar.end) ||
            !entry.end.isAfter(calendar.start),
      ),
      isTrue,
    );
  });

  test('buildPlan pulls forward undated tasks to fill spare capacity', () {
    final day = DateTime(2024, 1, 2);
    final undatedTask = Task(task: 'Write plan', priority: 'high');

    final result = DayPlannerService.buildPlan(
      tasks: [undatedTask],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: day,
    );

    final task = result.entries.firstWhere((entry) => entry.type == 'task');
    expect(task.subtitle, contains('Pulled forward from backlog'));
  });

  test(
    'buildPlan pulls forward tasks due after the selected day to fill spare capacity',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(task: 'Future task', priority: 'high', dueDate: '2024-01-05'),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      final task = result.entries.firstWhere((entry) => entry.type == 'task');
      expect(task.subtitle, contains('Pulled forward from backlog'));
    },
  );

  test(
    'buildPlan treats a task overdue before the selected day as backlog, not due today',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(task: 'Overdue task', priority: 'high', dueDate: '2024-01-01'),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      final task = result.entries.firstWhere((entry) => entry.type == 'task');
      expect(task.subtitle, contains('Pulled forward from backlog'));
    },
  );

  test('absolute-priority tasks claim their full effort before other tasks', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          id: 'normal-task',
          task: 'Normal task',
          priority: 'high',
          doDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
        Task(
          id: 'absolute-task',
          task: 'Absolute task',
          priority: 'low',
          dueDate: '2024-01-05',
          effortMinutes: 120,
          nextSessionEffortMinutes: 30,
          absolutePriority: true,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );

    final absoluteSessions = result.entries
        .where((entry) => entry.task?.id == 'absolute-task')
        .toList();
    expect(absoluteSessions, hasLength(2));
    expect(
      absoluteSessions.fold<int>(
        0,
        (total, entry) => total + entry.end.difference(entry.start).inMinutes,
      ),
      120,
    );
    expect(
      result.entries.firstWhere((entry) => entry.type == 'task').task?.id,
      'absolute-task',
    );
  });

  test(
    'buildPlan omits a task flagged excludeWhenOverdue once its due date has passed',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(
            task: 'Meeting prep',
            priority: 'high',
            dueDate: '2024-01-01',
            excludeWhenOverdue: true,
          ),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      expect(result.entries.any((entry) => entry.type == 'task'), isFalse);
    },
  );

  test(
    'buildPlan still schedules an excludeWhenOverdue task on its actual due day',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(
            task: 'Meeting prep',
            priority: 'high',
            dueDate: '2024-01-02',
            excludeWhenOverdue: true,
          ),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      expect(result.entries.any((entry) => entry.type == 'task'), isTrue);
    },
  );

  test(
    'buildPlan omits a task flagged waitingOnOthers even when due today',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(
            task: 'Blocked on vendor',
            priority: 'high',
            dueDate: '2024-01-02',
            waitingOnOthers: true,
          ),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      expect(result.entries.any((entry) => entry.type == 'task'), isFalse);
    },
  );

  test('buildPlan never pulls a waitingOnOthers task forward as backlog', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Blocked on vendor',
          priority: 'high',
          dueDate: '2024-06-01',
          waitingOnOthers: true,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
    );

    expect(result.entries.any((entry) => entry.type == 'task'), isFalse);
  });

  test(
    'buildPlan pulls forward a task whose do date is after the selected day',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(
            task: 'Scheduled task',
            priority: 'high',
            doDate: '2024-01-03',
            dueDate: '2024-01-02',
          ),
        ],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
      );

      final task = result.entries.firstWhere((entry) => entry.type == 'task');
      expect(task.subtitle, contains('Pulled forward from backlog'));
    },
  );

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
    expect(task.start, DateTime(2024, 1, 2, 10, 15));
  });

  test('Home calendar planning defaults to Personal-labeled events only', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'home-personal',
          subject: 'Personal appointment',
          start: DateTime(2024, 1, 2, 10),
          end: DateTime(2024, 1, 2, 11),
          isAllDay: false,
          calendarSource: 'home',
          labels: ['Personal'],
        ),
        OutlookCalendarEvent(
          id: 'home-other',
          subject: 'Other appointment',
          start: DateTime(2024, 1, 2, 12),
          end: DateTime(2024, 1, 2, 13),
          isAllDay: false,
          calendarSource: 'home',
          labels: ['Other'],
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    final personal = result.entries.firstWhere(
      (entry) => entry.id == 'calendar-home-personal',
    );
    final other = result.entries.firstWhere(
      (entry) => entry.id == 'calendar-home-other',
    );
    expect(personal.category, PlannerEventCategory.fixed);
    expect(other.category, PlannerEventCategory.informational);
  });

  test('buildPlan keeps tasks separate from eligible home calendar events', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Home task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'home-personal',
          subject: 'Personal appointment',
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 10),
          isAllDay: false,
          calendarSource: 'home',
          labels: ['Personal'],
        ),
      ],
      day: DateTime(2024, 1, 2),
    );
    final task = result.entries.firstWhere((entry) => entry.type == 'task');
    final calendar = result.entries.firstWhere(
      (entry) => entry.id == 'calendar-home-personal',
    );

    expect(
      !task.start.isBefore(calendar.end) || !task.end.isAfter(calendar.start),
      isTrue,
    );
  });

  test(
    'buildPlan does not schedule Work tasks during Work calendar events',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: [
          Task(
            task: 'KASP review of tasks',
            priority: 'high',
            dueDate: '2024-01-02',
            nextSessionEffortMinutes: 30,
          ),
        ],
        calendarEvents: [
          OutlookCalendarEvent(
            id: 'work-review',
            subject: 'Work review',
            start: DateTime(2024, 1, 2, 9),
            end: DateTime(2024, 1, 2, 10),
            isAllDay: false,
            calendarSource: 'work',
          ),
        ],
        day: DateTime(2024, 1, 2),
        nonBlockingCalendarEventIds: const {'calendar-work-review'},
      );

      final task = result.entries.firstWhere((entry) => entry.type == 'task');
      expect(
        task.start.isBefore(DateTime(2024, 1, 2, 10)) &&
            task.end.isAfter(DateTime(2024, 1, 2, 9)),
        isFalse,
      );
    },
  );

  test('recovery breaks account for opening focus and Work calendar time', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Morning task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'morning-meeting',
          subject: 'Morning meeting',
          start: DateTime(2024, 1, 2, 10),
          end: DateTime(2024, 1, 2, 11),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );

    final recoveryBreaks = result.entries
        .where((entry) => entry.title == 'Recovery break')
        .toList();
    expect(recoveryBreaks, isNotEmpty);
    expect(
      recoveryBreaks.any(
        (entry) =>
            entry.start.isAtSameMomentAs(DateTime(2024, 1, 2, 11)) ||
            entry.start.isAtSameMomentAs(DateTime(2024, 1, 2, 11, 30)),
      ),
      isTrue,
    );
    for (var index = 0; index < recoveryBreaks.length; index++) {
      for (
        var nextIndex = index + 1;
        nextIndex < recoveryBreaks.length;
        nextIndex++
      ) {
        expect(
          recoveryBreaks[index].end.isAfter(recoveryBreaks[nextIndex].start),
          isFalse,
        );
      }
    }
  });

  test('WFH recovery uses a valid gap after a Work calendar event', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Follow-up task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'morning-review',
          subject: 'Morning review',
          start: DateTime(2024, 1, 2, 10),
          end: DateTime(2024, 1, 2, 11),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );
    final recovery = result.entries.firstWhere(
      (entry) => entry.title == 'Recovery break',
    );

    expect(!recovery.start.isBefore(DateTime(2024, 1, 2, 11)), isTrue);
    expect(recovery.end.difference(recovery.start).inMinutes, 15);
  });

  test('planner keeps Break entries separated', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Long task',
          priority: 'high',
          dueDate: '2024-01-02',
          effortMinutes: 240,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'lunch-event',
          subject: 'Lunch event',
          start: DateTime(2024, 1, 2, 12),
          end: DateTime(2024, 1, 2, 12, 30),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );
    final breaks =
        result.entries.where((entry) => entry.type == 'break').toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    for (var index = 1; index < breaks.length; index++) {
      expect(
        breaks[index].start.difference(breaks[index - 1].end).inMinutes,
        greaterThanOrEqualTo(15),
      );
    }
  });

  test(
    'planner break policy uses a 15 minute recovery break after 60 minutes',
    () {
      expect(PlannerBreakPolicy.recoveryBreakMinutesForFocus(30), 0);
      expect(PlannerBreakPolicy.recoveryBreakMinutesForFocus(60), 15);
      expect(PlannerBreakPolicy.recoveryBreakMinutesForFocus(180), 15);
    },
  );

  test(
    'buildPlan splits work into 60 minute focus sessions with 15 minute breaks',
    () {
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

      final focusSessions = result.entries
          .where((entry) => entry.type == 'task')
          .map((entry) => entry.end.difference(entry.start).inMinutes)
          .toList();
      final breakSessions = result.entries.where(
        (entry) => entry.type == 'break',
      );

      expect(focusSessions, isNotEmpty);
      expect(focusSessions.every((minutes) => minutes <= 60), isTrue);
      expect(
        breakSessions.any(
          (entry) => entry.end.difference(entry.start).inMinutes == 15,
        ),
        isTrue,
      );
    },
  );

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

    expect(
      result.entries.where(
        (entry) => entry.type == 'task' && entry.title != 'Commute',
      ),
      hasLength(6),
    );
  });

  test(
    'buildPlan fills leftover gap time with real tasks instead of leaving it empty',
    () {
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

      // The soft capacity reserve leaves a gap, but that gap should be used
      // for backlog tasks rather than a generic placeholder when tasks exist.
      expect(
        result.entries.where(
          (entry) => entry.type == 'task' && entry.title != 'Commute',
        ),
        hasLength(6),
      );
    },
  );

  test('buildPlan lets due-today tasks claim the opening slot instead of a '
      'generic Focus Time placeholder', () {
    // A due-today task should be able to claim the start of the work
    // window directly, instead of a generic opening "Focus Time"
    // placeholder reserving that time first and pushing the task later
    // (or off the day entirely) to make room for it.
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          id: 'ipsg',
          task: 'IPSG to do',
          priority: 'high',
          doDate: '2024-01-02',
          dueDate: '2024-01-10',
          nextSessionEffortMinutes: 60,
        ),
        Task(
          id: 'kasp',
          task: 'KASP review of tasks',
          priority: 'medium',
          doDate: '2024-01-02',
          dueDate: '2024-01-02',
          effortMinutes: 120,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'annual-leave',
          subject: 'Annual leave',
          start: DateTime(2024, 1, 2, 12),
          end: DateTime(2024, 1, 2, 17),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 13 * 60,
    );

    final taskTitles = result.entries
        .where((entry) => entry.type == 'task')
        .map((entry) => entry.title)
        .toList();
    expect(taskTitles, contains('IPSG to do'));
    expect(result.rolloverTasks, hasLength(lessThan(2)));
  });

  test('buildPlan on a compressed WFH morning schedules real tasks instead of '
      'letting standing/walking crowd them out', () {
    // Same shape as the office regression above, but WFH: standing/walking
    // must not consume the short morning exclusively, since it's allowed
    // to run concurrently with the due-today tasks.
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          id: 'ipsg',
          task: 'IPSG to do',
          priority: 'high',
          doDate: '2024-01-02',
          dueDate: '2024-01-10',
          nextSessionEffortMinutes: 60,
        ),
        Task(
          id: 'kasp',
          task: 'KASP review of tasks',
          priority: 'medium',
          doDate: '2024-01-02',
          dueDate: '2024-01-02',
          effortMinutes: 120,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'annual-leave',
          subject: 'Annual leave',
          start: DateTime(2024, 1, 2, 12),
          end: DateTime(2024, 1, 2, 17),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 13 * 60,
    );

    final taskTitles = result.entries
        .where((entry) => entry.type == 'task')
        .map((entry) => entry.title)
        .toList();
    expect(taskTitles, contains('IPSG to do'));
    expect(result.rolloverTasks, hasLength(lessThan(2)));
  });

  test('buildPlan caps each focus session at 60 minutes', () {
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
    final focusSessions = result.entries
        .where((entry) => entry.type == 'task')
        .map((entry) => entry.end.difference(entry.start).inMinutes)
        .toList();
    expect(focusSessions, isNotEmpty);
    expect(focusSessions.every((minutes) => minutes <= 60), isTrue);
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

  test(
    'buildPlan groups short tasks into an Admin Block capped at 60 minutes',
    () {
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
      expect(admin.end.difference(admin.start).inMinutes <= 60, isTrue);
      expect(admin.subtitle, contains('Admin task 0'));
    },
  );

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
      15,
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
          labels: ['Personal'],
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

  test('buildPlan adds movement sessions on WFH days', () {
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

    expect(
      result.entries.where((entry) => entry.type == 'movement'),
      isNotEmpty,
    );
    expect(
      result.entries.where(
        (entry) =>
            entry.type == 'movement' &&
            entry.title.toLowerCase().contains('stand'),
      ),
      isNotEmpty,
    );
  });

  test('buildPlan uses shorter office walk breaks', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );

    final movement = result.entries.where(
      (entry) =>
          entry.type == 'movement' &&
          (entry.title.contains('Walk') || entry.title.contains('Stand')),
    );
    expect(movement, isNotEmpty);
    expect(
      movement.every(
        (entry) => entry.end.difference(entry.start).inMinutes == 15,
      ),
      isTrue,
    );
  });

  test('office days use Lunch and walking breaks without recovery breaks', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Office project',
          priority: 'high',
          dueDate: '2024-01-02',
          effortMinutes: 180,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );

    final breaks = result.entries.where((entry) => entry.type == 'break');
    expect(breaks.where((entry) => entry.id == 'break-lunch'), hasLength(1));
    expect(breaks.where((entry) => entry.title == 'Recovery break'), isEmpty);
    expect(
      result.entries.where((entry) => entry.type == 'movement'),
      isNotEmpty,
    );
  });

  test(
    'office days add adjustable Work commute blocks around the work window',
    () {
      final result = DayPlannerService.buildPlan(
        tasks: const <Task>[],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: DateTime(2024, 1, 2),
        dayContext: _officeDayContext,
        workdayStartMinutes: 9 * 60,
        workdayEndMinutes: 17 * 60,
      );

      final commute = result.entries
          .where((entry) => entry.title == 'Commute')
          .toList();
      expect(commute, hasLength(2));
      expect(
        commute.map((entry) => entry.id),
        containsAll(<String>[
          'commute-before-2024-1-2',
          'commute-after-2024-1-2',
        ]),
      );
      expect(commute.every((entry) => entry.type == 'task'), isTrue);
      expect(commute.every((entry) => entry.task?.category == 'Work'), isTrue);
      expect(
        commute
            .firstWhere((entry) => entry.id.startsWith('commute-before'))
            .start,
        DateTime(2024, 1, 2, 8),
      );
      expect(
        commute.firstWhere((entry) => entry.id.startsWith('commute-after')).end,
        DateTime(2024, 1, 2, 18),
      );
    },
  );

  test('home days do not add commute blocks', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );

    expect(result.entries.where((entry) => entry.title == 'Commute'), isEmpty);
  });

  test('WFH days add a Work Switch off block after the work window', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );

    final switchOff = result.entries.firstWhere(
      (entry) => entry.title == 'Switch off',
    );
    expect(switchOff.id, 'switch-off-2024-1-2');
    expect(switchOff.type, 'task');
    expect(switchOff.task?.category, 'Work');
    expect(switchOff.start, DateTime(2024, 1, 2, 17));
    expect(switchOff.end, DateTime(2024, 1, 2, 17, 15));
  });

  test('office walking breaks are distributed through the workday', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );
    final walkingBreaks =
        result.entries
            .where((entry) => entry.type == 'movement' && !entry.isConcurrent)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    for (var index = 1; index < walkingBreaks.length; index++) {
      expect(
        walkingBreaks[index].start
            .difference(walkingBreaks[index - 1].start)
            .inMinutes,
        greaterThanOrEqualTo(60),
      );
    }
  });

  test('office break coverage spans the required workday periods', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );
    final breaks = result.entries.where(
      (entry) => entry.type == 'break' || entry.type == 'movement',
    );

    bool hasBreakBetween(DateTime start, DateTime end) {
      return breaks.any(
        (entry) => entry.start.isBefore(end) && entry.end.isAfter(start),
      );
    }

    expect(
      hasBreakBetween(DateTime(2024, 1, 2, 9), DateTime(2024, 1, 2, 12)),
      isTrue,
    );
    expect(
      hasBreakBetween(DateTime(2024, 1, 2, 12), DateTime(2024, 1, 2, 14)),
      isTrue,
    );
    expect(
      hasBreakBetween(DateTime(2024, 1, 2, 14), DateTime(2024, 1, 2, 17)),
      isTrue,
    );
  });

  test('a busy WFH day still gets a break in the first 3 hours, lunch, and a '
      'break in the last 3 hours, each at least an hour apart and never in '
      'the final hour', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        for (var index = 0; index < 8; index++)
          Task(
            task: 'Task $index',
            priority: 'high',
            dueDate: '2024-01-02',
            nextSessionEffortMinutes: 60,
          ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );

    final breaks =
        result.entries.where((entry) => entry.type == 'break').toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    bool hasBreakBetween(DateTime start, DateTime end) {
      return breaks.any(
        (entry) => entry.start.isBefore(end) && entry.end.isAfter(start),
      );
    }

    expect(
      hasBreakBetween(DateTime(2024, 1, 2, 9), DateTime(2024, 1, 2, 12)),
      isTrue,
    );
    expect(
      hasBreakBetween(DateTime(2024, 1, 2, 12), DateTime(2024, 1, 2, 14)),
      isTrue,
    );
    expect(
      hasBreakBetween(DateTime(2024, 1, 2, 14), DateTime(2024, 1, 2, 16)),
      isTrue,
    );
    final lunch = breaks.firstWhere((entry) => entry.id == 'break-lunch');
    expect(lunch.end.difference(lunch.start).inMinutes, 30);
    for (final entry in breaks.where((entry) => entry.id != 'break-lunch')) {
      expect(entry.end.difference(entry.start).inMinutes, 15);
    }
    expect(
      breaks.every((entry) => !entry.end.isAfter(DateTime(2024, 1, 2, 16))),
      isTrue,
    );
    for (var index = 1; index < breaks.length; index++) {
      expect(
        breaks[index].start.difference(breaks[index - 1].end).inMinutes,
        greaterThanOrEqualTo(60),
      );
    }
  });

  test('WFH break coverage preserves Lunch and required movement', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Home project',
          priority: 'high',
          dueDate: '2024-01-02',
          effortMinutes: 240,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 14 * 60,
    );

    expect(
      result.entries.where((entry) => entry.id == 'break-lunch'),
      hasLength(1),
    );
    expect(
      result.entries.where(
        (entry) =>
            entry.type == 'movement' &&
            entry.title.toLowerCase().contains('walk'),
      ),
      isNotEmpty,
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

  test('buildPlan can add concurrent movement on WFH days', () {
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
      result.entries.where(
        (entry) => entry.type == 'movement' && entry.isConcurrent,
      ),
      isNotEmpty,
    );
  });

  test('buildPlan places optional mobility when capacity remains', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );

    expect(
      result.entries.any((entry) => entry.title == 'Mobility session'),
      isTrue,
    );
    final mobility = result.entries.firstWhere(
      (entry) => entry.title == 'Mobility session',
    );
    expect(!mobility.start.isBefore(DateTime(2024, 1, 2, 17)), isTrue);
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
            entry.title == 'Mobility session' ||
            entry.title == 'Switch off' ||
            !entry.start.isBefore(DateTime(2024, 1, 2, 9)) &&
                !entry.end.isAfter(DateTime(2024, 1, 2, 17)),
      ),
      isTrue,
    );
  });

  test('buildPlan leaves walking breaks to office days', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
    );
    final movement = result.entries
        .where(
          (entry) =>
              entry.type == 'movement' &&
              !entry.isConcurrent &&
              entry.title.toLowerCase().contains('walk'),
        )
        .toList();
    expect(movement, isNotEmpty);
  });

  test('buildPlan pairs movement with a preferred WFH work event', () {
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
      result.entries.where(
        (entry) => entry.type == 'movement' && entry.isConcurrent,
      ),
      isNotEmpty,
    );
  });

  test('buildPlan lets WFH movement run concurrently with planned tasks', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Home focus task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 60,
        ),
      ],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _homeDayContext,
    );
    final movements = result.entries.where((entry) => entry.type == 'movement');
    final tasks = result.entries.where((entry) => entry.type == 'task');

    expect(movements, isNotEmpty);
    expect(tasks, isNotEmpty);
    // Standing/walking isn't "planning work", so it's allowed to overlap
    // real task blocks instead of reserving its own exclusive time.
    expect(
      movements.any(
        (movement) => tasks.any(
          (task) =>
              movement.isConcurrent &&
              movement.start.isBefore(task.end) &&
              movement.end.isAfter(task.start),
        ),
      ),
      isTrue,
    );
  });

  test('buildPlan keeps the opening Focus Time visible on a light WFH day '
      'instead of letting movement consume it exclusively', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'annual-leave',
          subject: 'Annual leave',
          start: DateTime(2024, 1, 2, 12),
          end: DateTime(2024, 1, 2, 17),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
      dayContext: const DayContext(
        gymMorning: true,
        workLocation: WorkLocation.home,
        eveningAvailable: false,
      ),
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 13 * 60,
    );

    final openingFocus = result.entries.where(
      (entry) =>
          entry.type == 'focus' && entry.start == DateTime(2024, 1, 2, 9),
    );
    expect(openingFocus, isNotEmpty);
    // Movement should overlay the opening focus time concurrently rather
    // than claiming it exclusively and pushing the placeholder out.
    final firstMovement = result.entries.firstWhere(
      (entry) => entry.type == 'movement',
    );
    expect(firstMovement.start, DateTime(2024, 1, 2, 9));
    expect(firstMovement.isConcurrent, isTrue);
  });

  test('buildPlan keeps Focus Time separate from planning commitments', () {
    final result = DayPlannerService.buildPlan(
      tasks: [
        Task(
          task: 'Planning task',
          priority: 'high',
          dueDate: '2024-01-02',
          nextSessionEffortMinutes: 30,
        ),
      ],
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'work-meeting',
          subject: 'Work meeting',
          start: DateTime(2024, 1, 2, 11),
          end: DateTime(2024, 1, 2, 12),
          isAllDay: false,
          calendarSource: 'work',
        ),
      ],
      day: DateTime(2024, 1, 2),
    );
    final focusEntries = result.entries
        .where((entry) => entry.type == 'focus')
        .toList();
    final commitments = result.entries.where((entry) => entry.type != 'focus');

    for (final focus in focusEntries) {
      for (final commitment in commitments) {
        expect(
          !focus.start.isBefore(commitment.end) ||
              !focus.end.isAfter(commitment.start),
          isTrue,
        );
      }
    }
    for (var index = 0; index < focusEntries.length; index++) {
      for (
        var otherIndex = index + 1;
        otherIndex < focusEntries.length;
        otherIndex++
      ) {
        final first = focusEntries[index];
        final second = focusEntries[otherIndex];
        expect(
          !first.start.isBefore(second.end) || !first.end.isAfter(second.start),
          isTrue,
        );
      }
    }
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

  test('buildPlan starts the work window with focus time', () {
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: DateTime(2024, 1, 2),
      dayContext: _officeDayContext,
      workdayStartMinutes: 9 * 60,
      workdayEndMinutes: 17 * 60,
    );
    final openingFocus = result.entries
        .where(
          (entry) =>
              entry.type == 'focus' && entry.start == DateTime(2024, 1, 2, 9),
        )
        .toList();

    expect(openingFocus, hasLength(1));
    expect(
      openingFocus.single.end.difference(openingFocus.single.start).inMinutes,
      60,
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

  test('buildPlan keeps required movement in a compressed WFH window', () {
    final day = DateTime(2024, 1, 2);
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: day,
      dayContext: _homeDayContext,
      workdayStartMinutes: 10 * 60,
      workdayEndMinutes: 14 * 60,
    );

    final movement = result.entries.where(
      (entry) =>
          entry.type == 'movement' &&
          (entry.title.contains('Walk') || entry.title.contains('Stand')),
    );
    expect(movement, isNotEmpty);
    expect(
      movement.every(
        (entry) =>
            !entry.start.isBefore(DateTime(2024, 1, 2, 10)) &&
            !entry.end.isAfter(DateTime(2024, 1, 2, 14)),
      ),
      isTrue,
    );
  });

  test('buildPlan keeps required movement in an extended office window', () {
    final day = DateTime(2024, 1, 2);
    final result = DayPlannerService.buildPlan(
      tasks: const <Task>[],
      calendarEvents: const <OutlookCalendarEvent>[],
      day: day,
      dayContext: _officeDayContext,
      workdayStartMinutes: 7 * 60,
      workdayEndMinutes: 19 * 60,
    );

    final movement = result.entries.where((entry) => entry.type == 'movement');
    expect(movement, isNotEmpty);
    expect(
      movement.every(
        (entry) =>
            !entry.start.isBefore(DateTime(2024, 1, 2, 7)) &&
            !entry.end.isAfter(DateTime(2024, 1, 2, 19)),
      ),
      isTrue,
    );
  });

  test(
    'buildPlan uses custom enabledActivityNames for WFH movement titles',
    () {
      final day = DateTime(2024, 1, 2);
      final result = DayPlannerService.buildPlan(
        tasks: const <Task>[],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: day,
        dayContext: _homeDayContext,
        enabledActivityNames: const ['Treadmill walk', 'Desk stretch'],
      );

      final movementTitles = result.entries
          .where((entry) => entry.type == 'movement')
          .map((entry) => entry.title)
          .toSet();

      expect(movementTitles, containsAll(['Treadmill walk', 'Desk stretch']));
    },
  );

  test(
    'buildPlan uses custom enabledActivityNames for Office movement titles',
    () {
      final day = DateTime(2024, 1, 2);
      final result = DayPlannerService.buildPlan(
        tasks: const <Task>[],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: day,
        dayContext: _officeDayContext,
        enabledActivityNames: const ['Stair climb', 'Office stretch'],
      );

      final movementTitles = result.entries
          .where((entry) => entry.type == 'movement')
          .map((entry) => entry.title)
          .toSet();

      expect(movementTitles, containsAll(['Stair climb', 'Office stretch']));
    },
  );

  test(
    'buildPlan disables movement entries when enabledActivityNames is empty',
    () {
      final day = DateTime(2024, 1, 2);
      final result = DayPlannerService.buildPlan(
        tasks: const <Task>[],
        calendarEvents: const <OutlookCalendarEvent>[],
        day: day,
        dayContext: _homeDayContext,
        enabledActivityNames: const <String>[],
      );

      final scheduledMovementEntries = result.entries.where(
        (entry) =>
            entry.id.startsWith('movement-home') ||
            entry.id.startsWith('movement-office'),
      );
      expect(scheduledMovementEntries, isEmpty);
    },
  );
}
