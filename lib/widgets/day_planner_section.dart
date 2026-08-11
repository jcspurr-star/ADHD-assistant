import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/day_planner_service.dart';
import '../services/one_drive_sync_service.dart';

class DayPlannerSection extends StatelessWidget {
  const DayPlannerSection({
    super.key,
    required this.upcomingOutlookEventsFuture,
    required this.loadUpcomingOutlookEvents,
    required this.outlookLookAheadDays,
    required this.plannerDayOffset,
    required this.showWorkInPlanner,
    required this.showHomeInPlanner,
    required this.showPlannerInPlanner,
    required this.tasks,
    required this.isNarrow,
    required this.useWideWebOverviewColumns,
    required this.isWorkTask,
    required this.formatPlannerDate,
    required this.onPlannerDayOffsetChanged,
    required this.onShowWorkInPlannerChanged,
    required this.onShowHomeInPlannerChanged,
    required this.onShowPlannerInPlannerChanged,
  });

  final Future<List<OutlookCalendarEvent>>? upcomingOutlookEventsFuture;
  final Future<List<OutlookCalendarEvent>> Function() loadUpcomingOutlookEvents;
  final int outlookLookAheadDays;
  final int plannerDayOffset;
  final bool showWorkInPlanner;
  final bool showHomeInPlanner;
  final bool showPlannerInPlanner;
  final List<Task> tasks;
  final bool isNarrow;
  final bool useWideWebOverviewColumns;
  final bool Function(Task task) isWorkTask;
  final String Function(BuildContext context, DateTime value) formatPlannerDate;
  final ValueChanged<int> onPlannerDayOffsetChanged;
  final ValueChanged<bool> onShowWorkInPlannerChanged;
  final ValueChanged<bool> onShowHomeInPlannerChanged;
  final ValueChanged<bool> onShowPlannerInPlannerChanged;

