import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';
import '../models/task.dart';
import '../services/day_planner_service.dart';
import '../services/movement_recommendation_service.dart';
import '../services/next_action_service.dart';
import '../services/planner_execution_service.dart';
import '../services/one_drive_sync_service.dart';
import 'next_action_card.dart';
import 'movement_recommendation_panel.dart';

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
    required this.gymAvailable,
    required this.wfhAvailable,
    required this.eveningAvailable,
    required this.weeklyActivityTotals,
    required this.daysSinceLastMobility,
    required this.gymCompletedToday,
    required this.completedActivityPillarsToday,
    required this.executionStates,
    required this.preferredConcurrentEntryIds,
    required this.removedPlannerEntryIds,
    required this.plannerEntryOverrides,
    required this.workdayStartMinutes,
    required this.workdayEndMinutes,
    required this.tasks,
    required this.isNarrow,
    required this.useWideWebOverviewColumns,
    required this.isWorkTask,
    required this.formatPlannerDate,
    required this.onPlannerDayOffsetChanged,
    required this.onShowWorkInPlannerChanged,
    required this.onShowHomeInPlannerChanged,
    required this.onShowPlannerInPlannerChanged,
    required this.onGymAvailableChanged,
    required this.onWfhAvailableChanged,
    required this.onEveningAvailableChanged,
    required this.onCompleteRecommendation,
    required this.onViewActivityHistory,
    required this.onPreferredConcurrentEntryIdsChanged,
    required this.onRemovePlannerEntry,
    required this.onWorkdayHoursChanged,
    required this.onEditPlannerEntryTime,
    required this.onTogglePlannerEntryLock,
    required this.onExecutePlannerEntry,
    required this.onOpenTask,
    this.dashboardMode = false,
    this.onOpenPlanner,
  });

  final Future<List<OutlookCalendarEvent>>? upcomingOutlookEventsFuture;
  final Future<List<OutlookCalendarEvent>> Function() loadUpcomingOutlookEvents;
  final int outlookLookAheadDays;
  final int plannerDayOffset;
  final bool showWorkInPlanner;
  final bool showHomeInPlanner;
  final bool showPlannerInPlanner;
  final bool gymAvailable;
  final bool wfhAvailable;
  final bool eveningAvailable;
  final WeeklyActivityTotals weeklyActivityTotals;
  final int daysSinceLastMobility;
  final bool gymCompletedToday;
  final Set<ActivityPillar> completedActivityPillarsToday;
  final Map<String, ExecutionState> executionStates;
  final Set<String> preferredConcurrentEntryIds;
  final Set<String> removedPlannerEntryIds;
  final Map<String, PlannerEntryOverride> plannerEntryOverrides;
  final int workdayStartMinutes;
  final int workdayEndMinutes;
  final List<Task> tasks;
  final bool isNarrow;
  final bool useWideWebOverviewColumns;
  final bool Function(Task task) isWorkTask;
  final String Function(BuildContext context, DateTime value) formatPlannerDate;
  final ValueChanged<int> onPlannerDayOffsetChanged;
  final ValueChanged<bool> onShowWorkInPlannerChanged;
  final ValueChanged<bool> onShowHomeInPlannerChanged;
  final ValueChanged<bool> onShowPlannerInPlannerChanged;
  final ValueChanged<bool> onGymAvailableChanged;
  final ValueChanged<bool> onWfhAvailableChanged;
  final ValueChanged<bool> onEveningAvailableChanged;
  final ValueChanged<ActivityRecommendation> onCompleteRecommendation;
  final VoidCallback onViewActivityHistory;
  final ValueChanged<Set<String>> onPreferredConcurrentEntryIdsChanged;
  final ValueChanged<String> onRemovePlannerEntry;
  final ValueChanged<(int, int)> onWorkdayHoursChanged;
  // Called with (entryId, startMinutes, endMinutes) when the user edits an entry's time.
  final void Function(String entryId, int startMinutes, int endMinutes)
  onEditPlannerEntryTime;
  final void Function(String entryId, bool locked) onTogglePlannerEntryLock;
  final void Function(DayPlannerEntry entry, ExecutionState state)
  onExecutePlannerEntry;
  final ValueChanged<Task> onOpenTask;
  final bool dashboardMode;
  final VoidCallback? onOpenPlanner;

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

  Widget _buildPlannerEntryCard(
    BuildContext context,
    DayPlannerEntry entry, {
    double height = 80,
  }) {
    final isTask = entry.type == 'task';
    final isCalendar = entry.type == 'calendar';
    final isAllDayCalendarEntry = isCalendar && entry.isAllDay;
    final now = DateTime.now();
    final workColor = const Color(0xFF008E7A);
    final homeColor = const Color(0xFF1E63D0);
    final plannerColor = const Color(0xFF7C4DFF);
    final movementColor = const Color(0xFFB05A00);
    final isMovement = entry.type == 'movement';
    final isCompleted = entry.executionState == ExecutionState.completed;
    final isSkipped = entry.executionState == ExecutionState.skipped;
    final isCompact = height < 76;
    // The card's internal padding reduces the usable action-column height.
    // Treat near-minimum cards as tiny before their nominal height reaches 46.
    final isTiny = height <= 50;
    final isPreferredConcurrent = preferredConcurrentEntryIds.contains(
      entry.id,
    );

    final isWorkTaskEntry =
        isTask && entry.task != null && isWorkTask(entry.task!);
    final isWorkCalendarEntry =
        isCalendar && (entry.subtitle?.toLowerCase().contains('work') ?? false);
    final isHomeTaskEntry =
        isTask && entry.task != null && !isWorkTask(entry.task!);
    final isHomeCalendarEntry =
        isCalendar && (entry.subtitle?.toLowerCase().contains('home') ?? false);

    final color = isMovement
        ? movementColor
        : (isWorkTaskEntry || isWorkCalendarEntry)
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
    } else if (isMovement) {
      subtitle = subtitle == null || subtitle.trim().isEmpty
          ? 'Movement plan'
          : '$subtitle • Movement plan';
    }

    final timeLabel = isAllDayCalendarEntry
        ? 'All day'
        : '${entry.start.hour.toString().padLeft(2, '0')}:${entry.start.minute.toString().padLeft(2, '0')}–${entry.end.hour.toString().padLeft(2, '0')}:${entry.end.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        height: height,
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 5 : 8,
          vertical: isTiny ? 0 : (isCompact ? 4 : 8),
        ),
        decoration: BoxDecoration(
          color: color.withAlpha(
            isCompleted || isSkipped ? 18 : (isCurrentEntry ? 56 : 36),
          ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowLane = constraints.maxWidth < 140;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isCompact ? 5 : 8,
                  height: isTiny ? 14 : (isCompact ? 28 : 60),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: isTiny
                            ? constraints.maxHeight.clamp(0, 14).toDouble()
                            : (isCompact || isNarrowLane ? 18 : 32),
                        child: ClipRect(
                          child: Text(
                            entry.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isSkipped ? Colors.grey : null,
                            ),
                            maxLines: isCompact || isNarrowLane ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (!isCompact && !isNarrowLane)
                        const SizedBox(height: 2),
                      if (!isCompact && !isNarrowLane)
                        Text(
                          subtitle ?? ' ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (!isCompact && !isNarrowLane && entry.isConcurrent)
                        Text(
                          'Concurrent movement',
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isNarrowLane && !isTiny)
                  SizedBox(
                    width: 84,
                    child: ClipRect(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isCalendar && !isTiny)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Complete',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 22,
                                  ),
                                  icon: Icon(
                                    isCompleted
                                        ? Icons.check_circle
                                        : Icons.check_circle_outline,
                                    size: 15,
                                    color: isCompleted
                                        ? Colors.green.shade700
                                        : Colors.blueGrey.shade500,
                                  ),
                                  onPressed: isCompleted
                                      ? null
                                      : () => onExecutePlannerEntry(
                                          entry,
                                          ExecutionState.completed,
                                        ),
                                ),
                                IconButton(
                                  tooltip: 'Skip',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 22,
                                  ),
                                  icon: Icon(
                                    isSkipped
                                        ? Icons.skip_next
                                        : Icons.skip_next_outlined,
                                    size: 15,
                                    color: isSkipped
                                        ? Colors.orange.shade700
                                        : Colors.blueGrey.shade500,
                                  ),
                                  onPressed: isSkipped
                                      ? null
                                      : () => onExecutePlannerEntry(
                                          entry,
                                          ExecutionState.skipped,
                                        ),
                                ),
                              ],
                            ),
                          if (isCalendar && isCompact && !isTiny)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: isPreferredConcurrent
                                      ? 'Remove movement pairing'
                                      : 'Pair movement with this event',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 22,
                                  ),
                                  icon: Icon(
                                    isPreferredConcurrent
                                        ? Icons.directions_walk
                                        : Icons.directions_walk_outlined,
                                    size: 16,
                                    color: isPreferredConcurrent
                                        ? movementColor
                                        : Colors.blueGrey.shade500,
                                  ),
                                  onPressed: () {
                                    final next = Set<String>.from(
                                      preferredConcurrentEntryIds,
                                    );
                                    if (!next.add(entry.id)) {
                                      next.remove(entry.id);
                                    }
                                    onPreferredConcurrentEntryIdsChanged(next);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Remove from this plan',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 22,
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 16,
                                  ),
                                  onPressed: () =>
                                      onRemovePlannerEntry(entry.id),
                                ),
                              ],
                            ),
                          if (isCalendar && !isCompact && !isTiny)
                            IconButton(
                              tooltip: isPreferredConcurrent
                                  ? 'Remove movement pairing'
                                  : 'Pair movement with this event',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 22,
                              ),
                              icon: Icon(
                                isPreferredConcurrent
                                    ? Icons.directions_walk
                                    : Icons.directions_walk_outlined,
                                size: 16,
                                color: isPreferredConcurrent
                                    ? movementColor
                                    : Colors.blueGrey.shade500,
                              ),
                              onPressed: () {
                                final next = Set<String>.from(
                                  preferredConcurrentEntryIds,
                                );
                                if (!next.add(entry.id)) {
                                  next.remove(entry.id);
                                }
                                onPreferredConcurrentEntryIdsChanged(next);
                              },
                            ),
                          if (isCalendar && !isCompact && !isTiny)
                            IconButton(
                              tooltip: 'Remove from this plan',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 22,
                              ),
                              icon: const Icon(
                                Icons.visibility_off_outlined,
                                size: 16,
                              ),
                              onPressed: () => onRemovePlannerEntry(entry.id),
                            ),
                          if (isCalendar && isTiny)
                            Tooltip(
                              message: isPreferredConcurrent
                                  ? 'Remove movement pairing'
                                  : 'Pair movement with this event',
                              child: InkWell(
                                onTap: () {
                                  final next = Set<String>.from(
                                    preferredConcurrentEntryIds,
                                  );
                                  if (!next.add(entry.id)) {
                                    next.remove(entry.id);
                                  }
                                  onPreferredConcurrentEntryIdsChanged(next);
                                },
                                child: Icon(
                                  isPreferredConcurrent
                                      ? Icons.directions_walk
                                      : Icons.directions_walk_outlined,
                                  size: 14,
                                  color: isPreferredConcurrent
                                      ? movementColor
                                      : Colors.blueGrey.shade500,
                                ),
                              ),
                            ),
                          if (!isTiny &&
                              !isCompact &&
                              entry.type != 'buffer' &&
                              !isAllDayCalendarEntry)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: entry.isLocked
                                      ? 'Unlock time'
                                      : 'Lock time so re-planning won\'t move it',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 22,
                                  ),
                                  icon: Icon(
                                    entry.isLocked
                                        ? Icons.lock
                                        : Icons.lock_open_outlined,
                                    size: 14,
                                    color: entry.isLocked
                                        ? color
                                        : Colors.blueGrey.shade400,
                                  ),
                                  onPressed: () => onTogglePlannerEntryLock(
                                    entry.id,
                                    !entry.isLocked,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit time',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 22,
                                  ),
                                  icon: const Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                  ),
                                  onPressed: () =>
                                      _showEditEntryTimeDialog(context, entry),
                                ),
                              ],
                            ),
                          if (isCurrentEntry && !isTiny && !isCompact)
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
                          if (isCurrentEntry && !isTiny && !isCompact)
                            const SizedBox(height: 4),
                          if (!isTiny && !isCompact)
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
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final suffix = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')}$suffix';
  }

  String _formatTime(DateTime value) {
    return _formatMinutes(value.hour * 60 + value.minute);
  }

  Future<void> _showEditEntryTimeDialog(
    BuildContext context,
    DayPlannerEntry entry,
  ) async {
    var startTime = TimeOfDay(
      hour: entry.start.hour,
      minute: entry.start.minute,
    );
    var endTime = TimeOfDay(hour: entry.end.hour, minute: entry.end.minute);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Edit "${entry.title}" time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    trailing: Text(
                      _formatMinutes(startTime.hour * 60 + startTime.minute),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setDialogState(() => startTime = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    trailing: Text(
                      _formatMinutes(endTime.hour * 60 + endTime.minute),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: endTime,
                      );
                      if (picked != null) {
                        setDialogState(() => endTime = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !context.mounted) return;

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    onEditPlannerEntryTime(entry.id, startMinutes, endMinutes);
  }

  Future<void> _pickWorkdayTime(
    BuildContext context, {
    required bool isStart,
  }) async {
    final currentMinutes = isStart
        ? workdayStartMinutes
        : workdayEndMinutes.clamp(0, 23 * 60 + 59).toInt();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );
    if (!context.mounted || picked == null) return;

    final pickedMinutes = picked.hour * 60 + picked.minute;
    final nextStart = isStart ? pickedMinutes : workdayStartMinutes;
    final nextEnd = isStart ? workdayEndMinutes : pickedMinutes;
    if (nextEnd <= nextStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    onWorkdayHoursChanged((nextStart, nextEnd));
  }

  Widget _buildPlannerTimeline({
    required DateTime day,
    required List<DayPlannerEntry> entries,
    required double height,
  }) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(minutes: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        return _buildPlannerTimelineContent(
          day: day,
          entries: entries,
          height: height,
          now: snapshot.data ?? DateTime.now(),
        );
      },
    );
  }

  Widget _buildPlannerTimelineContent({
    required DateTime day,
    required List<DayPlannerEntry> entries,
    required double height,
    required DateTime now,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final isToday =
        now.year == day.year && now.month == day.month && now.day == day.day;
    final start = dayStart;
    final end = dayStart.add(const Duration(days: 1));
    final totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) return const SizedBox.shrink();
    // Keep the viewport at the full pane height while rendering the day at a
    // readable scale inside its vertical scroll area.
    final timelineContentHeight = height * 8;
    final allDayEntries = entries.where((entry) => entry.isAllDay).toList();

    final positionedEntries = <({DayPlannerEntry entry, int lane})>[];
    final laneEnds = <DateTime>[];
    final sortedEntries =
        entries
            .where((entry) => entry.type != 'buffer' && !entry.isAllDay)
            .toList()
          ..sort((a, b) {
            final startCompare = a.start.compareTo(b.start);
            if (startCompare != 0) return startCompare;
            return b.end.compareTo(a.end);
          });
    for (final entry in sortedEntries) {
      final visualEnd =
          entry.end.isAfter(entry.start.add(const Duration(minutes: 30)))
          ? entry.end
          : entry.start.add(const Duration(minutes: 30));
      var lane = 0;
      while (lane < laneEnds.length && entry.start.isBefore(laneEnds[lane])) {
        lane++;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(visualEnd);
      } else {
        laneEnds[lane] = visualEnd;
      }
      positionedEntries.add((entry: entry, lane: lane));
    }

    final laneCount = laneEnds.isEmpty ? 1 : laneEnds.length;
    const timeAxisWidth = 48.0;
    const laneGap = 4.0;
    final timelineColor = Colors.blueGrey.shade200;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        children: [
          if (allDayEntries.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(120),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All day events',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 6),
                      itemCount: allDayEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => SizedBox(
                        width: 180,
                        child: _buildPlannerEntryCard(
                          context,
                          allDayEntries[index],
                          height: 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth - timeAxisWidth;
                final minimumTimelineWidth =
                    timeAxisWidth +
                    (laneCount * 180) +
                    ((laneCount - 1) * laneGap);
                final timelineWidth = contentWidth < minimumTimelineWidth
                    ? minimumTimelineWidth
                    : constraints.maxWidth;
                final laneWidth =
                    (timelineWidth -
                        timeAxisWidth -
                        ((laneCount - 1) * laneGap)) /
                    laneCount;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  child: SizedBox(
                    width: timelineWidth,
                    height: timelineContentHeight,
                    child: SingleChildScrollView(
                      primary: false,
                      child: SizedBox(
                        height: timelineContentHeight,
                        child: Stack(
                          children: [
                            for (var hour = 0; hour <= totalMinutes; hour += 60)
                              Positioned(
                                top:
                                    (hour / totalMinutes) *
                                    timelineContentHeight,
                                left: 0,
                                right: 0,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: timeAxisWidth,
                                      child: Text(
                                        _formatTime(
                                          start.add(Duration(minutes: hour)),
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: timelineColor,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final positioned in positionedEntries)
                              if (positioned.lane < laneCount)
                                Positioned(
                                  top:
                                      (((positioned.entry.start.isBefore(start)
                                                  ? start
                                                  : positioned.entry.start)
                                              .difference(start)
                                              .inMinutes
                                              .clamp(0, totalMinutes)) /
                                          totalMinutes) *
                                      timelineContentHeight,
                                  left:
                                      timeAxisWidth +
                                      positioned.lane * (laneWidth + laneGap),
                                  width: laneWidth,
                                  height:
                                      (((positioned.entry.end
                                                  .difference(
                                                    positioned.entry.start
                                                            .isBefore(start)
                                                        ? start
                                                        : positioned
                                                              .entry
                                                              .start,
                                                  )
                                                  .inMinutes)
                                              .clamp(30, totalMinutes)) /
                                          totalMinutes) *
                                      timelineContentHeight,
                                  child: _buildPlannerEntryCard(
                                    context,
                                    positioned.entry,
                                    height:
                                        (((positioned.entry.end
                                                    .difference(
                                                      positioned.entry.start,
                                                    )
                                                    .inMinutes)
                                                .clamp(30, totalMinutes)) /
                                            totalMinutes) *
                                        timelineContentHeight,
                                  ),
                                ),
                            if (isToday)
                              Positioned(
                                top:
                                    ((now.hour * 60 + now.minute) /
                                        totalMinutes) *
                                    timelineContentHeight,
                                left: 0,
                                right: 0,
                                height: 4,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: timeAxisWidth,
                                      child: Text(
                                        _formatTime(now),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 3,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

          if (removedPlannerEntryIds.contains('calendar-${event.id}')) {
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

        final dayContext = DayContext(
          gymMorning: gymAvailable,
          workLocation: wfhAvailable ? WorkLocation.home : WorkLocation.office,
          eveningAvailable: eveningAvailable,
        );

        final plannerResult = DayPlannerService.buildPlan(
          tasks: filteredTasks,
          calendarEvents: filteredCalendarEvents,
          day: selectedPlannerDate,
          dayContext: dayContext,
          weeklyTotals: weeklyActivityTotals,
          gymCompletedToday: gymCompletedToday,
          daysSinceLastMobility: daysSinceLastMobility,
          preferredConcurrentEntryIds: preferredConcurrentEntryIds,
          workdayStartMinutes: workdayStartMinutes,
          workdayEndMinutes: workdayEndMinutes,
          entryOverrides: plannerEntryOverrides,
          executionStates: executionStates,
        );
        final visiblePlannerEntries = plannerResult.entries.where((entry) {
          if (isPlannerDayToday && !entry.end.isAfter(now)) {
            return false;
          }
          final isPlannerAddition =
              entry.type == 'break' ||
              entry.type == 'buffer' ||
              entry.type == 'movement';
          if (isPlannerAddition && !showPlannerInPlanner) {
            return false;
          }
          return true;
        }).toList();
        final executionSummary = PlannerExecutionService.summarize(
          visiblePlannerEntries
              .where((entry) => entry.type != 'calendar')
              .map((entry) => entry.id),
          executionStates,
        );

        if (dashboardMode) {
          return _buildDashboardContent(
            context: context,
            plannerResult: plannerResult,
            executionSummary: executionSummary,
            filteredTasks: filteredTasks,
            visiblePlannerEntries: visiblePlannerEntries,
            selectedPlannerDate: selectedPlannerDate,
            dayContext: dayContext,
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: LayoutBuilder(
            builder: (context, sectionConstraints) {
              final availableHeight = sectionConstraints.maxHeight;
              final timelineHeight = availableHeight > 140
                  ? availableHeight - 110
                  : availableHeight;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: availableHeight > 140 ? 90 : null,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildPlannerHeaderContent(
                          context: context,
                          plannerResult: plannerResult,
                          effectivePlannerDayOffset: effectivePlannerDayOffset,
                          maxPlannerOffset: maxPlannerOffset,
                          selectedPlannerDate: selectedPlannerDate,
                          dayContext: dayContext,
                          executionSummary: executionSummary,
                          filteredTasks: filteredTasks,
                          visiblePlannerEntries: visiblePlannerEntries,
                          onPlannerDayOffsetChanged: onPlannerDayOffsetChanged,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visiblePlannerEntries.isEmpty)
                    SizedBox(
                      height: timelineHeight,
                      child: Center(
                        child: Text(
                          'Nothing to show with current filters.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildPlannerTimeline(
                      day: selectedPlannerDate,
                      entries: visiblePlannerEntries,
                      height: timelineHeight,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.teal.shade900,
        ),
      ),
    );
  }

  Widget _buildExecutionSummary(PlannerExecutionSummary summary) {
    Widget metric(String label, int value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(label, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        metric('Completed', summary.completedCount, Colors.green.shade700),
        const SizedBox(width: 6),
        metric('Skipped', summary.skippedCount, Colors.orange.shade700),
        const SizedBox(width: 6),
        metric('Remaining', summary.remainingCount, Colors.blueGrey.shade700),
      ],
    );
  }

  Widget _buildUpcomingItems(List<DayPlannerEntry> entries) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming items',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No pending planner items.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              )
            else
              for (final entry in entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    entry.type == 'movement'
                        ? Icons.directions_walk_outlined
                        : entry.type == 'break'
                        ? Icons.free_breakfast_outlined
                        : Icons.task_alt_outlined,
                    size: 17,
                    color: Colors.teal.shade700,
                  ),
                  title: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_formatMinutes(entry.start.hour * 60 + entry.start.minute)} • ${entry.end.difference(entry.start).inMinutes} mins',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextSection(
    BuildContext context,
    DayContext dayContext, {
    double? width,
  }) {
    final targets = MovementRecommendationService.resolveDayTypeTargets(
      dayContext,
    );
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.tune, size: 18),
                  const Text(
                    'Planner context',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${dayContext.workLocation == WorkLocation.home ? 'WFH' : 'Office'} • ${dayContext.eveningAvailable ? 'Evening available' : 'Evening unavailable'}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _buildPlannerToggleChip(
                    label: 'Gym morning',
                    selected: dayContext.gymMorning,
                    chipColor: Colors.deepOrange,
                    onChanged: onGymAvailableChanged,
                  ),
                  _buildPlannerToggleChip(
                    label: dayContext.workLocation == WorkLocation.home
                        ? 'WFH'
                        : 'Office',
                    selected: dayContext.workLocation == WorkLocation.home,
                    chipColor: Colors.blue,
                    onChanged: onWfhAvailableChanged,
                  ),
                  _buildPlannerToggleChip(
                    label: 'Evening available',
                    selected: dayContext.eveningAvailable,
                    chipColor: Colors.teal,
                    onChanged: onEveningAvailableChanged,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Day type notes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal.shade800,
                ),
              ),
              Text(
                targets.notes,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Work window',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  OutlinedButton(
                    onPressed: () => _pickWorkdayTime(context, isStart: true),
                    child: Text(_formatMinutes(workdayStartMinutes)),
                  ),
                  const Text('to', style: TextStyle(fontSize: 10)),
                  OutlinedButton(
                    onPressed: () => _pickWorkdayTime(context, isStart: false),
                    child: Text(_formatMinutes(workdayEndMinutes)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
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
        ),
      ),
    );
  }

  Widget _buildDashboardContent({
    required BuildContext context,
    required DayPlannerResult plannerResult,
    required PlannerExecutionSummary executionSummary,
    required List<Task> filteredTasks,
    required List<DayPlannerEntry> visiblePlannerEntries,
    required DateTime selectedPlannerDate,
    required DayContext dayContext,
  }) {
    final nextAction = NextActionService.recommend(
      plannerResult: plannerResult,
      tasks: filteredTasks,
      plannerDay: selectedPlannerDate,
    );
    final pendingEntries = visiblePlannerEntries
        .where(
          (entry) =>
              entry.type != 'calendar' &&
              entry.executionState == ExecutionState.pending,
        )
        .take(3)
        .toList();
    final nextActionWidget = nextAction != null
        ? NextActionCard(
            recommendation: nextAction,
            onOpen: nextAction.task != null
                ? () => onOpenTask(nextAction.task!)
                : onOpenPlanner,
            onComplete: nextAction.plannerEntry != null
                ? () => onExecutePlannerEntry(
                    nextAction.plannerEntry!,
                    ExecutionState.completed,
                  )
                : nextAction.movementRecommendation != null
                ? () => onCompleteRecommendation(
                    nextAction.movementRecommendation!,
                  )
                : null,
          )
        : const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Nothing needs your attention right now.'),
            ),
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildContextSection(context, dayContext)),
              const SizedBox(width: 12),
              Expanded(child: nextActionWidget),
            ],
          ),
          const SizedBox(height: 14),
          _buildSectionLabel('Today'),
          _buildExecutionSummary(executionSummary),
          const SizedBox(height: 8),
          _buildUpcomingItems(pendingEntries),
          const SizedBox(height: 10),
          MovementRecommendationPanel(
            dayContext: dayContext,
            todayTargets: MovementRecommendationService.resolveDayTypeTargets(
              dayContext,
            ),
            weeklyProgress:
                MovementRecommendationService.calculateWeeklyProgress(
                  weeklyActivityTotals,
                ),
            recommendations: plannerResult.recommendations,
            onGymAvailableChanged: onGymAvailableChanged,
            onWfhAvailableChanged: onWfhAvailableChanged,
            onEveningAvailableChanged: onEveningAvailableChanged,
            completedActivityPillars: completedActivityPillarsToday,
            onCompleteRecommendation: onCompleteRecommendation,
            onViewActivityHistory: onViewActivityHistory,
            showContext: false,
          ),
          Text(
            formatPlannerDate(context, selectedPlannerDate),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlannerHeaderContent({
    required BuildContext context,
    required DayPlannerResult plannerResult,
    required int effectivePlannerDayOffset,
    required int maxPlannerOffset,
    required DateTime selectedPlannerDate,
    required DayContext dayContext,
    required PlannerExecutionSummary executionSummary,
    required List<Task> filteredTasks,
    required List<DayPlannerEntry> visiblePlannerEntries,
    required ValueChanged<int> onPlannerDayOffsetChanged,
  }) {
    return [
      Row(
        children: [
          const Icon(Icons.view_timeline_outlined, size: 18),
          const SizedBox(width: 6),
          const Text(
            'Daily Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final dateWidth = constraints.maxWidth * 0.25;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(150),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left, size: 24),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: effectivePlannerDayOffset > 0
                      ? () => onPlannerDayOffsetChanged(
                          effectivePlannerDayOffset - 1,
                        )
                      : null,
                ),
                SizedBox(
                  width: dateWidth,
                  child: Text(
                    formatPlannerDate(context, selectedPlannerDate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Next day',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right, size: 24),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: effectivePlannerDayOffset < maxPlannerOffset
                      ? () => onPlannerDayOffsetChanged(
                          effectivePlannerDayOffset + 1,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: effectivePlannerDayOffset > 0
                      ? () => onPlannerDayOffsetChanged(0)
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
              ],
            ),
          );
        },
      ),
    ];
  }
}
