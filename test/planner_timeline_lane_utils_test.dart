import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/widgets/day_planner_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single interval uses the leftmost lane without category lock', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    final entry = DayPlannerEntry(
      id: 'solo',
      title: 'Solo task',
      type: 'task',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );

    final lanes = DayPlannerSection.assignLeftmostFreeLanes([entry]);
    expect(lanes, hasLength(1));
    expect(lanes.single.lane, 0);
  });

  test('overlapping intervals use different lanes, not the same lane', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    final a = DayPlannerEntry(
      id: 'task-a',
      title: 'Task A',
      type: 'task',
      start: start,
      end: start.add(const Duration(minutes: 60)),
    );
    final b = DayPlannerEntry(
      id: 'task-b',
      title: 'Task B',
      type: 'task',
      start: start.add(const Duration(minutes: 30)),
      end: start.add(const Duration(minutes: 90)),
    );

    final lanes = DayPlannerSection.assignLeftmostFreeLanes([a, b]);
    final assigned = {for (final item in lanes) item.entry.id: item.lane};
    expect(assigned['task-a'], 0);
    expect(assigned['task-b'], 1);
  });

  test('excluded Home calendar events use the rightmost concurrent lane', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    final includedWork = DayPlannerEntry(
      id: 'work-task',
      title: 'Work task',
      type: 'task',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );
    final excludedHome = DayPlannerEntry(
      id: 'home-calendar',
      title: 'Home event',
      type: 'calendar',
      subtitle: 'Home calendar',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );

    final lanes = DayPlannerSection.assignLeftmostFreeLanes([
      includedWork,
      excludedHome,
    ], lanePriority: (entry) => entry.id == 'home-calendar' ? 7 : 1);
    final assigned = {for (final item in lanes) item.entry.id: item.lane};

    expect(assigned['work-task'], 0);
    expect(assigned['home-calendar'], 1);
  });

  test(
    'timeline columns use one full-width column when events are isolated',
    () {
      final start = DateTime(2024, 1, 2, 9, 0);
      final entry = DayPlannerEntry(
        id: 'solo',
        title: 'Solo task',
        type: 'task',
        start: start,
        end: start.add(const Duration(minutes: 30)),
      );

      final columns = DayPlannerSection.assignExpandedTimelineColumns([entry]);

      expect(columns.single.lane, 0);
      expect(columns.single.columnCount, 1);
    },
  );

  test('timeline columns split concurrent events evenly', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    DayPlannerEntry entry(String id) {
      return DayPlannerEntry(
        id: id,
        title: id,
        type: 'task',
        start: start,
        end: start.add(const Duration(minutes: 30)),
      );
    }

    final columns = DayPlannerSection.assignExpandedTimelineColumns([
      entry('first'),
      entry('second'),
    ]);

    expect(columns, hasLength(2));
    expect(columns.every((item) => item.columnCount == 2), isTrue);
    expect(columns.map((item) => item.lane).toSet(), {0, 1});
  });

  test('concurrent categories follow the requested lane preference order', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    DayPlannerEntry entry(String id, String type, {String? subtitle}) {
      return DayPlannerEntry(
        id: id,
        title: id,
        type: type,
        subtitle: subtitle,
        start: start,
        end: start.add(const Duration(minutes: 30)),
      );
    }

    final entries = [
      entry('break', 'break'),
      entry('movement', 'movement'),
      entry('personal', 'personal'),
      entry('home', 'calendar', subtitle: 'Home appointment'),
      entry('focus', 'focus'),
      entry('work', 'calendar', subtitle: 'Work meeting'),
    ];

    final lanes = DayPlannerSection.assignLeftmostFreeLanes(entries);
    final assigned = {for (final item in lanes) item.entry.id: item.lane};

    expect(assigned['work'], 1);
    expect(assigned['focus'], 0);
    expect(assigned['home'], 2);
    expect(assigned['personal'], 3);
    expect(assigned['movement'], 5);
    expect(assigned['break'], 4);
  });

  test(
    'category preference applies when concurrent entries start at different times',
    () {
      final start = DateTime(2024, 1, 2, 9, 0);
      final home = DayPlannerEntry(
        id: 'home',
        title: 'Home',
        type: 'calendar',
        subtitle: 'Home appointment',
        start: start,
        end: start.add(const Duration(minutes: 60)),
      );
      final work = DayPlannerEntry(
        id: 'work',
        title: 'Work',
        type: 'calendar',
        subtitle: 'Work meeting',
        start: start.add(const Duration(minutes: 15)),
        end: start.add(const Duration(minutes: 45)),
      );

      final lanes = DayPlannerSection.assignLeftmostFreeLanes([home, work]);
      final assigned = {for (final item in lanes) item.entry.id: item.lane};

      expect(assigned['work'], 0);
      expect(assigned['home'], 1);
    },
  );

  test('focus sessions and focus breaks take the Work lane preference', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    final home = DayPlannerEntry(
      id: 'home',
      title: 'Home',
      type: 'calendar',
      subtitle: 'Home appointment',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );
    final focus = DayPlannerEntry(
      id: 'focus',
      title: 'Focus Time',
      type: 'focus',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );
    final focusBreak = DayPlannerEntry(
      id: 'focus-break',
      title: 'Recovery break',
      type: 'break',
      subtitle: 'Recovery after 60 min focus',
      start: start,
      end: start.add(const Duration(minutes: 15)),
    );

    final lanes = DayPlannerSection.assignLeftmostFreeLanes([
      home,
      focusBreak,
      focus,
    ]);
    final assigned = {for (final item in lanes) item.entry.id: item.lane};

    expect(assigned['focus-break'], 0);
    expect(assigned['focus'], 1);
    expect(assigned['home'], 2);
  });

  test('zero-duration markers do not reserve a real interval lane', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    final realEntry = DayPlannerEntry(
      id: 'real',
      title: 'Real task',
      type: 'task',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );
    final marker = DayPlannerEntry(
      id: 'marker',
      title: 'Marker',
      type: 'calendar',
      start: start,
      end: start,
      isZeroDuration: true,
    );

    final lanes = DayPlannerSection.assignLeftmostFreeLanes([
      realEntry,
      marker,
    ]);
    expect(lanes, hasLength(1));
    expect(lanes.single.lane, 0);
  });

  test(
    'zero-duration markers always use the leftmost slot for their start time',
    () {
      final start = DateTime(2024, 1, 2, 9, 0);
      final firstAtStart = DayPlannerEntry(
        id: 'first-at-start',
        title: 'First',
        type: 'calendar',
        start: start,
        end: start,
        isZeroDuration: true,
      );
      final secondAtStart = DayPlannerEntry(
        id: 'second-at-start',
        title: 'Second',
        type: 'calendar',
        start: start,
        end: start,
        isZeroDuration: true,
      );
      final laterMarker = DayPlannerEntry(
        id: 'later-marker',
        title: 'Later',
        type: 'calendar',
        start: start.add(const Duration(minutes: 15)),
        end: start.add(const Duration(minutes: 15)),
        isZeroDuration: true,
      );

      final slots = DayPlannerSection.assignZeroDurationMarkerSlots([
        firstAtStart,
        secondAtStart,
        laterMarker,
      ]);

      final assigned = {for (final item in slots) item.entry.id: item.slot};

      expect(assigned['first-at-start'], 0);
      expect(assigned['second-at-start'], 1);
      expect(assigned['later-marker'], 0);
    },
  );

  test('simultaneous zero-duration markers follow category preference', () {
    final start = DateTime(2024, 1, 2, 9, 0);
    DayPlannerEntry marker(String id, String subtitle) {
      return DayPlannerEntry(
        id: id,
        title: id,
        type: 'calendar',
        subtitle: subtitle,
        start: start,
        end: start,
        isZeroDuration: true,
      );
    }

    final slots = DayPlannerSection.assignZeroDurationMarkerSlots([
      marker('home', 'Home appointment'),
      marker('work', 'Work meeting'),
    ]);
    final assigned = {for (final item in slots) item.entry.id: item.slot};

    expect(assigned['work'], 0);
    expect(assigned['home'], 1);
  });
}
