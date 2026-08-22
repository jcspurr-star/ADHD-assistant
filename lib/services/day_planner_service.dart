import '../models/activity_recommendation.dart';
import '../models/task.dart';
import 'movement_recommendation_service.dart';
import 'one_drive_sync_service.dart';
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
    this.isAllDay = false,
    this.isConcurrent = false,
    this.isLocked = false,
    this.executionState = ExecutionState.pending,
    this.category = PlannerEventCategory.planned,
    this.isZeroDuration = false,
  });

  final String id;
  final String title;
  final String type;
  final DateTime start;
  final DateTime end;
  final String? subtitle;
  final Task? task;
  final bool isAllDay;
  final bool isConcurrent;
  // True when the user manually pinned this entry's time; the planner won't move it.
  final bool isLocked;
  final ExecutionState executionState;
  final PlannerEventCategory category;
  final bool isZeroDuration;

  DayPlannerEntry copyWith({
    DateTime? start,
    DateTime? end,
    bool? isLocked,
    ExecutionState? executionState,
    PlannerEventCategory? category,
    bool? isZeroDuration,
  }) {
    return DayPlannerEntry(
      id: id,
      title: title,
      type: type,
      start: start ?? this.start,
      end: end ?? this.end,
      subtitle: subtitle,
      task: task,
      isAllDay: isAllDay,
      isConcurrent: isConcurrent,
      isLocked: isLocked ?? this.isLocked,
      executionState: executionState ?? this.executionState,
      category: category ?? this.category,
      isZeroDuration: isZeroDuration ?? this.isZeroDuration,
    );
  }
}

/// A user-provided manual time override for a planner entry, keyed by entry id.
class PlannerEntryOverride {
  const PlannerEntryOverride({
    this.startMinutes,
    this.endMinutes,
    this.locked = false,
  });

  /// Minutes since midnight for the overridden start time, or null to keep the planned start.
  final int? startMinutes;

