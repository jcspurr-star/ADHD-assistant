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

  DayPlannerEntry copyWith({
    DateTime? start,
    DateTime? end,
    bool? isLocked,
    ExecutionState? executionState,
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

class DayPlannerResult {
  DayPlannerResult({
    required this.entries,
    required this.summary,
    this.recommendations = const <ActivityRecommendation>[],
  });

  final List<DayPlannerEntry> entries;
  final String summary;
  final List<ActivityRecommendation> recommendations;
}

class DayPlannerService {
  static const Duration _defaultBreak = Duration(minutes: 10);
  static const Duration _defaultLunchBreak = Duration(minutes: 20);
  static const Duration _minimumEventDuration = Duration(minutes: 5);

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
    Map<String, PlannerEntryOverride> entryOverrides =
        const <String, PlannerEntryOverride>{},
    Map<String, ExecutionState> executionStates =
        const <String, ExecutionState>{},
  }) {
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

      if (adjustedStart.isAfter(cursor)) {
        final gapDuration = adjustedStart.difference(cursor);
        if (gapDuration.inMinutes >= 45) {
          entries.add(
            DayPlannerEntry(
              id: 'buffer-${entries.length}',
              title: 'Open block',
              type: 'buffer',
              start: cursor,
              end: adjustedStart,
              subtitle: 'Free time for a quick task or reset',
            ),
          );
        }
      }

      if (!adjustedStart.isAfter(adjustedEnd)) {
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
          ),
        );
      }

      cursor = adjustedEnd.isAfter(cursor) ? adjustedEnd : cursor;
    }

    if (cursor.isBefore(dayEnd)) {
      entries.add(
        DayPlannerEntry(
          id: 'buffer-${entries.length}',
          title: 'Open block',
          type: 'buffer',
          start: cursor,
          end: dayEnd,
          subtitle: 'Free time for the rest of the day',
        ),
      );
    }

    final actionableTasks =
        tasks.where((task) => _isTaskEligibleForDay(task, day)).toList()
          ..sort((a, b) {
            final aPlanningDate = _planningDateForTask(a);
            final bPlanningDate = _planningDateForTask(b);
            if (aPlanningDate != null && bPlanningDate != null) {
              final planningCompare = aPlanningDate.compareTo(bPlanningDate);
              if (planningCompare != 0) {
                return planningCompare;
              }
            } else if (aPlanningDate != null) {
              return -1;
            } else if (bPlanningDate != null) {
              return 1;
            }

            final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
            final aPriority = priorityOrder[a.priority] ?? 1;
            final bPriority = priorityOrder[b.priority] ?? 1;
            if (aPriority != bPriority) return aPriority.compareTo(bPriority);
            final aDue = a.dueDate;
            final bDue = b.dueDate;
            if (aDue == null && bDue == null) return 0;
            if (aDue == null) return 1;
            if (bDue == null) return -1;
            return aDue.compareTo(bDue);
          });

    final plannedTaskEntries = <DayPlannerEntry>[];
    DateTime currentTime = dayStart;
    bool hasShownLunchBreak = false;

    for (var index = 0; index < actionableTasks.length && index < 3; index++) {
      final task = actionableTasks[index];
      final estimatedDuration = _estimateTaskDuration(task);
      final duration = estimatedDuration.inMinutes <= 0
          ? const Duration(minutes: 5)
          : estimatedDuration;
      DateTime candidateStart = currentTime;
      DateTime? placedStart;

      for (final entry in entries.where(
        (entry) => entry.type == 'calendar' && !entry.isAllDay,
      )) {
        if (candidateStart.isBefore(entry.start) &&
                candidateStart.add(duration).isBefore(entry.start) ||
            candidateStart.add(duration).isAtSameMomentAs(entry.start)) {
          placedStart = candidateStart;
          break;
        }
        if (candidateStart.isBefore(entry.start) &&
            candidateStart.add(duration).isAfter(entry.start)) {
          candidateStart = entry.end;
          continue;
        }
        if (candidateStart.isAfter(entry.end)) {
          continue;
        }
        candidateStart = entry.end;
      }

      if (placedStart == null) {
        if (candidateStart.add(duration).isBefore(dayEnd) ||
            candidateStart.add(duration).isAtSameMomentAs(dayEnd)) {
          placedStart = candidateStart;
        }
      }

      if (placedStart != null) {
        final plannedEnd = placedStart.add(duration);
        if (plannedEnd.isAfter(dayEnd)) {
          continue;
        }

        plannedTaskEntries.add(
          DayPlannerEntry(
            id: 'task-${task.task}-$index',
            title: task.task,
            type: 'task',
            start: placedStart,
            end: plannedEnd,
            subtitle: _taskSubtitle(task),
            task: task,
          ),
        );

        currentTime = plannedEnd;

        if (index == 1 &&
            !hasShownLunchBreak &&
            plannedEnd.add(_defaultLunchBreak).isBefore(dayEnd)) {
          plannedTaskEntries.add(
            DayPlannerEntry(
              id: 'break-lunch-$index',
              title: 'Lunch / reset break',
              type: 'break',
              start: plannedEnd,
              end: plannedEnd.add(_defaultLunchBreak),
              subtitle: 'Take a longer pause before the next block',
            ),
          );
          currentTime = plannedEnd.add(_defaultLunchBreak);
          hasShownLunchBreak = true;
        } else if (plannedEnd.add(_defaultBreak).isBefore(dayEnd) &&
            index < 2) {
          plannedTaskEntries.add(
            DayPlannerEntry(
              id: 'break-$index',
              title: 'Short break',
              type: 'break',
              start: plannedEnd,
              end: plannedEnd.add(_defaultBreak),
              subtitle: 'Stretch, hydrate, or reset',
            ),
          );
          currentTime = plannedEnd.add(_defaultBreak);
        }
      }
    }

    final merged = <DayPlannerEntry>[];
    merged.addAll(entries);
    merged.addAll(plannedTaskEntries);
    final movementEntries = _buildMovementEntries(
      day: day,
      dayContext: dayContext,
      occupiedEntries: merged,
      dayStart: dayStart,
      dayEnd: dayEnd,
      preferredConcurrentEntryIds: preferredConcurrentEntryIds,
    );
    merged.addAll(movementEntries);
    final overridden = entryOverrides.isEmpty
        ? merged
        : _applyEntryOverrides(merged, entryOverrides, dayStart, dayEnd);
    for (var index = 0; index < overridden.length; index++) {
      final entry = overridden[index];
      overridden[index] = entry.copyWith(
        executionState: executionStates[entry.id] ?? ExecutionState.pending,
      );
    }
    overridden.sort((a, b) => a.start.compareTo(b.start));

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

    return DayPlannerResult(
      entries: overridden,
      summary: summarySegments.isEmpty
          ? 'A light day is ready.'
          : summarySegments.join(' • '),
      recommendations: dayContext == null
          ? const <ActivityRecommendation>[]
          : MovementRecommendationService.generateRecommendations(
              dayContext: dayContext,
              weeklyTotals: weeklyTotals,
              gymCompletedToday: gymCompletedToday,
              daysSinceLastMobility: daysSinceLastMobility,
            ),
    );
  }

  static List<DayPlannerEntry> _buildMovementEntries({
    required DateTime day,
    required DayContext? dayContext,
    required List<DayPlannerEntry> occupiedEntries,
    required DateTime dayStart,
    required DateTime dayEnd,
    required Set<String> preferredConcurrentEntryIds,
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

    final occupied =
        occupiedEntries
            .where((entry) => !entry.isAllDay && entry.type != 'buffer')
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    for (var blockIndex = 0; blockIndex < blockDurations.length; blockIndex++) {
      final block = blockDurations[blockIndex];
      final duration = Duration(minutes: block.$1);
      final movementLabel = block.$3;
      final concurrentEntry = _findConcurrentEntry(
        occupied,
        duration,
        mode,
        preferredConcurrentEntryIds,
        dayStart,
        dayEnd,
      );
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
          occupied.remove(concurrentEntry);
          continue;
        }
      }
      final target = dayStart.add(
        Duration(
          minutes:
              ((dayEnd.difference(dayStart).inMinutes * (blockIndex + 1)) /
                      (blockDurations.length + 1))
                  .round(),
        ),
      );
      final placedStart = _findNearestFreeStart(
        occupied,
        duration,
        target,
        dayStart,
        dayEnd,
      );
      if (placedStart == null) break;

      final end = placedStart.add(duration);
      entries.add(
        DayPlannerEntry(
          id: 'movement-$mode-${entries.length}',
          title: block.$2,
          type: 'movement',
          start: placedStart,
          end: end,
          subtitle: movementLabel,
        ),
      );
      occupied.add(entries.last);
      occupied.sort((a, b) => a.start.compareTo(b.start));
    }

    return entries;
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
    DateTime dayEnd,
  ) {
    for (final entry in occupied) {
      if (entry.isAllDay || entry.isConcurrent) continue;
      if (!entry.start.isBefore(dayEnd) || !entry.end.isAfter(dayStart)) {
        continue;
      }
      if (entry.end.difference(entry.start) < duration) continue;
      final isPreferred = preferredConcurrentEntryIds.contains(entry.id);
      if (entry.type == 'calendar' &&
          (isPreferred ||
              (preferredConcurrentEntryIds.isEmpty &&
                  _calendarAllowsConcurrentMovement(entry.title, mode)))) {
        return entry;
      }
      if (entry.type == 'task' &&
          preferredConcurrentEntryIds.isEmpty &&
          _taskAllowsConcurrentMovement(entry.title)) {
        return entry;
      }
    }
    return null;
  }

  static DateTime? _findNearestFreeStart(
    List<DayPlannerEntry> occupied,
    Duration duration,
    DateTime target,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final boundaries = <DateTime>[dayStart, dayEnd];
    for (final entry in occupied) {
      if (entry.isAllDay || entry.type == 'buffer') continue;
      if (entry.end.isAfter(dayStart) && entry.start.isBefore(dayEnd)) {
        boundaries.add(entry.start.isBefore(dayStart) ? dayStart : entry.start);
        boundaries.add(entry.end.isAfter(dayEnd) ? dayEnd : entry.end);
      }
    }
    boundaries.sort();

    DateTime? best;
    Duration? bestDistance;
    for (var index = 0; index < boundaries.length - 1; index++) {
      final gapStart = boundaries[index];
      final gapEnd = boundaries[index + 1];
      if (gapEnd.difference(gapStart) < duration) continue;
      final latestStart = gapEnd.subtract(duration);
      final candidate = target.isBefore(gapStart)
          ? gapStart
          : target.isAfter(latestStart)
          ? latestStart
          : target;
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
      if (task.effortMinutes! <= 120) {
        return Duration(minutes: task.effortMinutes!);
      }
    }

    return switch (task.priority) {
      'high' => const Duration(minutes: 75),
      'medium' => const Duration(minutes: 60),
      'low' => const Duration(minutes: 45),
      _ => const Duration(minutes: 60),
    };
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
