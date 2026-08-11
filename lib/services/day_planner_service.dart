import '../models/task.dart';
import 'one_drive_sync_service.dart';

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
  });

  final String id;
  final String title;
  final String type;
  final DateTime start;
  final DateTime end;
  final String? subtitle;
  final Task? task;
  final bool isAllDay;
}

class DayPlannerResult {
  DayPlannerResult({required this.entries, required this.summary});

  final List<DayPlannerEntry> entries;
  final String summary;
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
  }) {
    final dayStart = DateTime(day.year, day.month, day.day, 8, 0);
    final dayEnd = DateTime(day.year, day.month, day.day, 20, 0);
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
              (start.isBefore(dayEnd) && end.isAfter(dayStart));
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

      var adjustedStart = eventStart.isBefore(dayStart) ? dayStart : eventStart;
      var adjustedEnd = eventEnd.isAfter(dayEnd) ? dayEnd : eventEnd;

      if (!event.isAllDay && !adjustedEnd.isAfter(adjustedStart)) {
        final minimumEnd = adjustedStart.add(_minimumEventDuration);
        if (minimumEnd.isAfter(dayEnd)) {
          if (adjustedStart.isAfter(dayEnd)) {
            continue;
          }
          if (adjustedStart.isAtSameMomentAs(dayEnd)) {
            adjustedStart = dayEnd.subtract(_minimumEventDuration);
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
    merged.sort((a, b) => a.start.compareTo(b.start));

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
    if (todaysEvents.isNotEmpty) {
      summarySegments.add(
        '${todaysEvents.length} calendar item${todaysEvents.length == 1 ? '' : 's'}',
      );
    }

    return DayPlannerResult(
      entries: merged,
      summary: summarySegments.isEmpty
          ? 'A light day is ready.'
          : summarySegments.join(' • '),
    );
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