  /// Minutes since midnight for the overridden end time, or null to keep the planned end.
  final int? endMinutes;
  final bool locked;
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
  });

  final List<Task> tasks;
  final Duration duration;
  final int sessionIndex;
  final int sessionCount;
  final bool isAdmin;

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
  static const Duration _defaultBreak = Duration(minutes: 10);
  static const Duration _defaultLunchBreak = Duration(minutes: 30);
  static const Duration _minimumEventDuration = Duration(minutes: 5);

  static bool _occupiesPlanningTime(DayPlannerEntry entry) {
    return !entry.isAllDay &&
        entry.type != 'buffer' &&
        entry.category != PlannerEventCategory.informational &&
        !(entry.type == 'calendar' && entry.isZeroDuration);
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

    final targetDay = DateTime(day.year, day.month, day.day);
    final doDate = _parseTaskDate(task.doDate);
    if (doDate != null) {
      final normalizedDoDate = DateTime(doDate.year, doDate.month, doDate.day);
      return !normalizedDoDate.isAfter(targetDay);
    }

    final subtaskDate = _currentSubtaskPlanningDate(task, day);
    if (subtaskDate != null) {
      return true;
    }

    return _parseTaskDate(task.dueDate) != null;
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

  static DateTime? _currentSubtaskPlanningDate(Task task, DateTime day) {
    final targetDay = DateTime(day.year, day.month, day.day);
    DateTime? firstFutureDate;
    for (final subtask in task.subtasks) {
      if (subtask.done == true) {
        continue;
      }

      final date = _parseTaskDate(subtask.doDate);
      if (date == null) {
        continue;
      }

      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!normalizedDate.isAfter(targetDay)) {
        return normalizedDate;
      }

      firstFutureDate ??= normalizedDate;
    }
    return firstFutureDate;
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
    Set<String> nonBlockingCalendarEventIds = const <String>{},
    Map<String, PlannerEntryOverride> entryOverrides =
        const <String, PlannerEntryOverride>{},
    List<PersonalPlannerBlock> personalBlocks = const <PersonalPlannerBlock>[],
    Map<String, ExecutionState> executionStates =
        const <String, ExecutionState>{},
    TimeGrid timeGrid = TimeGrid.fifteenMinutes,
  }) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final normalizedStart = workdayStartMinutes.clamp(0, 23 * 60 + 59);
    final normalizedEnd = workdayEndMinutes.clamp(1, 24 * 60);
    final dayStart = _dateAtMinutes(day, normalizedStart);
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
        final isZeroDuration =
            !event.isAllDay &&
            event.end != null &&
            !event.end!.toLocal().isAfter(event.start!.toLocal());
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
            category: event.isAllDay
                ? PlannerEventCategory.informational
                : nonBlockingCalendarEventIds.contains('calendar-${event.id}')
                ? PlannerEventCategory.informational
                : PlannerEventCategory.fixed,
            isZeroDuration: isZeroDuration,
          ),
        );
      }

      cursor = adjustedEnd.isAfter(cursor) ? adjustedEnd : cursor;
      if (cursor.isAfter(dayEnd)) cursor = dayEnd;
    }

    if (!isWeekend) {
      final lunchEntry = _placeLunch(entries, dayStart, dayEnd);
      if (lunchEntry != null) entries.add(lunchEntry);
    }

    if (isWeekend) {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        entries[index] = entry.copyWith(
          executionState: executionStates[entry.id] ?? ExecutionState.pending,
        );
      }
      entries.sort((a, b) => a.start.compareTo(b.start));
      return DayPlannerResult(
        entries: entries,
        summary: entries.isEmpty
            ? 'Weekend: no activities planned.'
            : 'Weekend: calendar items only.',
        rolloverTasks: const <Task>[],
      );
    }

    final prioritizedTasks = _prioritizeTasks(tasks, day);
    final actionableTasks = prioritizedTasks.map((item) => item.task).toList();

    final plannedTaskEntries = <DayPlannerEntry>[];
    final dailyCapacity = _calculateDailyCapacity(entries, dayStart, dayEnd);
    var remainingTaskCapacity = dailyCapacity.availableMinutes;
    final sessions = _createTaskSessions(prioritizedTasks);
    final scheduledTaskIds = <String>{};

    for (
      var index = 0;
      index < sessions.length && remainingTaskCapacity > 0;
      index++
    ) {
      final session = sessions[index];
      final duration = session.duration;
      if (duration.inMinutes > remainingTaskCapacity) break;
      final target = dayStart.add(
        Duration(
          minutes: sessions.length == 1
              ? 0
              : (dayEnd.difference(dayStart).inMinutes *
                        (index + 1) /
                        (sessions.length + 1))
                    .round(),
        ),
      );
      final placedStart = _findNearestFreeStart(
        [...entries, ...plannedTaskEntries],
        duration,
        target,
        dayStart,
        dayEnd,
      );
      if (placedStart == null) continue;

      final snappedStart = PlannerExecutionService.snapToGrid(
        placedStart,
        timeGrid,
      );
      final task = session.primaryTask;
      plannedTaskEntries.add(
        DayPlannerEntry(
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
          start: snappedStart,
          end: snappedStart.add(duration),
          subtitle: session.isAdmin
              ? 'Includes: ${session.tasks.map((task) => task.task).join(', ')}'
              : _taskSubtitle(task),
          task: task,
          category: PlannerEventCategory.planned,
        ),
      );
      remainingTaskCapacity -= duration.inMinutes;
      scheduledTaskIds.addAll(session.tasks.map((task) => task.id));
    }
    final cumulativeBreaks = _insertCumulativeFocusBreaks(
      [...entries, ...plannedTaskEntries],
      dayStart,
      dayEnd,
    );
    plannedTaskEntries.addAll(cumulativeBreaks);

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
    final movementEntries = _placeMovementEvents(
      day: day,
      dayContext: dayContext,
      occupiedEntries: merged,
      dayStart: dayStart,
      dayEnd: dayEnd,
      preferredConcurrentEntryIds: preferredConcurrentEntryIds,
      timeGrid: timeGrid,
    );
    merged.addAll(movementEntries);
    final mergedWithShortGaps = _extendShortGaps(merged, dayStart, dayEnd);
    merged
      ..clear()
      ..addAll(mergedWithShortGaps)
      ..addAll(_buildOpenBlocks(mergedWithShortGaps, dayStart, dayEnd));
    final overridden = entryOverrides.isEmpty
        ? merged
        : _applyEntryOverrides(merged, entryOverrides, dayStart, dayEnd);
    final normalizedEntries = _validatePlan(
      _removeTaskOverlaps(overridden),
      dayStart,
      dayEnd,
    );
    for (var index = 0; index < normalizedEntries.length; index++) {
      final entry = normalizedEntries[index];
      normalizedEntries[index] = entry.copyWith(
        executionState: executionStates[entry.id] ?? ExecutionState.pending,
      );
    }
    normalizedEntries.sort((a, b) => a.start.compareTo(b.start));

    final summarySegments = <String>[];
    if (plannedTaskEntries.isNotEmpty) {
      summarySegments.add(
        '${plannedTaskEntries.where((entry) => entry.type == 'task').length} focus block${plannedTaskEntries.where((entry) => entry.type == 'task').length == 1 ? '' : 's'}',
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

  static List<_PrioritizedTask> _prioritizeTasks(
    List<Task> tasks,
    DateTime day,
  ) {
    final targetDay = DateTime(day.year, day.month, day.day);
    final priorityScore = {'high': 40, 'medium': 20, 'low': 0};
    final scored = tasks.where((task) => _isTaskEligibleForDay(task, day)).map((
      task,
    ) {
      final due = _parseTaskDate(task.dueDate);
      final doDate = _parseTaskDate(task.doDate);
      final planningDate = doDate ?? due;
      final overdueDays = due == null
          ? 0
          : targetDay.difference(DateTime(due.year, due.month, due.day)).inDays;
      final urgency = planningDate == null
          ? 0
          : (targetDay
                        .difference(
                          DateTime(
                            planningDate.year,
                            planningDate.month,
                            planningDate.day,
                          ),
                        )
                        .inDays >=
                    0
                ? 30
                : 0);
      final rolloverBonus =
          planningDate != null && planningDate.isBefore(targetDay) ? 15 : 0;
      final contextPenalty =
          task.category.trim().isEmpty ||
              task.category.trim().toLowerCase() == 'none'
          ? 0
          : -5;
      return _PrioritizedTask(
        task: task,
        score:
            (priorityScore[task.priority] ?? 20) +
            (overdueDays > 0 ? 35 + overdueDays.clamp(0, 14) : 0) +
            urgency +
            rolloverBonus +
            contextPenalty.toDouble(),
      );
    }).toList();
    scored.sort((a, b) {
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

  static List<_TaskSession> _createTaskSessions(
    List<_PrioritizedTask> prioritizedTasks,
  ) {
    final sessions = <_TaskSession>[];
    final adminGroups = _groupAdminTasks(prioritizedTasks);
    final adminTasks = adminGroups.expand((group) => group).toSet();
    for (final item in prioritizedTasks) {
      if (adminTasks.contains(item)) continue;
      final minutes = _estimateTaskDuration(item.task).inMinutes;
      if (minutes <= 90) {
        sessions.add(
          _TaskSession(
            tasks: [item.task],
            duration: Duration(minutes: minutes.clamp(25, 90)),
          ),
        );
        continue;
      }
      final splitCount = (minutes / 60).ceil();
      var remaining = minutes;
      for (var index = 1; index <= splitCount; index++) {
        final sessionsLeft = splitCount - index;
        var sessionMinutes = remaining > 60 ? 60 : remaining;
        if (sessionsLeft > 0 && remaining - sessionMinutes < 25) {
          sessionMinutes = remaining - (sessionsLeft * 45);
        }
        sessionMinutes = sessionMinutes.clamp(25, 60);
        sessions.add(
          _TaskSession(
            tasks: [item.task],
            duration: Duration(minutes: sessionMinutes),
            sessionIndex: index,
            sessionCount: splitCount,
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
      sessions.add(
        _TaskSession(
          tasks: group.map((item) => item.task).toList(),
          duration: Duration(minutes: minutes.clamp(25, 60)),
          isAdmin: true,
        ),
      );
    }
    return sessions;
  }

  static List<DayPlannerEntry> _insertCumulativeFocusBreaks(
    List<DayPlannerEntry> existingEntries,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final focusEntries =
        existingEntries
            .where((entry) => entry.type == 'task' || entry.type == 'admin')
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final occupied = List<DayPlannerEntry>.from(existingEntries);
    final breaks = <DayPlannerEntry>[];
    var cumulativeFocusMinutes = 0;
    var breakIndex = 0;
    for (final focusEntry in focusEntries) {
      cumulativeFocusMinutes += focusEntry.end
          .difference(focusEntry.start)
          .inMinutes;
      final breakMinutes = cumulativeFocusMinutes >= 120
          ? 15
          : cumulativeFocusMinutes >= 90
          ? 10
          : cumulativeFocusMinutes >= 50
          ? 5
          : 0;
      if (breakMinutes == 0) continue;
      final duration = Duration(minutes: breakMinutes);
      final placedStart = _findNearestFreeStart(
        occupied,
        duration,
        focusEntry.end,
        dayStart,
        dayEnd,
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
      breaks.add(breakEntry);
      occupied.add(breakEntry);
      cumulativeFocusMinutes = 0;
      breakIndex++;
    }
    return breaks;
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
    required TimeGrid timeGrid,
  }) {
    if (dayContext == null) {
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
    final blockDurations = mode == 'home'
        ? [
            (standingBlockMinutes, 'Stand at your desk', 'Standing desk'),
            (walkingBlockMinutes, 'Walk while you work', 'Walking pad'),
            (standingBlockMinutes, 'Stand at your desk', 'Standing desk'),
            (walkingBlockMinutes, 'Walk while you work', 'Walking pad'),
          ]
        : [
            (walkingBlockMinutes, 'Walk break', 'Office movement'),
            (walkingBlockMinutes, 'Walk break', 'Office movement'),
            (walkingBlockMinutes, 'Walk break', 'Office movement'),
          ];

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
      final duration = _snapDurationToFiveMinutes(
        Duration(minutes: block.$2 == 'Walk break' ? 15 : block.$1),
      );
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
          final movementTitle = mode == 'office'
              ? 'Walk while you work'
              : block.$2;
          entries.add(
            DayPlannerEntry(
              id: 'movement-$mode-${entries.length}',
              title: movementTitle,
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
        minimumGap: const Duration(minutes: 30),
        separateFromTypes: const {'movement', 'break'},
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
      if (entry.start.difference(cursor) > const Duration(minutes: 30)) {
        blocks.add(
          DayPlannerEntry(
            id: 'buffer-${blocks.length}',
            title: 'Available Time',
            type: 'buffer',
            start: cursor,
            end: entry.start,
            subtitle: 'Free time for a quick task or reset',
          ),
        );
      }
      if (entry.end.isAfter(cursor)) cursor = entry.end;
    }
    if (dayEnd.difference(cursor) > const Duration(minutes: 30)) {
      blocks.add(
        DayPlannerEntry(
          id: 'buffer-${blocks.length}',
          title: 'Available Time',
          type: 'buffer',
          start: cursor,
          end: dayEnd,
          subtitle: 'Free time for the rest of the day',
        ),
      );
    }
    return blocks;
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
    final target = dayStart.add(
      Duration(minutes: dayEnd.difference(dayStart).inMinutes ~/ 2),
    );
    final start = _findNearestFreeStart(
      fixedEntries,
      duration,
      target,
      dayStart,
      dayEnd,
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
        if (current.type == 'buffer' || !current.start.isBefore(task.start)) {
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
    return entries.where((entry) {
      if (entry.isAllDay) return true;
      return entry.end.isAfter(entry.start);
    }).toList();
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
          (previous.type == 'movement' && !previous.isConcurrent);
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

  static bool _intervalIsFree(
    Iterable<DayPlannerEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    return entries.every(
      (entry) =>
          !_occupiesPlanningTime(entry) ||
          !start.isBefore(entry.end) ||
          !end.isAfter(entry.start),
    );
  }

  static List<DayPlannerEntry> _applyEntryOverrides(
    List<DayPlannerEntry> entries,
    Map<String, PlannerEntryOverride> overrides,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
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
      return entry.copyWith(
        start: newStart,
        end: newEnd,
        isLocked: override.locked,
      );
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
      if (!entry.start.isBefore(dayEnd) || !entry.end.isAfter(dayStart)) {
        continue;
      }
      if (entry.end.difference(entry.start) < duration) continue;
      final isPreferred = preferredConcurrentEntryIds.contains(entry.id);
      if (entry.type == 'calendar' &&
          ((mode != 'office' &&
                  (isPreferred || preferredConcurrentEntryIds.isEmpty)) ||
              (mode == 'office' &&
                  isPreferred &&
                  entry.subtitle?.toLowerCase().contains('work') == true)) &&
          !_intervalOverlapsPersonal(entry.start, entry.end, occupied) &&
          _concurrentWindowIsExclusive(
            entry,
            occupied,
            duration,
            dayStart,
            dayEnd,
          )) {
        final distance = entry.start.difference(target).abs();
        if (bestDistance == null || distance < bestDistance) {
          best = entry;
          bestDistance = distance;
        }
      }
      if (entry.type == 'task' &&
          mode != 'office' &&
          !_intervalOverlapsPersonal(entry.start, entry.end, occupied) &&
          _concurrentWindowIsExclusive(
            entry,
            occupied,
            duration,
            dayStart,
            dayEnd,
          )) {
        final distance = entry.start.difference(target).abs();
        if (bestDistance == null || distance < bestDistance) {
          best = entry;
          bestDistance = distance;
        }
      }
    }
    return best;
  }

  static DateTime _taskStartAfterCalendarReset(
    List<DayPlannerEntry> entries,
    DateTime currentTime,
    DateTime target,
    DateTime dayEnd,
  ) {
    var earliest = currentTime;
    for (final entry in entries) {
      if (entry.type != 'calendar' || entry.isAllDay) continue;
      if (entry.end.isAfter(earliest) && !entry.end.isAfter(target)) {
        earliest = entry.end.add(_defaultBreak);
      }
    }
    return earliest.isAfter(dayEnd) ? dayEnd : earliest;
  }

  static bool _intervalOverlapsPersonal(
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
      if (identical(entry, selectedEntry) || entry.isAllDay) {
        return true;
      }
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
    Duration minimumGap = Duration.zero,
    String? separateFromType,
    Set<String> separateFromTypes = const <String>{},
  }) {
    final boundaries = <DateTime>[dayStart, dayEnd];
    for (final entry in occupied) {
      if (!_occupiesPlanningTime(entry)) continue;
      final separation =
          entry.type == separateFromType ||
              separateFromTypes.contains(entry.type)
          ? minimumGap
          : Duration.zero;
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

  static bool _calendarAllowsConcurrentMovement(String title, String mode) {
    final normalized = title.toLowerCase();
    const sharedMeetingWords = [
      'call',
      'catch up',
      'catch-up',
      'check-in',
      'check in',
      'one to one',
      '1:1',
      'stand-up',
      'stand up',
      'sync',
      'review',
      'interview',
      'webinar',
      'briefing',
    ];
    if (!sharedMeetingWords.any(normalized.contains)) return false;
    if (mode == 'office') {
      return normalized.contains('call') ||
          normalized.contains('catch') ||
          normalized.contains('1:1') ||
          normalized.contains('check');
    }
    return true;
  }

  static bool _taskAllowsConcurrentMovement(String title) {
    final normalized = title.toLowerCase();
    const lowLoadTaskWords = [
      'call',
      'phone',
      'listen',
      'read',
      'inbox',
      'admin',
      'file',
      'sort',
    ];
    return lowLoadTaskWords.any(normalized.contains);
  }

  static Duration _estimateTaskDuration(Task task) {
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
