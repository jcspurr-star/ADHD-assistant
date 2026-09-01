import '../models/activity_recommendation.dart';
import '../models/task.dart';
import 'movement_recommendation_service.dart';
import 'one_drive_sync_service.dart';
import 'planner_break_policy.dart';
import 'planner_execution_service.dart';

class DayPlannerEntry {
  DayPlannerEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    required this.end,
    this.subtitle,
    this.task,
    this.relatedTaskIds = const <String>[],
    this.isAllDay = false,
    this.isConcurrent = false,
    this.isLocked = false,
    this.executionState = ExecutionState.pending,
    this.category = PlannerEventCategory.planned,
    this.isZeroDuration = false,
    this.labels = const <String>[],
  });

  /// Serializes this entry for persistence as part of a frozen planner
  /// snapshot. The linked [task] is NOT stored — it's re-resolved by id from
  /// the live task list when rehydrating via [fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'subtitle': subtitle,
    'relatedTaskIds': relatedTaskIds,
    'isAllDay': isAllDay,
    'isConcurrent': isConcurrent,
    'category': category.name,
    'isZeroDuration': isZeroDuration,
    'labels': labels,
  };

  factory DayPlannerEntry.fromJson(
    Map<String, dynamic> json, {
    Task? Function(String id)? resolveTask,
  }) {
    final relatedTaskIds =
        (json['relatedTaskIds'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final type = json['type']?.toString() ?? '';
    final task =
        resolveTask != null &&
            relatedTaskIds.isNotEmpty &&
            (type == 'task' || type == 'admin')
        ? resolveTask(relatedTaskIds.first)
        : null;
    return DayPlannerEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: type,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      subtitle: json['subtitle']?.toString(),
      task: task,
      relatedTaskIds: relatedTaskIds,
      isAllDay: json['isAllDay'] == true,
      isConcurrent: json['isConcurrent'] == true,
      category: PlannerEventCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => PlannerEventCategory.planned,
      ),
      isZeroDuration: json['isZeroDuration'] == true,
      labels:
          (json['labels'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
    );
  }

  final String id;
  final String title;
  final String type;
  final DateTime start;
  final DateTime end;
  final String? subtitle;
  final Task? task;
  final List<String> relatedTaskIds;
  final bool isAllDay;
  final bool isConcurrent;
  // True when the user manually pinned this entry's time; the planner won't move it.
  final bool isLocked;
  final ExecutionState executionState;
  final PlannerEventCategory category;
  final bool isZeroDuration;
  final List<String> labels;

  DayPlannerEntry copyWith({
    String? title,
    String? subtitle,
    String? type,
    Task? task,
    bool clearTask = false,
    List<String>? relatedTaskIds,
    DateTime? start,
    DateTime? end,
    bool? isLocked,
    ExecutionState? executionState,
    PlannerEventCategory? category,
    bool? isZeroDuration,
    List<String>? labels,
  }) {
    return DayPlannerEntry(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      start: start ?? this.start,
      end: end ?? this.end,
      subtitle: subtitle ?? this.subtitle,
      task: clearTask ? null : (task ?? this.task),
      relatedTaskIds: relatedTaskIds ?? this.relatedTaskIds,
      isAllDay: isAllDay,
      isConcurrent: isConcurrent,
      isLocked: isLocked ?? this.isLocked,
      executionState: executionState ?? this.executionState,
      category: category ?? this.category,
      isZeroDuration: isZeroDuration ?? this.isZeroDuration,
      labels: labels ?? this.labels,
    );
  }
}

/// A user-provided manual override for a planner entry, keyed by entry id:
/// its time/lock state, and/or which activity (task or custom name) it is.
class PlannerEntryOverride {
  const PlannerEntryOverride({
    this.startMinutes,
    this.endMinutes,
    this.locked = false,
    this.taskId,
    this.customTitle,
  });

  /// Minutes since midnight for the overridden start time, or null to keep the planned start.
  final int? startMinutes;

  /// Minutes since midnight for the overridden end time, or null to keep the planned end.
  final int? endMinutes;
  final bool locked;

  /// Reassigns this slot to a specific task from the task list, if set.
  final String? taskId;

  /// Reassigns this slot to a free-typed/preset activity name, if set (and
  /// [taskId] isn't). Mutually exclusive with [taskId].
  final String? customTitle;
}

class PersonalPlannerBlock {
  const PersonalPlannerBlock({
    required this.id,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String id;
  final String title;
  final int startMinutes;
  final int endMinutes;
}

class _DailyCapacity {
  const _DailyCapacity({
    required this.workWindowMinutes,
    required this.fixedEventMinutes,
    required this.lunchMinutes,
    required this.requiredBreakMinutes,
    required this.movementMinimumMinutes,
    required this.reserveMinutes,
  });

  final int workWindowMinutes;
  final int fixedEventMinutes;
  final int lunchMinutes;
  final int requiredBreakMinutes;
  final int movementMinimumMinutes;
  final int reserveMinutes;

  int get availableMinutes =>
      (workWindowMinutes -
              fixedEventMinutes -
              lunchMinutes -
              requiredBreakMinutes -
              movementMinimumMinutes -
              reserveMinutes)
          .clamp(0, workWindowMinutes);
}

class _PrioritizedTask {
  const _PrioritizedTask({required this.task, required this.score});

  final Task task;
  final double score;
}

class _TaskSession {
  const _TaskSession({
    required this.tasks,
    required this.duration,
    this.sessionIndex = 1,
    this.sessionCount = 1,
    this.isAdmin = false,
    this.isPulledForward = false,
  });

  final List<Task> tasks;
  final Duration duration;
  final int sessionIndex;
  final int sessionCount;
  final bool isAdmin;
  // True when this task isn't due yet but was pulled forward to fill spare capacity.
  final bool isPulledForward;

  Task get primaryTask => tasks.first;
}

class DayPlannerResult {
  DayPlannerResult({
    required this.entries,
    required this.summary,
    this.recommendations = const <ActivityRecommendation>[],
    this.rolloverTasks = const <Task>[],
  });

  final List<DayPlannerEntry> entries;
  final String summary;
  final List<ActivityRecommendation> recommendations;
  final List<Task> rolloverTasks;
}

class DayPlannerService {
  static const Duration _minimumEventDuration = Duration(minutes: 5);

  static bool _occupiesPlanningTime(DayPlannerEntry entry) {
    return !entry.isAllDay &&
        entry.type != 'buffer' &&
        (entry.category != PlannerEventCategory.informational ||
            _isWorkCalendarEntry(entry)) &&
        !(entry.type == 'calendar' && entry.isZeroDuration);
  }

  static bool _isWorkCalendarEntry(DayPlannerEntry entry) {
    return entry.type == 'calendar' &&
        entry.subtitle?.toLowerCase().contains('work calendar') == true;
  }

  static DateTime? _parseTaskDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime? _planningDateForTask(Task task) {
    return _parseTaskDate(task.doDate) ??
        _parseTaskDate(task.dueDate) ??
        _firstPlannedIncompleteSubtaskDate(task);
  }

  static bool _isTaskEligibleForDay(Task task, DateTime day) {
    if (task.done == true) {
      return false;
    }
    if (task.waitingOnOthers) {
      return false;
    }

    final targetDay = DateTime(day.year, day.month, day.day);
    if (_isBlockedAsOverdue(task, targetDay)) {
      return false;
    }

    final dueDate = _parseTaskDate(task.dueDate);
    if (task.absolutePriority && dueDate != null) {
      final normalizedDueDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
      );
      return !normalizedDueDate.isBefore(targetDay);
    }

    final doDate = _parseTaskDate(task.doDate);
    if (doDate != null) {
      final normalizedDoDate = DateTime(doDate.year, doDate.month, doDate.day);
      return !normalizedDoDate.isAfter(targetDay);
    }

    for (final subtask in task.subtasks) {
      if (subtask.done == true) continue;
      final subtaskDate = _parseTaskDate(subtask.doDate);
      if (subtaskDate == null) continue;
      final normalizedSubtaskDate = DateTime(
        subtaskDate.year,
        subtaskDate.month,
        subtaskDate.day,
      );
      if (!normalizedSubtaskDate.isAfter(targetDay)) {
        return true;
      }
    }

    if (dueDate == null) return false;
    final normalizedDueDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );
    // Due-date-only fallback (no explicit do-date): only due exactly on this
    // day counts. A due date before this day is overdue, not "for" this
    // day — it no longer forces itself into every subsequent day's plan; it
    // may still get pulled forward opportunistically via
    // `_prioritizeFutureTasks` if there's spare capacity.
    return normalizedDueDate.isAtSameMomentAs(targetDay);
  }

  // Tasks with `excludeWhenOverdue` set stop appearing in the planner
  // entirely once their due date passes without completion — unlike regular
  // tasks, they don't fall back to opportunistic backlog carry-over either.
  static bool _isBlockedAsOverdue(Task task, DateTime targetDay) {
    if (!task.excludeWhenOverdue) return false;
    final dueDate = _parseTaskDate(task.dueDate);
    if (dueDate == null) return false;
    final normalizedDueDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );
    return normalizedDueDate.isBefore(targetDay);
  }

  static DateTime? _firstPlannedIncompleteSubtaskDate(Task task) {
    DateTime? earliest;
    for (final subtask in task.subtasks) {
      if (subtask.done == true) {
        continue;
      }

      final date = _parseTaskDate(subtask.doDate);
      if (date == null) {
        continue;
      }

      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }
    return earliest;
  }

  static DayPlannerResult buildPlan({
    required List<Task> tasks,
    required List<OutlookCalendarEvent> calendarEvents,
    required DateTime day,
    DayContext? dayContext,
    WeeklyActivityTotals weeklyTotals = const WeeklyActivityTotals(),
    bool gymCompletedToday = false,
    int daysSinceLastMobility = 0,
    int workdayStartMinutes = 9 * 60,
    int workdayEndMinutes = 17 * 60,
    Set<String> preferredConcurrentEntryIds = const <String>{},
    Set<String> excludedConcurrentEntryIds = const <String>{},
    Set<String> nonBlockingCalendarEventIds = const <String>{},
    Set<String> includedCalendarEventIds = const <String>{},
    Map<String, PlannerEntryOverride> entryOverrides =
        const <String, PlannerEntryOverride>{},
    Set<String> excludedPlannerEntryIds = const <String>{},
    DateTime? planningStart,
    List<PersonalPlannerBlock> personalBlocks = const <PersonalPlannerBlock>[],
    Map<String, ExecutionState> executionStates =
        const <String, ExecutionState>{},
    TimeGrid timeGrid = TimeGrid.fifteenMinutes,
    bool isHoliday = false,
    // See `_placeMovementEvents` — null falls back to the original built-in
    // WFH/office movement names, an explicit empty list disables movement
    // for the day entirely.
    List<String>? enabledActivityNames,
  }) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    // A manually-marked holiday weekday is scheduled exactly like a weekend:
    // calendar events only, no tasks/movement/breaks.
    final isNonWorkingDay = isWeekend || isHoliday;
    final normalizedStart = workdayStartMinutes.clamp(0, 23 * 60 + 59);
    final normalizedEnd = workdayEndMinutes.clamp(1, 24 * 60);
    final configuredDayStart = _dateAtMinutes(day, normalizedStart);
    final dayStart =
        planningStart == null ||
            planningStart.isBefore(configuredDayStart) ||
            planningStart.day != day.day
        ? configuredDayStart
        : planningStart;
    final dayEnd = _dateAtMinutes(day, normalizedEnd);
    final displayStart = DateTime(day.year, day.month, day.day);
    final displayEnd = displayStart.add(const Duration(days: 1));
    if (!dayEnd.isAfter(dayStart)) {
      return DayPlannerResult(
        entries: const <DayPlannerEntry>[],
        summary: 'Set an end time after the start time.',
      );
    }
    final entries = <DayPlannerEntry>[];

    for (final block in personalBlocks) {
      final start = _dateAtMinutes(day, block.startMinutes);
      final end = _dateAtMinutes(day, block.endMinutes);
      if (!end.isAfter(start)) continue;
      entries.add(
        DayPlannerEntry(
          id: block.id,
          title: block.title,
          type: 'personal',
          start: start,
          end: end,
          subtitle: 'Personal block',
          isLocked: true,
          category: PlannerEventCategory.fixed,
        ),
      );
    }

    final todaysEvents =
        calendarEvents.where((event) {
          final start = event.start?.toLocal();
          if (start == null) return false;
          final rawEnd = event.end?.toLocal();
          final end = _normalizedEventEnd(start, rawEnd, event.isAllDay);
          final eventDay = DateTime(start.year, start.month, start.day);
          final targetDay = DateTime(day.year, day.month, day.day);
          return eventDay == targetDay ||
              (start.isBefore(displayEnd) && end.isAfter(displayStart));
        }).toList()..sort((a, b) {
          final aStart = a.start?.toLocal();
          final bStart = b.start?.toLocal();
          if (aStart == null || bStart == null) return 0;
          return aStart.compareTo(bStart);
        });

    DateTime cursor = dayStart;

    for (final event in todaysEvents) {
      final eventStart = event.start?.toLocal();
      if (eventStart == null) continue;
      final eventEnd = _normalizedEventEnd(
        eventStart,
        event.end?.toLocal(),
        event.isAllDay,
      );

      var adjustedStart = eventStart.isBefore(displayStart)
          ? displayStart
          : eventStart;
      var adjustedEnd = eventEnd.isAfter(displayEnd) ? displayEnd : eventEnd;
      final isZeroDuration =
          !event.isAllDay &&
          event.end != null &&
          !event.end!.toLocal().isAfter(event.start!.toLocal());
      if (event.calendarSource == 'work' &&
          !event.isAllDay &&
          !isZeroDuration &&
          adjustedEnd.isAfter(adjustedStart)) {
        final durationMinutes = adjustedEnd.difference(adjustedStart).inMinutes;
        final roundedMinutes = ((durationMinutes + 14) ~/ 15) * 15;
        adjustedEnd = adjustedStart.add(Duration(minutes: roundedMinutes));
        if (adjustedEnd.isAfter(displayEnd)) adjustedEnd = displayEnd;
      }

      if (!event.isAllDay && !adjustedEnd.isAfter(adjustedStart)) {
        final minimumEnd = adjustedStart.add(_minimumEventDuration);
        if (minimumEnd.isAfter(displayEnd)) {
          if (adjustedStart.isAfter(displayEnd)) {
            continue;
          }
          if (adjustedStart.isAtSameMomentAs(displayEnd)) {
            adjustedStart = displayEnd.subtract(_minimumEventDuration);
          }
          adjustedEnd = dayEnd;
        } else {
          adjustedEnd = minimumEnd;
        }
      }

      if (!adjustedStart.isAfter(adjustedEnd)) {
        final isHomeCalendar = event.calendarSource != 'work';
        final hasPersonalLabel = event.labels.any(
          (label) => label.trim().toLowerCase() == 'personal',
        );
        final isIncludedHomeEvent =
            !isHomeCalendar ||
            (!nonBlockingCalendarEventIds.contains('calendar-${event.id}') &&
                (hasPersonalLabel ||
                    includedCalendarEventIds.contains('calendar-${event.id}')));
        entries.add(
          DayPlannerEntry(
            id: 'calendar-${event.id}',
            title: event.subject.trim().isEmpty
                ? 'Calendar event'
                : event.subject,
            type: 'calendar',
            start: adjustedStart,
            end: adjustedEnd,
            subtitle: event.calendarSource == 'work'
                ? 'Work calendar'
                : 'Home calendar',
            isAllDay: event.isAllDay,
            labels: event.labels,
            category: event.isAllDay
                ? PlannerEventCategory.informational
                : !isIncludedHomeEvent
                ? PlannerEventCategory.informational
                : PlannerEventCategory.fixed,
            isZeroDuration: isZeroDuration,
          ),
        );
      }

      cursor = adjustedEnd.isAfter(cursor) ? adjustedEnd : cursor;
      if (cursor.isAfter(dayEnd)) cursor = dayEnd;
    }

    if (!isNonWorkingDay) {
      final lunchEntry = excludedPlannerEntryIds.contains('break-lunch')
          ? null
          : _placeLunch(entries, dayStart, dayEnd);
      if (lunchEntry != null) entries.add(lunchEntry);
    }

    if (isNonWorkingDay) {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        entries[index] = entry.copyWith(
          executionState: executionStates[entry.id] ?? ExecutionState.pending,
        );
      }
      entries.sort((a, b) => a.start.compareTo(b.start));
      final label = isHoliday && !isWeekend ? 'Holiday' : 'Weekend';
      return DayPlannerResult(
        entries: entries,
        summary: entries.isEmpty
            ? '$label: no activities planned.'
            : '$label: calendar items only.',
        rolloverTasks: const <Task>[],
      );
    }

    final movementEntries = <DayPlannerEntry>[];

    final isOfficeDay = dayContext?.workLocation == WorkLocation.office;
    final prioritizedTasks = _prioritizeTasks(tasks, day);
    final actionableTasks = prioritizedTasks.map((item) => item.task).toList();

    if (isOfficeDay) {
      // Commute placement always anchors to the CONFIGURED work-day start,
      // not the replan-reanchored `dayStart` (which shifts to "now" when
      // replanning from now) — otherwise replanning mid-morning placed a
      // spurious "commute before" block in the hour right before "now"
      // instead of before the actual start of the work window.
      entries.addAll(_buildCommuteEntries(day, configuredDayStart, dayEnd));
    } else if (dayContext?.workLocation == WorkLocation.home) {
      final switchOffEntry = _buildSwitchOffEntry(day, dayEnd);
      if (switchOffEntry != null) entries.add(switchOffEntry);
    }

    // Every work day opens with an hour of Focus Time unless a calendar event
    // blocks it; this is reserved before tasks so it can't be claimed by them.
    final openingFocusEntry = _buildOpeningFocusEntry(
      entries,
      dayStart,
      dayEnd,
    );
    if (openingFocusEntry != null) entries.add(openingFocusEntry);

    // Insert a recovery break for the reserved opening hour now, before tasks
    // are scheduled, so tasks naturally space themselves around it instead of
    // packing solid and forcing several breaks into whatever's left later.
    final earlyRecoveryBreaks = isOfficeDay
        ? const <DayPlannerEntry>[]
        : _insertCumulativeFocusBreaks(
            entries,
            dayStart,
            dayEnd,
            excludedPlannerEntryIds: excludedPlannerEntryIds,
          );
    entries.addAll(earlyRecoveryBreaks);

    // Guarantee at least one break in the first 3 hours and one in the last
    // 3 hours before tasks can pack the day solid and crowd them out.
    if (dayContext != null) {
      entries.addAll(
        _ensureBreakCoverage(
          entries,
          dayContext: dayContext,
          dayStart: dayStart,
          dayEnd: dayEnd,
          excludedPlannerEntryIds: excludedPlannerEntryIds,
        ),
      );
    }

    // Fixed calendar/lunch/opening-focus/early-break commitments only; real
    // tasks (scheduled below) fill whatever gaps remain after that.
    final taskSchedulingOccupants = List<DayPlannerEntry>.from(entries);

    final plannedTaskEntries = <DayPlannerEntry>[];
    final dailyCapacity = _calculateDailyCapacity(
      taskSchedulingOccupants,
      dayStart,
      dayEnd,
    );
    var remainingTaskCapacity = dailyCapacity.availableMinutes;
    final sessions = _createTaskSessions(prioritizedTasks);
    final scheduledTaskIds = <String>{};
    final overflowSessions = <_TaskSession>[];

    for (final session in sessions) {
      if (_isExcludedTaskSession(session, excludedPlannerEntryIds)) continue;
      final duration = session.duration;
      // A single oversized session shouldn't block smaller ones later in the
      // priority order from still fitting within the remaining capacity.
      if (duration.inMinutes > remainingTaskCapacity) {
        overflowSessions.add(session);
        continue;
      }
      final placedStart = _findNearestFreeStart(
        [...taskSchedulingOccupants, ...plannedTaskEntries],
        duration,
        dayStart,
        dayStart,
        dayEnd,
      );
      if (placedStart == null) {
        overflowSessions.add(session);
        continue;
      }

      final snappedStart = _snapToAvailableStart(
        occupied: [...taskSchedulingOccupants, ...plannedTaskEntries],
        start: placedStart,
        duration: duration,
        timeGrid: timeGrid,
        dayEnd: dayEnd,
      );
      if (snappedStart == null) {
        overflowSessions.add(session);
        continue;
      }
      plannedTaskEntries.add(_buildTaskEntry(session, snappedStart));
      remainingTaskCapacity -= duration.inMinutes;
      scheduledTaskIds.addAll(session.tasks.map((task) => task.id));
    }

    // The soft capacity/reserve above is meant to leave breathing room, but any
    // gap it leaves behind still gets visually filled with a generic "Focus
    // Time" block later. Prefer using that same physical space for real
    // backlog tasks so days don't look empty of actual work.
    for (final session in overflowSessions) {
      if (_isExcludedTaskSession(session, excludedPlannerEntryIds)) continue;
      final duration = session.duration;
      final placedStart = _findNearestFreeStart(
        [...taskSchedulingOccupants, ...plannedTaskEntries],
        duration,
        dayStart,
        dayStart,
        dayEnd,
      );
      if (placedStart == null) continue;
      final snappedStart = _snapToAvailableStart(
        occupied: [...taskSchedulingOccupants, ...plannedTaskEntries],
        start: placedStart,
        duration: duration,
        timeGrid: timeGrid,
        dayEnd: dayEnd,
      );
      if (snappedStart == null) continue;
      plannedTaskEntries.add(_buildTaskEntry(session, snappedStart));
      scheduledTaskIds.addAll(session.tasks.map((task) => task.id));
    }

    // Still gaps left? Pull forward backlog tasks that aren't due yet rather
    // than leaving the day looking empty until their due date arrives.
    final futureSessions = _createTaskSessions(
      _prioritizeFutureTasks(tasks, day),
      pulledForward: true,
    );
    for (final session in futureSessions) {
      if (_isExcludedTaskSession(session, excludedPlannerEntryIds)) continue;
      final duration = session.duration;
      final placedStart = _findNearestFreeStart(
        [...taskSchedulingOccupants, ...plannedTaskEntries],
        duration,
        dayStart,
        dayStart,
        dayEnd,
      );
      if (placedStart == null) continue;
      final snappedStart = _snapToAvailableStart(
        occupied: [...taskSchedulingOccupants, ...plannedTaskEntries],
        start: placedStart,
        duration: duration,
        timeGrid: timeGrid,
        dayEnd: dayEnd,
      );
      if (snappedStart == null) continue;
      plannedTaskEntries.add(_buildTaskEntry(session, snappedStart));
      scheduledTaskIds.addAll(session.tasks.map((task) => task.id));
    }

    // Now that real tasks have claimed whatever gap time they need, add any
    // further recovery breaks their own cumulative focus time requires
    // (_resetsFocusWork treats the early break/lunch above as a reset point).
    final lateRecoveryBreaks = isOfficeDay
        ? const <DayPlannerEntry>[]
        : _insertCumulativeFocusBreaks(
            [...entries, ...plannedTaskEntries],
            dayStart,
            dayEnd,
            excludedPlannerEntryIds: excludedPlannerEntryIds,
          );
    plannedTaskEntries.addAll(lateRecoveryBreaks);
    if (dayContext != null) {
      entries.addAll(
        _ensureBreakCoverage(
          [...entries, ...plannedTaskEntries],
          dayContext: dayContext,
          dayStart: dayStart,
          dayEnd: dayEnd,
          excludedPlannerEntryIds: excludedPlannerEntryIds,
        ),
      );
    }

    if (dayContext != null) {
      // Placed after tasks, the opening focus placeholder, and recovery
      // breaks so standing/walking can pair concurrently with any of them
      // (real work or flexible focus time isn't "planning work" that
      // movement needs its own exclusive block to avoid).
      final placedMovementEntries = _placeMovementEvents(
        day: day,
        dayContext: dayContext,
        occupiedEntries: [...entries, ...plannedTaskEntries],
        dayStart: dayStart,
        dayEnd: dayEnd,
        preferredConcurrentEntryIds: preferredConcurrentEntryIds,
        excludedConcurrentEntryIds: excludedConcurrentEntryIds,
        timeGrid: timeGrid,
        enabledActivityNames: enabledActivityNames,
      );
      movementEntries.addAll(placedMovementEntries);
      entries.addAll(placedMovementEntries);
    }

    final merged = <DayPlannerEntry>[];
    merged.addAll(entries);
    merged.addAll(plannedTaskEntries);
    final recommendations = dayContext == null
        ? const <ActivityRecommendation>[]
        : MovementRecommendationService.generateRecommendations(
            dayContext: dayContext,
            weeklyTotals: weeklyTotals,
            gymCompletedToday: gymCompletedToday,
            daysSinceLastMobility: daysSinceLastMobility,
          );
    final zwiftEntry = _buildZwiftEntry(
      recommendations: recommendations,
      occupiedEntries: merged,
      day: day,
    );
    if (zwiftEntry != null) {
      merged.add(zwiftEntry);
    }
    final mobilityEntry = _placeOptionalMobility(
      recommendations: recommendations,
      occupiedEntries: merged,
      dayStart: dayStart,
      dayEnd: dayEnd,
      timeGrid: timeGrid,
    );
    if (mobilityEntry != null) {
      merged.add(mobilityEntry);
    }
    merged.addAll(
      _ensureBreakCoverage(
        merged,
        dayContext: dayContext,
        dayStart: dayStart,
        dayEnd: dayEnd,
        excludedPlannerEntryIds: excludedPlannerEntryIds,
      ),
    );
    final mergedWithShortGaps = _extendShortGaps(merged, dayStart, dayEnd);
    merged
      ..clear()
      ..addAll(mergedWithShortGaps)
      ..addAll(_buildOpenBlocks(mergedWithShortGaps, dayStart, dayEnd));
    final overridden = entryOverrides.isEmpty
        ? merged
        : applyEntryOverrides(
            merged,
            entryOverrides,
            dayStart,
            dayEnd,
            resolveTask: (id) {
              for (final candidate in tasks) {
                if (candidate.id == id) return candidate;
              }
              return null;
            },
          );
    final normalizedEntries = _removeFocusOverlaps(
      _validatePlan(_removeTaskOverlaps(overridden), dayStart, dayEnd),
    );
    for (var index = 0; index < normalizedEntries.length; index++) {
      final entry = normalizedEntries[index];
      normalizedEntries[index] = entry.copyWith(
        executionState: executionStates[entry.id] ?? ExecutionState.pending,
      );
    }
    normalizedEntries.sort((a, b) => a.start.compareTo(b.start));

    final summarySegments = <String>[];
    final plannedTaskCount = plannedTaskEntries
        .where((entry) => entry.type == 'task' || entry.type == 'admin')
        .length;
    if (plannedTaskCount > 0) {
      summarySegments.add(
        '$plannedTaskCount focus block${plannedTaskCount == 1 ? '' : 's'}',
      );
    }
    if (plannedTaskEntries.where((entry) => entry.type == 'break').isNotEmpty) {
      summarySegments.add(
        '${plannedTaskEntries.where((entry) => entry.type == 'break').length} break${plannedTaskEntries.where((entry) => entry.type == 'break').length == 1 ? '' : 's'}',
      );
    }
    if (movementEntries.isNotEmpty) {
      final movementMinutes = movementEntries.fold<int>(
        0,
        (total, entry) => total + entry.end.difference(entry.start).inMinutes,
      );
      summarySegments.add('$movementMinutes min movement');
    }
    if (todaysEvents.isNotEmpty) {
      summarySegments.add(
        '${todaysEvents.length} calendar item${todaysEvents.length == 1 ? '' : 's'}',
      );
    }
    final rolloverTasks = actionableTasks
        .where((task) => !scheduledTaskIds.contains(task.id))
        .toList();
    final rolloverSummary = _buildRolloverSummary(rolloverTasks);
    if (rolloverSummary != null) summarySegments.add(rolloverSummary);
    return DayPlannerResult(
      entries: normalizedEntries,
      summary: summarySegments.isEmpty
          ? 'A light day is ready.'
          : summarySegments.join(' • '),
      recommendations: recommendations,
      rolloverTasks: rolloverTasks,
    );
  }

  static bool _isExcludedTaskSession(
    _TaskSession session,
    Set<String> excludedEntryIds,
  ) {
    if (excludedEntryIds.isEmpty) return false;
    final task = session.primaryTask;
    final entryId = session.isAdmin
        ? 'admin-${task.id}'
        : session.sessionCount == 1
        ? 'task-${task.id}'
        : 'task-${task.id}-session-${session.sessionIndex}';
    return excludedEntryIds.contains(entryId);
  }

  static List<_PrioritizedTask> _prioritizeTasks(
    List<Task> tasks,
    DateTime day,
  ) {
    final targetDay = DateTime(day.year, day.month, day.day);
    final scored = tasks.where((task) => _isTaskEligibleForDay(task, day)).map((
      task,
    ) {
      return _PrioritizedTask(task: task, score: _taskScore(task, targetDay));
    }).toList();
    scored.sort((a, b) {
      final absolutePriorityCompare = (b.task.absolutePriority ? 1 : 0)
          .compareTo(a.task.absolutePriority ? 1 : 0);
      if (absolutePriorityCompare != 0) return absolutePriorityCompare;
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final aDate = _planningDateForTask(a.task);
      final bDate = _planningDateForTask(b.task);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return scored;
  }

  /// Tasks not yet due today (future due/do date, or no date at all), kept in
  /// reserve to fill spare capacity so days don't sit empty while backlog waits.
  static List<_PrioritizedTask> _prioritizeFutureTasks(
    List<Task> tasks,
    DateTime day,
  ) {
    final targetDay = DateTime(day.year, day.month, day.day);
    final scored = tasks
        .where(
          (task) =>
              task.done != true &&
              !task.waitingOnOthers &&
              !_isTaskEligibleForDay(task, day) &&
              !_isBlockedAsOverdue(task, targetDay),
        )
        .map((task) {
          return _PrioritizedTask(
            task: task,
            score: _taskScore(task, targetDay),
          );
        })
        .toList();
    scored.sort((a, b) {
      final absolutePriorityCompare = (b.task.absolutePriority ? 1 : 0)
          .compareTo(a.task.absolutePriority ? 1 : 0);
      if (absolutePriorityCompare != 0) return absolutePriorityCompare;
      final aDate = _planningDateForTask(a.task);
      final bDate = _planningDateForTask(b.task);
      if (aDate == null && bDate != null) return 1;
      if (aDate != null && bDate == null) return -1;
      if (aDate != null && bDate != null && aDate != bDate) {
        return aDate.compareTo(bDate);
      }
      return b.score.compareTo(a.score);
    });
    return scored;
  }

  static double _taskScore(Task task, DateTime targetDay) {
    if (task.absolutePriority) return double.infinity;
    final dueDate = _dateOnly(_parseTaskDate(task.dueDate));
    final planningDate = _dateOnly(
      _parseTaskDate(task.doDate) ?? _parseTaskDate(task.dueDate),
    );
    final overdueDays = dueDate == null
        ? 0
        : targetDay.difference(dueDate).inDays;
    final isDueForPlanning =
        planningDate != null && !planningDate.isAfter(targetDay);
    final isRolledOver =
        planningDate != null && planningDate.isBefore(targetDay);
    final priorityScore = switch (task.priority) {
      'high' => 40,
      'medium' => 20,
      'low' => 0,
      _ => 20,
    };
    final overdueScore = overdueDays > 0 ? 35 + overdueDays.clamp(0, 14) : 0;
    final urgencyScore = isDueForPlanning ? 30 : 0;
    final rolloverScore = isRolledOver ? 15 : 0;
    final contextPenalty = _hasCategory(task) ? -5 : 0;
    return (priorityScore +
            overdueScore +
            urgencyScore +
            rolloverScore +
            contextPenalty)
        .toDouble();
  }

  static DateTime? _dateOnly(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day);
  }

  static bool _hasCategory(Task task) {
    final category = task.category.trim().toLowerCase();
    return category.isNotEmpty && category != 'none';
  }

  static String? _buildRolloverSummary(List<Task> rolloverTasks) {
    if (rolloverTasks.isEmpty) return null;
    return '${rolloverTasks.length} task${rolloverTasks.length == 1 ? '' : 's'} rolled over';
  }

  static List<List<_PrioritizedTask>> _groupAdminTasks(
    List<_PrioritizedTask> tasks,
  ) {
    final groups = <List<_PrioritizedTask>>[];
    var current = <_PrioritizedTask>[];
    var currentMinutes = 0;
    for (final item in tasks) {
      final minutes = _estimateTaskDuration(item.task).inMinutes;
      if (minutes > 15) continue;
      if (current.isNotEmpty && currentMinutes + minutes > 60) {
        groups.add(current);
        current = <_PrioritizedTask>[];
        currentMinutes = 0;
      }
      current.add(item);
      currentMinutes += minutes;
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }

  static DayPlannerEntry _buildTaskEntry(_TaskSession session, DateTime start) {
    final duration = session.duration;
    final task = session.primaryTask;
    return DayPlannerEntry(
      id: session.isAdmin
          ? 'admin-${task.id}'
          : session.sessionCount == 1
          ? 'task-${task.id}'
          : 'task-${task.id}-session-${session.sessionIndex}',
      title: session.isAdmin
          ? 'Admin Block'
          : session.sessionCount == 1
          ? task.task
          : '${task.task} (Session ${session.sessionIndex}/${session.sessionCount})',
      type: session.isAdmin ? 'admin' : 'task',
      start: start,
      end: start.add(duration),
      subtitle: session.isAdmin
          ? 'Includes: ${session.tasks.map((task) => task.task).join(', ')}'
          : session.isPulledForward
          ? '${_taskSubtitle(task)} • Pulled forward from backlog'
          : _taskSubtitle(task),
      task: task,
      relatedTaskIds: session.tasks.map((task) => task.id).toList(),
      category: PlannerEventCategory.planned,
    );
  }

  static List<DayPlannerEntry> _buildCommuteEntries(
    DateTime day,
    DateTime workDayStart,
    DateTime dayEnd,
  ) {
    final dayBeginning = DateTime(day.year, day.month, day.day);
    final dayFinish = dayBeginning.add(const Duration(days: 1));
    Task commuteTask(String direction) => Task(
      id: 'commute-$direction-${day.year}-${day.month}-${day.day}',
      task: 'Commute',
      category: 'Work',
      effortMinutes: 60,
      nextSessionEffortMinutes: 60,
    );
    final entries = <DayPlannerEntry>[];
    final beforeStart = workDayStart.subtract(const Duration(hours: 1));
    if (beforeStart.isAfter(dayBeginning)) {
      entries.add(
        DayPlannerEntry(
          id: 'commute-before-${day.year}-${day.month}-${day.day}',
          title: 'Commute',
          type: 'task',
          start: beforeStart,
          end: workDayStart,
          subtitle: 'Before work window',
          task: commuteTask('before'),
          category: PlannerEventCategory.planned,
        ),
      );
    }

    final afterEnd = dayEnd.add(const Duration(hours: 1));
    if (afterEnd.isAfter(dayEnd) && afterEnd.isBefore(dayFinish)) {
      entries.add(
        DayPlannerEntry(
          id: 'commute-after-${day.year}-${day.month}-${day.day}',
          title: 'Commute',
          type: 'task',
          start: dayEnd,
          end: afterEnd,
          subtitle: 'After work window',
          task: commuteTask('after'),
          category: PlannerEventCategory.planned,
        ),
      );
    }
    return entries;
  }

  static DayPlannerEntry? _buildSwitchOffEntry(DateTime day, DateTime dayEnd) {
    final end = dayEnd.add(const Duration(minutes: 15));
    final dayFinish = DateTime(day.year, day.month, day.day + 1);
    if (!end.isBefore(dayFinish)) return null;
    return DayPlannerEntry(
      id: 'switch-off-${day.year}-${day.month}-${day.day}',
      title: 'Switch off',
      type: 'task',
      start: dayEnd,
      end: end,
      subtitle: 'End of work window',
      task: Task(
        id: 'switch-off-${day.year}-${day.month}-${day.day}',
        task: 'Switch off',
        category: 'Work',
        effortMinutes: 15,
        nextSessionEffortMinutes: 15,
      ),
      category: PlannerEventCategory.planned,
    );
  }

  static List<_TaskSession> _createTaskSessions(
    List<_PrioritizedTask> prioritizedTasks, {
    bool pulledForward = false,
  }) {
    final sessions = <_TaskSession>[];
    final adminGroups = _groupAdminTasks(prioritizedTasks);
    final adminTasks = adminGroups.expand((group) => group).toSet();

    for (final item in prioritizedTasks) {
      if (adminTasks.contains(item)) continue;
      final minutes = _estimateTaskDuration(item.task).inMinutes;
      final splitCount = (minutes / PlannerBreakPolicy.maxFocusSessionMinutes)
          .ceil();
      var remaining = minutes;

      for (var index = 1; index <= splitCount; index++) {
        final sessionMinutes =
            remaining > PlannerBreakPolicy.maxFocusSessionMinutes
            ? PlannerBreakPolicy.maxFocusSessionMinutes
            : remaining;
        sessions.add(
          _TaskSession(
            tasks: [item.task],
            duration: Duration(minutes: sessionMinutes),
            sessionIndex: index,
            sessionCount: splitCount,
            isPulledForward: pulledForward,
          ),
        );
        remaining -= sessionMinutes;
      }
    }

    for (final group in adminGroups) {
      final minutes = group.fold<int>(
        0,
        (total, item) => total + _estimateTaskDuration(item.task).inMinutes,
      );
      final splitCount = (minutes / PlannerBreakPolicy.maxFocusSessionMinutes)
          .ceil();
      var remaining = minutes;

      for (var index = 1; index <= splitCount; index++) {
        final sessionMinutes =
            remaining > PlannerBreakPolicy.maxFocusSessionMinutes
            ? PlannerBreakPolicy.maxFocusSessionMinutes
            : remaining;
        sessions.add(
          _TaskSession(
            tasks: group.map((item) => item.task).toList(),
            duration: Duration(minutes: sessionMinutes),
            sessionIndex: index,
            sessionCount: splitCount,
            isAdmin: true,
            isPulledForward: pulledForward,
          ),
        );
        remaining -= sessionMinutes;
      }
    }
    return sessions;
  }

  static List<DayPlannerEntry> _insertCumulativeFocusBreaks(
    List<DayPlannerEntry> existingEntries,
    DateTime dayStart,
    DateTime dayEnd, {
    Set<String> excludedPlannerEntryIds = const <String>{},
  }) {
    final focusEntries =
        existingEntries
            .where(
              (entry) => _countsAsFocusWork(entry) || _resetsFocusWork(entry),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final occupied = List<DayPlannerEntry>.from(existingEntries);
    final breaks = <DayPlannerEntry>[];
    var cumulativeFocusMinutes = 0;
    var breakIndex = 0;
    for (final focusEntry in focusEntries) {
      if (_resetsFocusWork(focusEntry)) {
        cumulativeFocusMinutes = 0;
        continue;
      }
      cumulativeFocusMinutes += focusEntry.end
          .difference(focusEntry.start)
          .inMinutes;
      final breakMinutes = PlannerBreakPolicy.recoveryBreakMinutesForFocus(
        cumulativeFocusMinutes,
      );
      if (breakMinutes == 0) continue;
      final lunchBreak = existingEntries.cast<DayPlannerEntry?>().firstWhere(
        (entry) => entry?.id == 'break-lunch',
        orElse: () => null,
      );
      if (lunchBreak != null &&
          !lunchBreak.start.isBefore(focusEntry.end) &&
          lunchBreak.start.difference(focusEntry.end) <=
              const Duration(minutes: 30)) {
        cumulativeFocusMinutes = 0;
        continue;
      }
      final duration = Duration(minutes: breakMinutes);
      final workWindowMinutes = dayEnd.difference(dayStart).inMinutes;
      final finalHourBoundary = workWindowMinutes >= 480
          ? dayEnd.subtract(const Duration(hours: 1))
          : dayEnd;
      final placedStart = _findNearestFreeStart(
        occupied,
        duration,
        focusEntry.end,
        dayStart,
        dayEnd,
        minimumGap: const Duration(hours: 1),
        separateFromTypes: const {'break', 'movement'},
        latestAllowedStart: finalHourBoundary.subtract(duration),
      );
      if (placedStart == null) continue;
      final breakEntry = DayPlannerEntry(
        id: 'break-cumulative-$breakIndex',
        title: 'Recovery break',
        type: 'break',
        start: placedStart,
        end: placedStart.add(duration),
        subtitle: 'Recovery after $cumulativeFocusMinutes min focus',
      );
      breakIndex++;
      if (excludedPlannerEntryIds.contains(breakEntry.id)) {
        cumulativeFocusMinutes = 0;
        continue;
      }
      breaks.add(breakEntry);
      occupied.add(breakEntry);
      cumulativeFocusMinutes = 0;
    }
    return breaks;
  }

  static bool _countsAsFocusWork(DayPlannerEntry entry) {
    if (entry.isAllDay || entry.isZeroDuration) return false;
    if (entry.type == 'task' ||
        entry.type == 'admin' ||
        entry.type == 'focus') {
      return true;
    }
    return entry.type == 'calendar' &&
        entry.subtitle?.toLowerCase().contains('work calendar') == true;
  }

  static List<DayPlannerEntry> _ensureBreakCoverage(
    List<DayPlannerEntry> entries, {
    required DayContext? dayContext,
    required DateTime dayStart,
    required DateTime dayEnd,
    Set<String> excludedPlannerEntryIds = const <String>{},
  }) {
    if (dayContext == null) return const <DayPlannerEntry>[];
    // Breaks are never allowed in the final hour of the day, so every
    // required window is clamped to end by then.
    final lastAllowedBreakEnd = dayEnd.subtract(const Duration(hours: 1));
    final requiredWindows = <({DateTime start, DateTime end})>[];

    // At least one break in the first 3 hours (lunch, 12pm-2pm, is handled
    // separately by _placeLunch and already counts as break-like coverage).
    final firstWindowEnd = dayStart.add(const Duration(hours: 3));
    final firstWindow = (
      start: dayStart,
      end: firstWindowEnd.isBefore(lastAllowedBreakEnd)
          ? firstWindowEnd
          : lastAllowedBreakEnd,
    );
    if (firstWindow.end.isAfter(firstWindow.start)) {
      requiredWindows.add(firstWindow);
    }

    // At least one break in the last 3 hours (excluding the final hour).
    final lastWindowStart = dayEnd.subtract(const Duration(hours: 3));
    final lastWindow = (
      start: lastWindowStart.isBefore(dayStart) ? dayStart : lastWindowStart,
      end: lastAllowedBreakEnd,
    );
    if (lastWindow.end.isAfter(lastWindow.start)) {
      requiredWindows.add(lastWindow);
    }

    final additions = <DayPlannerEntry>[];
    final occupied = List<DayPlannerEntry>.from(entries);
    final isOfficeDay = dayContext.workLocation == WorkLocation.office;
    for (var index = 0; index < requiredWindows.length; index++) {
      final window = requiredWindows[index];
      final hasBreak = occupied.any(
        (entry) =>
            _isBreakLikeEntry(entry) &&
            entry.start.isBefore(window.end) &&
            entry.end.isAfter(window.start),
      );
      if (hasBreak) continue;

      final duration = const Duration(minutes: 15);
      final target = window.start.add(
        Duration(minutes: window.end.difference(window.start).inMinutes ~/ 2),
      );
      final start = _findNearestFreeStart(
        occupied,
        duration,
        target,
        dayStart,
        dayEnd,
        earliestStart: window.start,
        latestAllowedStart: window.end.subtract(duration),
        minimumGap: const Duration(hours: 1),
        separateFromTypes: const {'break', 'movement'},
      );
      if (start == null) continue;
      final breakEntry = DayPlannerEntry(
        id: 'break-coverage-$index',
        title: isOfficeDay ? 'Walk break' : 'Recovery break',
        type: isOfficeDay ? 'movement' : 'break',
        start: start,
        end: start.add(duration),
        subtitle: isOfficeDay ? 'Office movement' : 'Scheduled recovery',
      );
      if (excludedPlannerEntryIds.contains(breakEntry.id)) continue;
      additions.add(breakEntry);
      occupied.add(breakEntry);
    }
    return additions;
  }

  static bool _isBreakLikeEntry(DayPlannerEntry entry) {
    return entry.type == 'break' ||
        (entry.type == 'movement' &&
            !entry.isConcurrent &&
            entry.title.toLowerCase().contains('walk'));
  }

  static bool _isLunchBreak(DayPlannerEntry entry) {
    return entry.id == 'break-lunch';
  }

  static bool _resetsFocusWork(DayPlannerEntry entry) {
    return entry.id == 'break-lunch' || entry.title == 'Recovery break';
  }

  static DayPlannerEntry? _buildZwiftEntry({
    required List<ActivityRecommendation> recommendations,
    required List<DayPlannerEntry> occupiedEntries,
    required DateTime day,
  }) {
    final hasZwiftRecommendation = recommendations.any(
      (recommendation) => recommendation.pillar == ActivityPillar.zwift,
    );
    if (!hasZwiftRecommendation) return null;

    final dayStart = DateTime(day.year, day.month, day.day);
    final eveningStart = dayStart.add(const Duration(hours: 18));
    final dayEnd = dayStart.add(const Duration(days: 1));
    const duration = Duration(minutes: 45);
    final occupied = occupiedEntries.where(_occupiesPlanningTime);
    for (
      var candidate = eveningStart;
      candidate.add(duration).isBefore(dayEnd) ||
          candidate.add(duration).isAtSameMomentAs(dayEnd);
      candidate = candidate.add(const Duration(minutes: 15))
    ) {
      final candidateEnd = candidate.add(duration);
      final overlaps = occupied.any(
        (entry) =>
            candidate.isBefore(entry.end) && candidateEnd.isAfter(entry.start),
      );
      if (!overlaps) {
        return DayPlannerEntry(
          id: 'activity-zwift',
          title: 'Zwift ride',
          type: 'movement',
          start: candidate,
          end: candidateEnd,
          subtitle: 'Evening Zwift session',
          category: PlannerEventCategory.planned,
        );
      }
    }
    return null;
  }

  static List<DayPlannerEntry> _placeMovementEvents({
    required DateTime day,
    required DayContext? dayContext,
    required List<DayPlannerEntry> occupiedEntries,
    required DateTime dayStart,
    required DateTime dayEnd,
    required Set<String> preferredConcurrentEntryIds,
    required Set<String> excludedConcurrentEntryIds,
    required TimeGrid timeGrid,
    // User-configured, per-day-enabled movement activity names (Settings ->
    // Movement activities + the planner's "Choose available activities"
    // toggle). Null means "not specified" (e.g. older callers/tests) — falls
    // back to the original built-in names/behavior below. An explicit EMPTY
    // list means the user deselected every activity for today.
    List<String>? enabledActivityNames,
  }) {
    if (dayContext == null) {
      return const <DayPlannerEntry>[];
    }
    if (enabledActivityNames != null && enabledActivityNames.isEmpty) {
      return const <DayPlannerEntry>[];
    }

    final targets = MovementRecommendationService.resolveDayTypeTargets(
      dayContext,
    );
    final mode = dayContext.workLocation == WorkLocation.home
        ? 'home'
        : 'office';
    final standingBlockMinutes = (targets.standingMinutes.minMinutes / 2)
        .round()
        .clamp(15, 60);
    final walkingBlockMinutes = (targets.walkingMinutes.minMinutes / 2)
        .round()
        .clamp(10, 45);
    final entries = <DayPlannerEntry>[];
    // Duration for a named activity: named-activity durations use the same
    // standing/walking split as before, matched by the name containing
    // "stand"/"walk" (case-insensitive) — falls back to the average of the
    // two for an unrecognized custom name. Office blocks always stay 15 min.
    int durationMinutesFor(String name) {
      if (mode == 'office') return 15;
      final lower = name.toLowerCase();
      if (lower.contains('walk')) return walkingBlockMinutes;
      if (lower.contains('stand')) return standingBlockMinutes;
      return ((standingBlockMinutes + walkingBlockMinutes) / 2).round();
    }

    List<(int, String, String)> blockDurations;
    if (enabledActivityNames != null && enabledActivityNames.isNotEmpty) {
      final slotCount = mode == 'home' ? 4 : 3;
      blockDurations = List<(int, String, String)>.generate(slotCount, (i) {
        final name = enabledActivityNames[i % enabledActivityNames.length];
        return (durationMinutesFor(name), name, name);
      });
    } else {
      blockDurations = mode == 'home'
          ? [
              (standingBlockMinutes, 'Stand at your desk', 'Standing desk'),
              (walkingBlockMinutes, 'Walk while you work', 'Walking pad'),
              (standingBlockMinutes, 'Stand at your desk', 'Standing desk'),
              (walkingBlockMinutes, 'Walk while you work', 'Walking pad'),
            ]
          : [
              (walkingBlockMinutes, 'Walk while you work', 'Office movement'),
              (walkingBlockMinutes, 'Walk while you work', 'Office movement'),
              (walkingBlockMinutes, 'Walk while you work', 'Office movement'),
            ];
    }

    final occupied = occupiedEntries.where(_occupiesPlanningTime).toList()
      ..sort((a, b) {
        final startCompare = a.start.compareTo(b.start);
        if (startCompare != 0) return startCompare;
        final aIsCalendar = a.type == 'calendar';
        final bIsCalendar = b.type == 'calendar';
        if (aIsCalendar != bIsCalendar) return aIsCalendar ? -1 : 1;
        return b.end.compareTo(a.end);
      });
    for (var blockIndex = 0; blockIndex < blockDurations.length; blockIndex++) {
      final block = blockDurations[blockIndex];
      final duration = mode == 'office'
          ? const Duration(minutes: 15)
          : _snapDurationToFiveMinutes(Duration(minutes: block.$1));
      final movementLabel = block.$3;
      final canRunConcurrently =
          mode != 'office' || preferredConcurrentEntryIds.isNotEmpty;
      final movementTarget = dayStart.add(
        Duration(
          minutes:
              (dayEnd.difference(dayStart).inMinutes *
                      (blockIndex + 1) /
                      (blockDurations.length + 1))
                  .round(),
        ),
      );
      final concurrentEntry = canRunConcurrently
          ? _findConcurrentEntry(
              occupied,
              duration,
              mode,
              preferredConcurrentEntryIds,
              excludedConcurrentEntryIds,
              dayStart,
              dayEnd,
              target: movementTarget,
            )
          : null;
      if (concurrentEntry != null) {
        final concurrentStart = concurrentEntry.start.isBefore(dayStart)
            ? dayStart
            : concurrentEntry.start;
        final concurrentEnd =
            concurrentStart.add(duration).isBefore(concurrentEntry.end)
            ? concurrentStart.add(duration)
            : concurrentEntry.end;
        if (concurrentEnd.difference(concurrentStart) >= duration) {
          final concurrentTitle = concurrentEntry.title;
          entries.add(
            DayPlannerEntry(
              id: 'movement-$mode-${entries.length}',
              title: block.$2,
              type: 'movement',
              start: concurrentStart,
              end: concurrentEnd,
              subtitle: '$movementLabel • During $concurrentTitle',
              isConcurrent: true,
            ),
          );
          occupied.add(entries.last);
          continue;
        }
      }
      final placedStart = _findNearestFreeStart(
        occupied,
        duration,
        movementTarget,
        dayStart,
        dayEnd,
        minimumGap: const Duration(hours: 1),
        separateFromTypes: const {'movement', 'break'},
        minimumGapByType: mode == 'office'
            ? const {
                'movement': Duration(minutes: 60),
                'break': Duration(hours: 1),
              }
            : const <String, Duration>{},
      );
      if (placedStart == null) break;

      final snappedStart = PlannerExecutionService.snapToGrid(
        placedStart,
        timeGrid,
      );
      final end = snappedStart.add(duration);
      entries.add(
        DayPlannerEntry(
          id: 'movement-$mode-${entries.length}',
          title: block.$2,
          type: 'movement',
          start: snappedStart,
          end: end,
          subtitle: movementLabel,
        ),
      );
      occupied.add(entries.last);
      occupied.sort((a, b) => a.start.compareTo(b.start));
    }

    return entries;
  }

  static DayPlannerEntry? _placeOptionalMobility({
    required List<ActivityRecommendation> recommendations,
    required List<DayPlannerEntry> occupiedEntries,
    required DateTime dayStart,
    required DateTime dayEnd,
    required TimeGrid timeGrid,
  }) {
    final hasMobilityRecommendation = recommendations.any(
      (recommendation) => recommendation.pillar == ActivityPillar.mobility,
    );
    if (!hasMobilityRecommendation) return null;

    const duration = Duration(minutes: 10);
    final dayBoundary = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
    ).add(const Duration(days: 1));
    if (!dayBoundary.isAfter(dayEnd)) return null;

    final target = dayEnd.add(
      Duration(minutes: (dayBoundary.difference(dayEnd).inMinutes / 2).round()),
    );
    final placedStart = _findNearestFreeStart(
      occupiedEntries,
      duration,
      target,
      dayEnd,
      dayBoundary,
    );
    if (placedStart == null) return null;

    final start = PlannerExecutionService.snapToGrid(placedStart, timeGrid);
    final end = start.add(duration);
    if (start.isBefore(dayEnd) || end.isAfter(dayBoundary)) return null;
    return DayPlannerEntry(
      id: 'activity-mobility',
      title: 'Mobility session',
      type: 'movement',
      start: start,
      end: end,
      subtitle: 'Optional recovery movement',
      category: PlannerEventCategory.planned,
    );
  }

  static List<DayPlannerEntry> _buildOpenBlocks(
    List<DayPlannerEntry> entries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final occupied =
        entries
            .where(
              (entry) =>
                  _occupiesPlanningTime(entry) &&
                  (entry.type != 'movement' || !entry.isConcurrent),
            )
            .map(
              (entry) => (
                start: entry.start.isBefore(dayStart) ? dayStart : entry.start,
                end: entry.end.isAfter(dayEnd) ? dayEnd : entry.end,
              ),
            )
            .where((entry) => entry.end.isAfter(entry.start))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final blocks = <DayPlannerEntry>[];
    var cursor = dayStart;

    for (final entry in occupied) {
      if (entry.start.isAfter(cursor)) {
        final gapStart = cursor;
        final gapEnd = entry.start;
        final isStartGap = gapStart.isAtSameMomentAs(dayStart);
        if (isStartGap &&
            gapEnd.difference(gapStart) >= const Duration(minutes: 30)) {
          final focusMinutes = gapEnd
              .difference(gapStart)
              .inMinutes
              .clamp(30, PlannerBreakPolicy.maxFocusSessionMinutes);
          final focusEnd = gapStart.add(Duration(minutes: focusMinutes));
          blocks.add(
            DayPlannerEntry(
              id: 'buffer-${blocks.length}',
              title: 'Focus Time',
              type: 'focus',
              start: gapStart,
              end: focusEnd,
              subtitle: 'Opening focus session',
            ),
          );
          if (gapEnd.difference(focusEnd) >=
              const Duration(
                minutes: PlannerBreakPolicy.minAvailableTimeMinutes,
              )) {
            blocks.add(
              DayPlannerEntry(
                id: 'focus-${blocks.length}',
                title: 'Focus Time',
                type: 'focus',
                start: focusEnd,
                end: gapEnd,
                subtitle: 'Filled planning gap',
              ),
            );
          }
          cursor = gapEnd;
        } else if (gapEnd.difference(gapStart) >=
            const Duration(
              minutes: PlannerBreakPolicy.minAvailableTimeMinutes,
            )) {
          blocks.add(
            DayPlannerEntry(
              id: 'focus-${blocks.length}',
              title: 'Focus Time',
              type: 'focus',
              start: gapStart,
              end: gapEnd,
              subtitle: 'Filled planning gap',
            ),
          );
          cursor = gapEnd;
        }
      }
      if (entry.end.isAfter(cursor)) cursor = entry.end;
    }

    if (dayEnd.isAfter(cursor)) {
      final gapStart = cursor;
      final gapEnd = dayEnd;
      if (gapStart.isAtSameMomentAs(dayStart) &&
          gapEnd.difference(gapStart) >= const Duration(minutes: 30)) {
        final focusMinutes = gapEnd
            .difference(gapStart)
            .inMinutes
            .clamp(30, PlannerBreakPolicy.maxFocusSessionMinutes);
        final focusEnd = gapStart.add(Duration(minutes: focusMinutes));
        blocks.add(
          DayPlannerEntry(
            id: 'buffer-${blocks.length}',
            title: 'Focus Time',
            type: 'focus',
            start: gapStart,
            end: focusEnd,
            subtitle: 'Opening focus session',
          ),
        );
        if (gapEnd.difference(focusEnd) >=
            const Duration(
              minutes: PlannerBreakPolicy.minAvailableTimeMinutes,
            )) {
          blocks.add(
            DayPlannerEntry(
              id: 'focus-${blocks.length}',
              title: 'Focus Time',
              type: 'focus',
              start: focusEnd,
              end: gapEnd,
              subtitle: 'Filled planning gap',
            ),
          );
        }
      } else if (gapEnd.difference(gapStart) >=
          const Duration(minutes: PlannerBreakPolicy.minAvailableTimeMinutes)) {
        blocks.add(
          DayPlannerEntry(
            id: 'focus-${blocks.length}',
            title: 'Focus Time',
            type: 'focus',
            start: gapStart,
            end: gapEnd,
            subtitle: 'Filled planning gap',
          ),
        );
      }
    }

    return blocks;
  }

  static DayPlannerEntry? _buildOpeningFocusEntry(
    List<DayPlannerEntry> entries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    if (entries.any(
      (entry) =>
          (_occupiesPlanningTime(entry) &&
              !entry.start.isAfter(dayStart) &&
              entry.end.isAfter(dayStart)) ||
          (entry.type == 'calendar' &&
              _isWorkCalendarEntry(entry) &&
              entry.start.isAtSameMomentAs(dayStart)),
    )) {
      return null;
    }
    var focusEnd = dayStart.add(
      const Duration(minutes: PlannerBreakPolicy.maxFocusSessionMinutes),
    );
    final openingOccupant = entries
        .where(
          (entry) =>
              _occupiesPlanningTime(entry) &&
              entry.start.isBefore(focusEnd) &&
              entry.end.isAfter(dayStart),
        )
        .map((entry) => entry.start.isBefore(dayStart) ? dayStart : entry.start)
        .where((start) => start.isAfter(dayStart))
        .fold<DateTime?>(null, (earliest, start) {
          if (earliest == null || start.isBefore(earliest)) return start;
          return earliest;
        });
    if (openingOccupant != null) focusEnd = openingOccupant;
    if (focusEnd.isAfter(dayEnd)) focusEnd = dayEnd;
    if (focusEnd.difference(dayStart) <
        const Duration(minutes: PlannerBreakPolicy.minAvailableTimeMinutes)) {
      return null;
    }

    return DayPlannerEntry(
      id: 'focus-opening',
      title: 'Focus Time',
      type: 'focus',
      start: dayStart,
      end: focusEnd,
      subtitle: 'Opening focus session',
    );
  }

  static _DailyCapacity _calculateDailyCapacity(
    List<DayPlannerEntry> fixedEntries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final intervals =
        fixedEntries
            .where(_occupiesPlanningTime)
            .map(
              (entry) => (
                start: entry.start.isBefore(dayStart) ? dayStart : entry.start,
                end: entry.end.isAfter(dayEnd) ? dayEnd : entry.end,
              ),
            )
            .where((entry) => entry.end.isAfter(entry.start))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    var fixedMinutes = 0;
    var occupiedEnd = dayStart;
    for (final interval in intervals) {
      final effectiveStart = interval.start.isAfter(occupiedEnd)
          ? interval.start
          : occupiedEnd;
      if (interval.end.isAfter(effectiveStart)) {
        fixedMinutes += interval.end.difference(effectiveStart).inMinutes;
      }
      if (interval.end.isAfter(occupiedEnd)) occupiedEnd = interval.end;
    }
    final workWindowMinutes = dayEnd.difference(dayStart).inMinutes;
    final reserveMinutes = (workWindowMinutes * 0.15).round();
    final hasLunch = fixedEntries.any(
      (entry) => entry.type == 'break' && entry.id == 'break-lunch',
    );
    return _DailyCapacity(
      workWindowMinutes: workWindowMinutes,
      fixedEventMinutes: fixedMinutes,
      lunchMinutes: hasLunch ? 0 : const Duration(minutes: 30).inMinutes,
      requiredBreakMinutes: workWindowMinutes >= 120 ? 10 : 0,
      movementMinimumMinutes: 0,
      reserveMinutes: reserveMinutes,
    );
  }

  static DayPlannerEntry? _placeLunch(
    List<DayPlannerEntry> fixedEntries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    const duration = Duration(minutes: 30);
    final midday = DateTime(dayStart.year, dayStart.month, dayStart.day, 12);
    final middayLatestStart = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      13,
      30,
    );
    final latestLunchStart =
        dayEnd.subtract(duration).isBefore(middayLatestStart)
        ? dayEnd.subtract(duration)
        : middayLatestStart;
    if (!dayEnd.isAfter(midday)) return null;
    final midpoint = dayStart.add(
      Duration(minutes: dayEnd.difference(dayStart).inMinutes ~/ 2),
    );
    final target = midpoint.isBefore(midday)
        ? midday
        : midpoint.isAfter(latestLunchStart)
        ? latestLunchStart
        : midpoint;
    final start = _findNearestFreeStart(
      fixedEntries,
      duration,
      target,
      dayStart,
      dayEnd,
      earliestStart: midday.isAfter(dayStart) ? midday : dayStart,
      latestAllowedStart: latestLunchStart,
    );
    if (start == null) return null;
    return DayPlannerEntry(
      id: 'break-lunch',
      title: 'Lunch / reset break',
      type: 'break',
      start: start,
      end: start.add(duration),
      subtitle: 'Protected midday recovery',
    );
  }

  // Guards against the same logical entry appearing twice in one plan — e.g.
  // a calendar event surfaced by both a live sync and a stale import with a
  // slightly different underlying id, or a frozen-plan replan merge briefly
  // carrying the same entry in both its "past" and "future" halves. Collapses
  // entries that share the same type/title/start/end (i.e. are clearly the
  // same real-world event/block), regardless of id — task ids can legitimately
  // collide (auto-generated from a timestamp) without the entries themselves
  // being duplicates of each other, so id alone isn't used as the key here.
  static List<DayPlannerEntry> _removeDuplicateEntries(
    List<DayPlannerEntry> entries,
  ) {
    final seenSignatures = <String>{};
    final deduped = <DayPlannerEntry>[];
    for (final entry in entries) {
      final signature =
          '${entry.type}|${entry.title.trim().toLowerCase()}|'
          '${entry.start.toIso8601String()}|${entry.end.toIso8601String()}';
      if (!seenSignatures.add(signature)) {
        continue;
      }
      deduped.add(entry);
    }
    return deduped;
  }

  static List<DayPlannerEntry> _removeTaskOverlaps(
    List<DayPlannerEntry> entries,
  ) {
    final tasks = entries.where((entry) => entry.type == 'task').toList();
    final normalized = <DayPlannerEntry>[];
    for (final entry in entries) {
      if (entry.type != 'break' && entry.type != 'buffer') {
        normalized.add(entry);
        continue;
      }
      DayPlannerEntry? adjusted = entry;
      for (final task in tasks) {
        final current = adjusted;
        if (current == null) break;
        final overlaps =
            current.start.isBefore(task.end) && current.end.isAfter(task.start);
        if (!overlaps) continue;
        if (current.type == 'buffer' ||
            current.title == 'Recovery break' ||
            !current.start.isBefore(task.start)) {
          adjusted = null;
          break;
        }
        adjusted = current.copyWith(end: task.start);
      }
      if (adjusted != null && adjusted.end.isAfter(adjusted.start)) {
        normalized.add(adjusted);
      }
    }
    return normalized;
  }

  static List<DayPlannerEntry> _validatePlan(
    List<DayPlannerEntry> entries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    var normalized = entries.where((entry) {
      if (entry.isAllDay) return true;
      return entry.end.isAfter(entry.start);
    }).toList();

    normalized = _removeDuplicateEntries(normalized);

    normalized = normalized
        .where((entry) {
          if (entry.title != 'Recovery break') return true;
          return entry.start
                  .add(
                    const Duration(
                      minutes: PlannerBreakPolicy.recoveryBreakMinutes,
                    ),
                  )
                  .isBefore(dayEnd) ||
              entry.start
                  .add(
                    const Duration(
                      minutes: PlannerBreakPolicy.recoveryBreakMinutes,
                    ),
                  )
                  .isAtSameMomentAs(dayEnd);
        })
        .map(
          (entry) => entry.title == 'Recovery break'
              ? entry.copyWith(
                  end: entry.start.add(
                    const Duration(
                      minutes: PlannerBreakPolicy.recoveryBreakMinutes,
                    ),
                  ),
                )
              : entry,
        )
        .toList();
    normalized = _removeBreakConflicts(normalized);
    normalized = _removeTaskOverlaps(normalized);
    normalized = _removeFocusTaskOverlaps(normalized);
    normalized = _ensureOpeningAvailableTime(normalized, dayStart, dayEnd);
    normalized = _fillGapsWithPlannerTime(normalized, dayStart, dayEnd);
    normalized = _normalizeLunchBoundary(normalized);
    normalized = _removeBreakCalendarOverlaps(normalized);
    normalized.sort((a, b) => a.start.compareTo(b.start));
    return normalized;
  }

  static List<DayPlannerEntry> _normalizeLunchBoundary(
    List<DayPlannerEntry> entries,
  ) {
    final lunchEntry = entries.cast<DayPlannerEntry?>().firstWhere(
      (entry) => entry?.id == 'break-lunch',
      orElse: () => null,
    );
    if (lunchEntry == null) return entries;
    var lunch = lunchEntry;

    final latestLunchStart = DateTime(
      lunch.start.year,
      lunch.start.month,
      lunch.start.day,
      13,
      30,
    );
    final precedingBreak = entries
        .where(
          (entry) =>
              _isBreakLikeEntry(entry) && entry.end.isBefore(lunch.start),
        )
        .fold<DayPlannerEntry?>(null, (candidate, entry) {
          if (candidate == null || entry.end.isAfter(candidate.end)) {
            return entry;
          }
          return candidate;
        });
    if (precedingBreak != null &&
        lunch.start.difference(precedingBreak.end) < const Duration(hours: 1)) {
      final shiftedStart = precedingBreak.end.add(const Duration(hours: 1));
      final shiftedEnd = shiftedStart.add(const Duration(minutes: 30));
      final conflictsWithPlanningEntry = entries.any(
        (entry) =>
            entry.id != lunch.id &&
            _occupiesPlanningTime(entry) &&
            shiftedStart.isBefore(entry.end) &&
            shiftedEnd.isAfter(entry.start),
      );
      if (!shiftedStart.isAfter(latestLunchStart) &&
          !conflictsWithPlanningEntry) {
        lunch = lunch.copyWith(start: shiftedStart, end: shiftedEnd);
      }
    }

    final result = entries
        .where((entry) {
          if (entry.title != 'Recovery break') return true;
          return lunch.start.difference(entry.end) > const Duration(hours: 1) ||
              entry.end.isAfter(lunch.start);
        })
        .map((entry) => entry.id == lunch.id ? lunch : entry)
        .toList();

    final previous = result
        .where(
          (entry) =>
              entry.type == 'task' &&
              !entry.end.isAfter(lunch.start) &&
              lunch.start.difference(entry.end) <= const Duration(minutes: 30),
        )
        .fold<DayPlannerEntry?>(null, (candidate, entry) {
          if (candidate == null || entry.start.isAfter(candidate.start)) {
            return entry;
          }
          return candidate;
        });
    if (previous == null) return result;

    final resultIndex = result.indexWhere((entry) => entry.id == previous.id);
    if (resultIndex < 0) return result;
    result[resultIndex] = previous.copyWith(end: lunch.start);
    return result;
  }

  static List<DayPlannerEntry> _removeBreakCalendarOverlaps(
    List<DayPlannerEntry> entries,
  ) {
    final calendarEntries = entries.where(
      (entry) => entry.type == 'calendar' && _occupiesPlanningTime(entry),
    );
    return entries.where((entry) {
      if (!_isBreakLikeEntry(entry)) return true;
      return !calendarEntries.any(
        (calendar) =>
            entry.start.isBefore(calendar.end) &&
            entry.end.isAfter(calendar.start),
      );
    }).toList();
  }

  static List<DayPlannerEntry> _removeFocusTaskOverlaps(
    List<DayPlannerEntry> entries,
  ) {
    final tasks = entries
        .where(
          (entry) =>
              !entry.isConcurrent &&
              (entry.type == 'task' ||
                  entry.type == 'admin' ||
                  (entry.type == 'calendar' && _occupiesPlanningTime(entry))),
        )
        .toList();
    return entries.where((entry) {
      if (entry.type != 'focus') return true;
      return !tasks.any(
        (task) =>
            entry.start.isBefore(task.end) && entry.end.isAfter(task.start),
      );
    }).toList();
  }

  static List<DayPlannerEntry> _removeFocusOverlaps(
    List<DayPlannerEntry> entries,
  ) {
    return entries.where((entry) {
      if (entry.type != 'focus' || entry.isAllDay) return true;
      return entries.every(
        (other) =>
            identical(entry, other) ||
            other.isAllDay ||
            other.isConcurrent ||
            !entry.start.isBefore(other.end) ||
            !entry.end.isAfter(other.start),
      );
    }).toList();
  }

  static List<DayPlannerEntry> _removeBreakConflicts(
    List<DayPlannerEntry> entries,
  ) {
    final result = <DayPlannerEntry>[];
    final sorted = List<DayPlannerEntry>.from(entries)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final entry in sorted) {
      final hasBreakConflict =
          _isBreakLikeEntry(entry) &&
          result.any(
            (previous) =>
                _isBreakLikeEntry(previous) &&
                entry.start.isBefore(
                  previous.end.add(const Duration(hours: 1)),
                ) &&
                entry.end.isAfter(previous.start),
          );
      if (hasBreakConflict) {
        if (_isLunchBreak(entry)) {
          result.removeWhere(
            (previous) =>
                _isBreakLikeEntry(previous) &&
                previous.end.add(const Duration(hours: 1)).isAfter(entry.start),
          );
        } else {
          continue;
        }
      }

      result.add(entry);
    }

    return result;
  }

  static List<DayPlannerEntry> _ensureOpeningAvailableTime(
    List<DayPlannerEntry> entries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    if (entries.any(
      (entry) =>
          entry.type == 'focus' &&
          entry.start.isAtSameMomentAs(dayStart) &&
          entry.subtitle == 'Opening focus session',
    )) {
      return entries;
    }
    final occupied =
        entries
            .where(
              (entry) =>
                  !entry.isAllDay &&
                  entry.type != 'buffer' &&
                  entry.type != 'focus' &&
                  entry.start.isBefore(dayEnd) &&
                  entry.end.isAfter(dayStart),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    if (occupied.isEmpty) {
      return entries;
    }

    final firstEntry = occupied.first;
    if (!firstEntry.start.isAtSameMomentAs(dayStart)) {
      final gapMinutes = firstEntry.start.difference(dayStart).inMinutes;
      if (gapMinutes >= PlannerBreakPolicy.minAvailableTimeMinutes) {
        final availableMinutes = gapMinutes.clamp(
          PlannerBreakPolicy.minAvailableTimeMinutes,
          PlannerBreakPolicy.maxAvailableTimeMinutes,
        );
        final block = DayPlannerEntry(
          id: 'buffer-open',
          title: 'Available Time',
          type: 'buffer',
          start: dayStart,
          end: dayStart.add(Duration(minutes: availableMinutes)),
          subtitle: 'Intentional free capacity',
        );
        final result = List<DayPlannerEntry>.from(entries)
          ..add(block)
          ..sort((a, b) => a.start.compareTo(b.start));
        return result;
      }
    }

    return entries;
  }

  static List<DayPlannerEntry> _fillGapsWithPlannerTime(
    List<DayPlannerEntry> entries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final occupied =
        entries
            .where(
              (entry) =>
                  !entry.isAllDay &&
                  entry.end.isAfter(entry.start) &&
                  entry.start.isBefore(dayEnd) &&
                  entry.end.isAfter(dayStart),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final result = List<DayPlannerEntry>.from(entries);
    var cursor = dayStart;

    for (final entry in occupied) {
      if (entry.start.isAfter(cursor)) {
        final gapStart = cursor;
        final gapEnd = entry.start;
        if (gapEnd.difference(gapStart) < const Duration(minutes: 15)) {
          cursor = gapEnd;
          continue;
        }
        final isOpeningGap =
            gapStart.isAtSameMomentAs(dayStart) &&
            !result.any(
              (candidate) =>
                  candidate.type != 'focus' &&
                  candidate.type != 'buffer' &&
                  candidate.start.isAtSameMomentAs(dayStart),
            );

        if (isOpeningGap &&
            gapEnd.difference(gapStart) >= const Duration(minutes: 30)) {
          final availableMinutes = gapEnd
              .difference(gapStart)
              .inMinutes
              .clamp(
                PlannerBreakPolicy.minAvailableTimeMinutes,
                PlannerBreakPolicy.maxAvailableTimeMinutes,
              );
          final availableEnd = gapStart.add(
            Duration(minutes: availableMinutes),
          );
          result.add(
            DayPlannerEntry(
              id: 'buffer-gap-${result.length}',
              title: 'Available Time',
              type: 'buffer',
              start: gapStart,
              end: availableEnd,
              subtitle: 'Intentional free capacity',
            ),
          );
          if (gapEnd.difference(availableEnd) >=
              const Duration(
                minutes: PlannerBreakPolicy.minAvailableTimeMinutes,
              )) {
            result.add(
              DayPlannerEntry(
                id: 'focus-gap-${result.length}',
                title: 'Focus Time',
                type: 'focus',
                start: availableEnd,
                end: gapEnd,
                subtitle: 'Filled planning gap',
              ),
            );
          }
        } else if (gapEnd.difference(gapStart) >=
            const Duration(
              minutes: PlannerBreakPolicy.minAvailableTimeMinutes,
            )) {
          result.add(
            DayPlannerEntry(
              id: 'focus-gap-${result.length}',
              title: 'Focus Time',
              type: 'focus',
              start: gapStart,
              end: gapEnd,
              subtitle: 'Filled planning gap',
            ),
          );
        }
      }
      cursor = entry.end.isAfter(cursor) ? entry.end : cursor;
    }

    if (dayEnd.isAfter(cursor)) {
      final gapStart = cursor;
      final gapEnd = dayEnd;
      if (gapStart.isAtSameMomentAs(dayStart) &&
          gapEnd.difference(gapStart) >= const Duration(minutes: 30)) {
        final availableMinutes = gapEnd
            .difference(gapStart)
            .inMinutes
            .clamp(
              PlannerBreakPolicy.minAvailableTimeMinutes,
              PlannerBreakPolicy.maxAvailableTimeMinutes,
            );
        final availableEnd = gapStart.add(Duration(minutes: availableMinutes));
        result.add(
          DayPlannerEntry(
            id: 'buffer-gap-${result.length}',
            title: 'Available Time',
            type: 'buffer',
            start: gapStart,
            end: availableEnd,
            subtitle: 'Intentional free capacity',
          ),
        );
        if (gapEnd.difference(availableEnd) >=
            const Duration(
              minutes: PlannerBreakPolicy.minAvailableTimeMinutes,
            )) {
          result.add(
            DayPlannerEntry(
              id: 'focus-gap-${result.length}',
              title: 'Focus Time',
              type: 'focus',
              start: availableEnd,
              end: gapEnd,
              subtitle: 'Filled planning gap',
            ),
          );
        }
      } else if (gapEnd.difference(gapStart) >=
          const Duration(minutes: PlannerBreakPolicy.minAvailableTimeMinutes)) {
        result.add(
          DayPlannerEntry(
            id: 'focus-gap-${result.length}',
            title: 'Focus Time',
            type: 'focus',
            start: gapStart,
            end: gapEnd,
            subtitle: 'Filled planning gap',
          ),
        );
      }
    }

    return result;
  }

  static List<DayPlannerEntry> _extendShortGaps(
    List<DayPlannerEntry> entries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final result = List<DayPlannerEntry>.from(entries);
    final occupied =
        result
            .where(
              (entry) =>
                  _occupiesPlanningTime(entry) &&
                  (entry.type != 'movement' || !entry.isConcurrent),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    for (var index = 1; index < occupied.length; index++) {
      final previous = occupied[index - 1];
      final current = occupied[index];
      final previousEnd = previous.end.isAfter(dayEnd) ? dayEnd : previous.end;
      final currentStart = current.start.isBefore(dayStart)
          ? dayStart
          : current.start;
      final gap = currentStart.difference(previousEnd);
      final canExtend =
          previous.type == 'task' ||
          previous.type == 'break' ||
          (previous.type == 'movement' &&
              !previous.isConcurrent &&
              !previous.title.toLowerCase().contains('walk'));
      final crossesTask = previous.type != 'task' && current.type == 'task';
      if (canExtend &&
          !crossesTask &&
          gap > Duration.zero &&
          gap <= const Duration(minutes: 15)) {
        final resultIndex = result.indexWhere(
          (entry) => entry.id == previous.id,
        );
        if (resultIndex >= 0) {
          result[resultIndex] = previous.copyWith(end: currentStart);
          occupied[index - 1] = result[resultIndex];
        }
      }
    }
    return result;
  }

  /// Applies user-provided manual time/lock overrides on top of already-
  /// scheduled entries. Public so a frozen (persisted) plan snapshot can have
  /// overrides re-applied without re-running the scheduler.
  /// scheduled entries. Public so a frozen (persisted) plan snapshot can have
  /// overrides re-applied without re-running the scheduler.
  static List<DayPlannerEntry> applyEntryOverrides(
    List<DayPlannerEntry> entries,
    Map<String, PlannerEntryOverride> overrides,
    DateTime dayStart,
    DateTime dayEnd, {
    Task? Function(String id)? resolveTask,
  }) {
    return entries.map((entry) {
      final override = overrides[entry.id];
      if (override == null) {
        return entry;
      }
      var newStart = override.startMinutes != null
          ? _dateAtMinutes(dayStart, override.startMinutes!)
          : entry.start;
      var newEnd = override.endMinutes != null
          ? _dateAtMinutes(dayStart, override.endMinutes!)
          : entry.end;
      if (newStart.isBefore(dayStart)) newStart = dayStart;
      if (newEnd.isAfter(dayEnd)) newEnd = dayEnd;
      if (!newEnd.isAfter(newStart)) {
        newEnd = newStart.add(const Duration(minutes: 5));
      }
      if (entry.type != 'calendar' && entry.type != 'buffer') {
        final snappedDuration = _snapDurationToFiveMinutes(
          newEnd.difference(newStart),
        );
        newEnd = newStart.add(snappedDuration);
        if (newEnd.isAfter(dayEnd)) {
          newEnd = dayEnd;
        }
      }
      var updated = entry.copyWith(
        start: newStart,
        end: newEnd,
        isLocked: override.locked,
      );
      final taskId = override.taskId;
      final customTitle = override.customTitle;
      if (taskId != null) {
        final resolvedTask = resolveTask?.call(taskId);
        if (resolvedTask != null) {
          updated = updated.copyWith(
            title: resolvedTask.task,
            subtitle: _taskSubtitle(resolvedTask),
            type: 'task',
            task: resolvedTask,
            relatedTaskIds: [resolvedTask.id],
          );
        }
      } else if (customTitle != null && customTitle.trim().isNotEmpty) {
        final trimmedTitle = customTitle.trim();
        final isFocusTime = trimmedTitle.toLowerCase() == 'focus time';
        updated = updated.copyWith(
          title: isFocusTime ? 'Focus Time' : trimmedTitle,
          subtitle: isFocusTime ? 'Filled planning gap' : 'Personal block',
          type: isFocusTime ? 'focus' : 'personal',
          clearTask: true,
          relatedTaskIds: const <String>[],
        );
      }
      return updated;
    }).toList();
  }

  static DateTime _dateAtMinutes(DateTime day, int minutes) {
    final dayOffset = minutes ~/ (24 * 60);
    final minuteOfDay = minutes % (24 * 60);
    return DateTime(
      day.year,
      day.month,
      day.day + dayOffset,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
  }

  static DayPlannerEntry? _findConcurrentEntry(
    List<DayPlannerEntry> occupied,
    Duration duration,
    String mode,
    Set<String> preferredConcurrentEntryIds,
    Set<String> excludedConcurrentEntryIds,
    DateTime dayStart,
    DateTime dayEnd, {
    required DateTime target,
  }) {
    DayPlannerEntry? best;
    Duration? bestDistance;
    for (final entry in occupied) {
      if (entry.isAllDay ||
          entry.isConcurrent ||
          entry.category == PlannerEventCategory.informational) {
        continue;
      }
      if (excludedConcurrentEntryIds.contains(entry.id)) {
        continue;
      }
      if (!entry.start.isBefore(dayEnd) || !entry.end.isAfter(dayStart)) {
        continue;
      }
      if (entry.end.difference(entry.start) < duration) continue;
      final isPreferred = preferredConcurrentEntryIds.contains(entry.id);
      final canPairCalendar =
          entry.type == 'calendar' &&
          ((mode != 'office' &&
                  (isPreferred || preferredConcurrentEntryIds.isEmpty)) ||
              (mode == 'office' &&
                  isPreferred &&
                  entry.subtitle?.toLowerCase().contains('work') == true));
      final canPairTask = entry.type == 'task' && mode != 'office';
      // Generic Focus Time is unclaimed flexible time, not a real
      // commitment, so standing/walking can overlay it too on WFH days.
      final canPairFocus = entry.type == 'focus' && mode != 'office';
      if ((!canPairCalendar && !canPairTask && !canPairFocus) ||
          _overlapsPersonal(entry.start, entry.end, occupied) ||
          !_concurrentWindowIsExclusive(
            entry,
            occupied,
            duration,
            dayStart,
            dayEnd,
          )) {
        continue;
      }
      final distance = entry.start.difference(target).abs();
      if (bestDistance == null || distance < bestDistance) {
        best = entry;
        bestDistance = distance;
      }
    }
    return best;
  }

  static bool _overlapsPersonal(
    DateTime start,
    DateTime end,
    Iterable<DayPlannerEntry> entries,
  ) {
    return entries.any(
      (entry) =>
          entry.type == 'personal' &&
          start.isBefore(entry.end) &&
          end.isAfter(entry.start),
    );
  }

  static bool _concurrentWindowIsExclusive(
    DayPlannerEntry selectedEntry,
    List<DayPlannerEntry> occupied,
    Duration duration,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final windowStart = selectedEntry.start.isBefore(dayStart)
        ? dayStart
        : selectedEntry.start;
    final windowEnd = windowStart.add(duration);
    if (windowEnd.isAfter(dayEnd) || windowEnd.isAfter(selectedEntry.end)) {
      return false;
    }
    return occupied.every((entry) {
      if (identical(entry, selectedEntry) || entry.isAllDay) return true;
      if (entry.type == 'personal') return true;
      return !entry.start.isBefore(windowEnd) ||
          !entry.end.isAfter(windowStart);
    });
  }

  static DateTime? _findNearestFreeStart(
    List<DayPlannerEntry> occupied,
    Duration duration,
    DateTime target,
    DateTime dayStart,
    DateTime dayEnd, {
    DateTime? earliestStart,
    DateTime? latestAllowedStart,
    Duration minimumGap = Duration.zero,
    String? separateFromType,
    Set<String> separateFromTypes = const <String>{},
    Map<String, Duration> minimumGapByType = const <String, Duration>{},
  }) {
    final boundaries = <DateTime>[dayStart, dayEnd];
    for (final entry in occupied) {
      if (!_occupiesPlanningTime(entry)) continue;
      final separation =
          minimumGapByType[entry.type] ??
          (entry.type == separateFromType ||
                  separateFromTypes.contains(entry.type)
              ? minimumGap
              : Duration.zero);
      if (entry.end.isAfter(dayStart) && entry.start.isBefore(dayEnd)) {
        boundaries.add(
          entry.start.subtract(separation).isBefore(dayStart)
              ? dayStart
              : entry.start.subtract(separation),
        );
        boundaries.add(
          entry.end.add(separation).isAfter(dayEnd)
              ? dayEnd
              : entry.end.add(separation),
        );
      }
    }
    boundaries.sort();

    DateTime? best;
    Duration? bestDistance;
    for (var index = 0; index < boundaries.length - 1; index++) {
      final gapStart = boundaries[index];
      final gapEnd = boundaries[index + 1];
      final effectiveGapStart =
          earliestStart != null && gapStart.isBefore(earliestStart)
          ? earliestStart
          : gapStart;
      if (gapEnd.difference(effectiveGapStart) < duration) continue;
      final latestStart = gapEnd.subtract(duration);
      final candidate = target.isBefore(effectiveGapStart)
          ? effectiveGapStart
          : target.isAfter(latestStart)
          ? latestStart
          : target;
      if (latestAllowedStart != null && candidate.isAfter(latestAllowedStart)) {
        continue;
      }
      if (occupied.any(
        (entry) =>
            _occupiesPlanningTime(entry) &&
            candidate.isBefore(entry.end) &&
            candidate.add(duration).isAfter(entry.start),
      )) {
        continue;
      }
      final distance = candidate.difference(target).abs();
      if (bestDistance == null || distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  static DateTime? _snapToAvailableStart({
    required List<DayPlannerEntry> occupied,
    required DateTime start,
    required Duration duration,
    required TimeGrid timeGrid,
    required DateTime dayEnd,
  }) {
    final interval = Duration(
      minutes: timeGrid == TimeGrid.fifteenMinutes ? 15 : 30,
    );
    var candidate = PlannerExecutionService.snapToGrid(start, timeGrid);
    while (candidate.add(duration).isBefore(dayEnd) ||
        candidate.add(duration).isAtSameMomentAs(dayEnd)) {
      final overlaps = occupied.any(
        (entry) =>
            _occupiesPlanningTime(entry) &&
            candidate.isBefore(entry.end) &&
            candidate.add(duration).isAfter(entry.start),
      );
      if (!overlaps) return candidate;
      candidate = candidate.add(interval);
    }
    return null;
  }

  static Duration _estimateTaskDuration(Task task) {
    if (task.absolutePriority &&
        task.effortMinutes != null &&
        task.effortMinutes! > 0) {
      return Duration(minutes: task.effortMinutes!);
    }

    if (task.nextSessionEffortMinutes != null &&
        task.nextSessionEffortMinutes! > 0) {
      return Duration(minutes: task.nextSessionEffortMinutes!);
    }

    if (task.effortMinutes != null && task.effortMinutes! > 0) {
      return Duration(minutes: task.effortMinutes!);
    }

    return switch (task.priority) {
      'high' => const Duration(minutes: 75),
      'medium' => const Duration(minutes: 60),
      'low' => const Duration(minutes: 45),
      _ => const Duration(minutes: 60),
    };
  }

  static Duration _snapDurationToFiveMinutes(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      return const Duration(minutes: 5);
    }
    final snappedMinutes = ((minutes / 5).round() * 5).clamp(5, 24 * 60);
    return Duration(minutes: snappedMinutes);
  }

  static DateTime _normalizedEventEnd(
    DateTime start,
    DateTime? rawEnd,
    bool isAllDay,
  ) {
    if (rawEnd == null) {
      return isAllDay
          ? start.add(const Duration(days: 1))
          : start.add(_minimumEventDuration);
    }
    if (!rawEnd.isAfter(start)) {
      return start.add(_minimumEventDuration);
    }
    return rawEnd;
  }

  static String _priorityLabel(String priority) {
    return switch (priority) {
      'high' => 'High priority',
      'medium' => 'Medium priority',
      'low' => 'Low priority',
      _ => 'Priority task',
    };
  }

  static String _taskSubtitle(Task task) {
    final parts = <String>[_priorityLabel(task.priority)];
    if (task.nextSessionEffortMinutes != null &&
        task.nextSessionEffortMinutes! > 0) {
      parts.add('Next ${_formatEffortLabel(task.nextSessionEffortMinutes!)}');
    }
    if (task.effortMinutes != null && task.effortMinutes! > 0) {
      parts.add('Total ${_formatEffortLabel(task.effortMinutes!)}');
    }
    return parts.join(' • ');
  }

  static String _formatEffortLabel(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }

    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainder}m';
  }
}