  Widget _buildPlannerToggleChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
    required Color chipColor,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : chipColor,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: chipColor,
      backgroundColor: chipColor.withAlpha(40),
      side: BorderSide(
        color: selected ? chipColor : chipColor.withAlpha(145),
        width: selected ? 1.4 : 1.1,
      ),
      onSelected: onChanged,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPlannerEntryCard(DayPlannerEntry entry) {
    final isTask = entry.type == 'task';
    final isCalendar = entry.type == 'calendar';
    final isAllDayCalendarEntry = isCalendar && entry.isAllDay;
    final now = DateTime.now();
    final workColor = const Color(0xFF008E7A);
    final homeColor = const Color(0xFF1E63D0);
    final plannerColor = const Color(0xFF7C4DFF);

    final isWorkTaskEntry =
        isTask && entry.task != null && isWorkTask(entry.task!);
    final isWorkCalendarEntry =
        isCalendar && (entry.subtitle?.toLowerCase().contains('work') ?? false);
    final isHomeTaskEntry =
        isTask && entry.task != null && !isWorkTask(entry.task!);
    final isHomeCalendarEntry =
        isCalendar && (entry.subtitle?.toLowerCase().contains('home') ?? false);

    final color = (isWorkTaskEntry || isWorkCalendarEntry)
        ? workColor
        : (isHomeTaskEntry || isHomeCalendarEntry)
        ? homeColor
        : plannerColor;
    final effectiveEnd = entry.end.isAfter(entry.start)
        ? entry.end
        : entry.start.add(const Duration(minutes: 5));
    final isCurrentEntry =
        !now.isBefore(entry.start) && now.isBefore(effectiveEnd);

    var subtitle = entry.subtitle;
    if (isTask && entry.task != null) {
      final sourceLabel = isWorkTask(entry.task!) ? 'Work task' : 'Home task';
      subtitle = subtitle == null || subtitle.trim().isEmpty
          ? sourceLabel
          : '$subtitle • $sourceLabel';
    } else if (entry.type == 'break' || entry.type == 'buffer') {
      subtitle = subtitle == null || subtitle.trim().isEmpty
          ? 'Planner addition'
          : '$subtitle • Planner addition';
    }

    final timeLabel = isAllDayCalendarEntry
        ? 'All day'
        : '${entry.start.hour.toString().padLeft(2, '0')}:${entry.start.minute.toString().padLeft(2, '0')}–${entry.end.hour.toString().padLeft(2, '0')}:${entry.end.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(isCurrentEntry ? 56 : 36),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withAlpha(isCurrentEntry ? 255 : 210),
            width: isCurrentEntry ? 2.2 : 1,
          ),
          boxShadow: isCurrentEntry
              ? [
                  BoxShadow(
                    color: color.withAlpha(90),
                    blurRadius: 12,
                    spreadRadius: 0.8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32,
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? ' ',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isCurrentEntry)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(230),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'NOW',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isCurrentEntry) const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OutlookCalendarEvent>>(
      future: upcomingOutlookEventsFuture ?? loadUpcomingOutlookEvents(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <OutlookCalendarEvent>[];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final maxPlannerOffset = (outlookLookAheadDays - 1)
            .clamp(0, 31)
            .toInt();
        final effectivePlannerDayOffset = plannerDayOffset.clamp(
          0,
          maxPlannerOffset,
        );
        final selectedPlannerDate = today.add(
          Duration(days: effectivePlannerDayOffset),
        );
        final selectedPlannerDayOnly = DateTime(
          selectedPlannerDate.year,
          selectedPlannerDate.month,
          selectedPlannerDate.day,
        );
        final isPlannerDayToday = selectedPlannerDayOnly == today;
        final filteredCalendarEvents = events.where((event) {
          final isWorkCalendar = event.calendarSource == 'work';
          if (isWorkCalendar && !showWorkInPlanner) {
            return false;
          }
          if (!isWorkCalendar && !showHomeInPlanner) {
            return false;
          }

          final start = event.start?.toLocal();
          if (start == null) {
            return false;
          }
          final eventEnd =
              event.end?.toLocal() ??
              (event.isAllDay
                  ? DateTime(start.year, start.month, start.day, 23, 59)
                  : start.add(const Duration(minutes: 5)));
          if (isPlannerDayToday && !eventEnd.isAfter(now)) {
            return false;
          }

          return true;
        }).toList();

        final filteredTasks = tasks.where((task) {
          final isWorkTaskValue = isWorkTask(task);
          if (isWorkTaskValue && !showWorkInPlanner) {
            return false;
          }
          if (!isWorkTaskValue && !showHomeInPlanner) {
            return false;
          }
          return true;
        }).toList();

        final plannerResult = DayPlannerService.buildPlan(
          tasks: filteredTasks,
          calendarEvents: filteredCalendarEvents,
          day: selectedPlannerDate,
        );
        final visiblePlannerEntries = plannerResult.entries.where((entry) {
          if (isPlannerDayToday && !entry.end.isAfter(now)) {
            return false;
          }
          final isPlannerAddition =
              entry.type == 'break' || entry.type == 'buffer';
          if (isPlannerAddition && !showPlannerInPlanner) {
            return false;
          }
          return true;
        }).toList();

        final plannerListHeight = isNarrow
            ? 200.0
            : ((MediaQuery.of(context).size.height * 0.28)
                  .clamp(200.0, 340.0)
                  .toDouble());

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Plan my day',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    plannerResult.summary,
                    style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Colors.teal.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: effectivePlannerDayOffset > 0
                        ? () {
                            onPlannerDayOffsetChanged(
                              effectivePlannerDayOffset - 1,
                            );
                          }
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      formatPlannerDate(context, selectedPlannerDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: effectivePlannerDayOffset > 0
                        ? () {
                            onPlannerDayOffsetChanged(0);
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('Today'),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Next day',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: effectivePlannerDayOffset < maxPlannerOffset
                        ? () {
                            onPlannerDayOffsetChanged(
                              effectivePlannerDayOffset + 1,
                            );
                          }
                        : null,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: Colors.teal.shade500.withAlpha(170),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'scroll',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade500.withAlpha(170),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildPlannerToggleChip(
                        label: 'Work',
                        selected: showWorkInPlanner,
                        chipColor: const Color(0xFF008E7A),
                        onChanged: onShowWorkInPlannerChanged,
                      ),
                      _buildPlannerToggleChip(
                        label: 'Home',
                        selected: showHomeInPlanner,
                        chipColor: const Color(0xFF1E63D0),
                        onChanged: onShowHomeInPlannerChanged,
                      ),
                      _buildPlannerToggleChip(
                        label: 'Planner',
                        selected: showPlannerInPlanner,
                        chipColor: const Color(0xFF7C4DFF),
                        onChanged: onShowPlannerInPlannerChanged,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (visiblePlannerEntries.isEmpty)
                Text(
                  'Nothing to show with current filters.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                )
              else
                (useWideWebOverviewColumns
                    ? Expanded(
                        child: ListView.builder(
                          itemCount: visiblePlannerEntries.length,
                          itemBuilder: (context, index) {
                            final entry = visiblePlannerEntries[index];
                            return _buildPlannerEntryCard(entry);
                          },
                        ),
                      )
                    : SizedBox(
                        height: plannerListHeight,
                        child: ListView.builder(
                          itemCount: visiblePlannerEntries.length,
                          itemBuilder: (context, index) {
                            final entry = visiblePlannerEntries[index];
                            return _buildPlannerEntryCard(entry);
                          },
                        ),
                      )),
            ],
          ),
        );
      },
    );
  }
}
