import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';
import '../models/task.dart';
import '../services/day_planner_service.dart';
import '../services/movement_recommendation_service.dart';
import '../services/next_action_service.dart';
import '../services/planner_execution_service.dart';
import '../services/planner_context_resolver.dart';
import '../services/one_drive_sync_service.dart';
import 'next_action_card.dart';
import 'movement_recommendation_panel.dart';

enum _PlannerFilterCategory {
  workCalendar,
  workTasks,
  homeCalendar,
  homeTasks,
  movement,
  personal,
  breakEntry,
  other,
}

class DayPlannerSection extends StatelessWidget {
  const DayPlannerSection({
    super.key,
    required this.upcomingOutlookEventsFuture,
    required this.loadUpcomingOutlookEvents,
    required this.outlookLookAheadDays,
    required this.plannerDayOffset,
    required this.showMovementInPlanner,
    required this.showBreakInPlanner,
    required this.showPersonalInPlanner,
    required this.gymAvailable,
    required this.wfhAvailable,
    required this.eveningAvailable,
    required this.weeklyActivityTotals,
    required this.dailyActivityTotals,
    required this.daysSinceLastMobility,
    required this.gymCompletedToday,
    required this.executionStates,
    required this.preferredConcurrentEntryIds,
    required this.nonBlockingCalendarEventIds,
    this.includedCalendarEventIds = const <String>{},
    required this.removedPlannerEntryIds,
    required this.removedCalendarEventIds,
    this.planningStart,
    required this.plannerEntryOverrides,
    required this.personalBlocks,
    required this.workdayStartMinutes,
    required this.workdayEndMinutes,
    required this.tasks,
    required this.isNarrow,
    required this.useWideWebOverviewColumns,
    required this.isWorkTask,
    required this.formatPlannerDate,
    required this.onPlannerDayOffsetChanged,
    required this.onShowMovementInPlannerChanged,
    required this.onShowBreakInPlannerChanged,
    required this.onShowPersonalInPlannerChanged,
    required this.onGymAvailableChanged,
    required this.onWfhAvailableChanged,
    required this.onEveningAvailableChanged,
    required this.onCompleteRecommendation,
    required this.onViewActivityHistory,
    required this.onPreferredConcurrentEntryIdsChanged,
    required this.onToggleCalendarPlanning,
    this.onToggleIncludedCalendarPlanning,
    required this.onLogHomeEventAsGym,
    required this.onDeleteActivity,
    required this.onWorkdayHoursChanged,
    required this.onEditPlannerEntryTime,
    required this.onTogglePlannerEntryLock,
    required this.onAddPersonalBlock,
    required this.onExecutePlannerEntry,
    required this.onOpenTask,
    this.dashboardMode = false,
    this.onOpenPlanner,
    this.quickCaptureSection,
    this.timeGrid = TimeGrid.fifteenMinutes,
    this.showWorkCalendarInPlanner = true,
    this.showWorkTasksInPlanner = true,
    this.showHomeCalendarInPlanner = true,
    this.showHomeTasksInPlanner = true,
    this.onShowWorkCalendarInPlannerChanged,
    this.onShowWorkTasksInPlannerChanged,
    this.onShowHomeCalendarInPlannerChanged,
    this.onShowHomeTasksInPlannerChanged,
    this.onPlannerResultBuilt,
  });

  final Future<List<OutlookCalendarEvent>>? upcomingOutlookEventsFuture;
  final Future<List<OutlookCalendarEvent>> Function() loadUpcomingOutlookEvents;
  final int outlookLookAheadDays;
  final int plannerDayOffset;
  final bool showMovementInPlanner;
  final bool showBreakInPlanner;
  final bool showPersonalInPlanner;
  final bool gymAvailable;
  final bool wfhAvailable;
  final bool eveningAvailable;
  final WeeklyActivityTotals weeklyActivityTotals;
  final DailyActivityTotals dailyActivityTotals;
  final int daysSinceLastMobility;
  final bool gymCompletedToday;
  final Map<String, ExecutionState> executionStates;
  final Set<String> preferredConcurrentEntryIds;
  final Set<String> nonBlockingCalendarEventIds;
  final Set<String> includedCalendarEventIds;
  final Set<String> removedPlannerEntryIds;
  final Set<String> removedCalendarEventIds;
  final DateTime? planningStart;
  final Map<String, PlannerEntryOverride> plannerEntryOverrides;
  final List<PersonalPlannerBlock> personalBlocks;
  final int workdayStartMinutes;
  final int workdayEndMinutes;
  final List<Task> tasks;
  final bool isNarrow;
  final bool useWideWebOverviewColumns;
  final bool Function(Task task) isWorkTask;
  final String Function(BuildContext context, DateTime value) formatPlannerDate;
  final ValueChanged<int> onPlannerDayOffsetChanged;
  final ValueChanged<bool> onShowMovementInPlannerChanged;
  final ValueChanged<bool> onShowBreakInPlannerChanged;
  final ValueChanged<bool> onShowPersonalInPlannerChanged;
  final ValueChanged<bool> onGymAvailableChanged;
  final ValueChanged<bool> onWfhAvailableChanged;
  final ValueChanged<bool> onEveningAvailableChanged;
  final ValueChanged<ActivityRecommendation> onCompleteRecommendation;
  final VoidCallback onViewActivityHistory;
  final ValueChanged<Set<String>> onPreferredConcurrentEntryIdsChanged;
  final ValueChanged<Set<String>> onToggleCalendarPlanning;
  final ValueChanged<Set<String>>? onToggleIncludedCalendarPlanning;
  final ValueChanged<DayPlannerEntry> onLogHomeEventAsGym;
  final ValueChanged<DayPlannerEntry> onDeleteActivity;
  final ValueChanged<(int, int)> onWorkdayHoursChanged;
  // Called with (entryId, startMinutes, endMinutes) when the user edits an entry's time.
  final void Function(String entryId, int startMinutes, int endMinutes)
  onEditPlannerEntryTime;
  final void Function(String entryId, bool locked) onTogglePlannerEntryLock;
  final void Function(
    DateTime date,
    String title,
    int startMinutes,
    int endMinutes,
  )
  onAddPersonalBlock;
  final void Function(DayPlannerEntry entry, ExecutionState state)
  onExecutePlannerEntry;
  final ValueChanged<Task> onOpenTask;
  final bool dashboardMode;
  final VoidCallback? onOpenPlanner;
  final Widget? quickCaptureSection;
  final TimeGrid timeGrid;
  final bool showWorkCalendarInPlanner;
  final bool showWorkTasksInPlanner;
  final bool showHomeCalendarInPlanner;
  final bool showHomeTasksInPlanner;
  final ValueChanged<bool>? onShowWorkCalendarInPlannerChanged;
  final ValueChanged<bool>? onShowWorkTasksInPlannerChanged;
  final ValueChanged<bool>? onShowHomeCalendarInPlannerChanged;
  final ValueChanged<bool>? onShowHomeTasksInPlannerChanged;
  final void Function(DateTime day, List<DayPlannerEntry> entries)?
  onPlannerResultBuilt;

  Widget _buildPlannerToggleChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
    required Color chipColor,
    double? width,
  }) {
    final labelWidget = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : chipColor,
      ),
    );
    final chip = FilterChip(
      label: width == null
          ? labelWidget
          : SizedBox(width: width - 16, child: labelWidget),
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
    return width == null ? chip : SizedBox(width: width, child: chip);
  }

  bool _isWorkPlannerEntry(DayPlannerEntry entry) {
    if (entry.type == 'calendar') {
      return entry.subtitle?.toLowerCase().contains('work') == true;
    }
    if (entry.type == 'focus' || entry.type == 'buffer') return true;
    if (entry.type == 'task' || entry.type == 'admin') {
      return entry.task != null && isWorkTask(entry.task!);
    }
    return false;
  }

  bool _isOpeningFocusEntry(DayPlannerEntry entry) {
    return entry.type == 'focus' && entry.subtitle == 'Opening focus session';
  }

  bool _isWalkingBreakEntry(DayPlannerEntry entry) {
    return entry.type == 'movement' &&
        !entry.isConcurrent &&
        entry.title.toLowerCase().contains('walk');
  }

  bool _isHomeCalendarIncludedInPlanning(DayPlannerEntry entry) {
    final hasPersonalLabel = entry.labels.any(
      (label) => label.trim().toLowerCase() == 'personal',
    );
    return !nonBlockingCalendarEventIds.contains(entry.id) &&
        (hasPersonalLabel || includedCalendarEventIds.contains(entry.id));
  }

  _PlannerFilterCategory _plannerFilterCategory(DayPlannerEntry entry) {
    if (entry.type == 'calendar') {
      return entry.subtitle?.toLowerCase().contains('work') == true
          ? _PlannerFilterCategory.workCalendar
          : _PlannerFilterCategory.homeCalendar;
    }
    if (_isOpeningFocusEntry(entry)) {
      return _PlannerFilterCategory.workTasks;
    }
    if (entry.type == 'focus' || entry.type == 'buffer') {
      return _PlannerFilterCategory.workTasks;
    }
    if (entry.type == 'task' || entry.type == 'admin') {
      return _isWorkPlannerEntry(entry)
          ? _PlannerFilterCategory.workTasks
          : _PlannerFilterCategory.homeTasks;
    }
    if (entry.type == 'personal') return _PlannerFilterCategory.personal;
    if (entry.type == 'movement') return _PlannerFilterCategory.movement;
    if (_isFocusBreak(entry)) return _PlannerFilterCategory.breakEntry;
    if (entry.type == 'break') return _PlannerFilterCategory.breakEntry;
    return _PlannerFilterCategory.other;
  }

  String _eventCategoryLabel(DayPlannerEntry entry) {
    return switch (_plannerFilterCategory(entry)) {
      _PlannerFilterCategory.workCalendar => 'Work calendar',
      _PlannerFilterCategory.workTasks => 'Work tasks',
      _PlannerFilterCategory.homeCalendar => 'Home calendar',
      _PlannerFilterCategory.homeTasks => 'Home tasks',
      _PlannerFilterCategory.personal => 'Personal',
      _PlannerFilterCategory.movement => 'Movement',
      _PlannerFilterCategory.breakEntry => 'Break',
      _PlannerFilterCategory.other => entry.type,
    };
  }

  int _lanePriority(DayPlannerEntry entry) {
    if (_isFocusBreak(entry)) return 6;
    if (entry.type == 'focus' || entry.type == 'buffer') return 1;
    if (entry.type == 'task' || entry.type == 'admin') {
      return entry.task != null && isWorkTask(entry.task!) ? 1 : 3;
    }
    if (entry.type == 'calendar') {
      if (entry.subtitle?.toLowerCase().contains('home') == true &&
          !_isHomeCalendarIncludedInPlanning(entry)) {
        return 7;
      }
      return entry.subtitle?.toLowerCase().contains('work') == true ? 1 : 3;
    }
    if (entry.type == 'personal') return 4;
    if (entry.type == 'movement') return 6;
    if (entry.type == 'break') return 6;
    return 3;
  }

  static bool _isFocusBreak(DayPlannerEntry entry) {
    return entry.type == 'break' &&
        entry.subtitle?.toLowerCase().contains('focus') == true;
  }

  static bool hasTimeOverlap(DayPlannerEntry a, DayPlannerEntry b) {
    if (a.isAllDay || b.isAllDay) return false;
    if (a.isZeroDuration || b.isZeroDuration) {
      return a.start.isAtSameMomentAs(b.start) && !a.isAllDay && !b.isAllDay;
    }
    return a.start.isBefore(b.end) && a.end.isAfter(b.start);
  }

  /// Assign each real interval to the leftmost lane available after applying
  /// category preference to concurrent entries.
  static List<({DayPlannerEntry entry, int lane})> assignLeftmostFreeLanes(
    Iterable<DayPlannerEntry> entries, {
    int Function(DayPlannerEntry entry)? lanePriority,
  }) {
    final intervalEntries =
        entries
            .where((entry) => !entry.isAllDay && !entry.isZeroDuration)
            .toList()
          ..sort((a, b) {
            final priorityCompare =
                (lanePriority?.call(a) ?? _defaultLanePriority(a)).compareTo(
                  lanePriority?.call(b) ?? _defaultLanePriority(b),
                );
            if (priorityCompare != 0) return priorityCompare;
            final startCompare = a.start.compareTo(b.start);
            if (startCompare != 0) return startCompare;
            final endCompare = a.end.compareTo(b.end);
            if (endCompare != 0) return endCompare;
            return a.id.compareTo(b.id);
          });

    final laneEntries = <List<DayPlannerEntry>>[];
    final positioned = <({DayPlannerEntry entry, int lane})>[];
    for (final entry in intervalEntries) {
      var lane = 0;
      while (lane < laneEntries.length &&
          laneEntries[lane].any((other) => hasTimeOverlap(entry, other))) {
        lane++;
      }
      if (lane == laneEntries.length) {
        laneEntries.add(<DayPlannerEntry>[entry]);
      } else {
        laneEntries[lane].add(entry);
      }
      positioned.add((entry: entry, lane: lane));
    }

    return positioned;
  }

  static List<({DayPlannerEntry entry, int lane, int columnCount})>
  assignExpandedTimelineColumns(
    Iterable<DayPlannerEntry> entries, {
    int Function(DayPlannerEntry entry)? lanePriority,
  }) {
    final realEntries = entries
        .where((entry) => !entry.isAllDay && !entry.isZeroDuration)
        .toList();
    final remaining = Set<DayPlannerEntry>.from(realEntries);
    final expanded = <({DayPlannerEntry entry, int lane, int columnCount})>[];

    while (remaining.isNotEmpty) {
      final component = <DayPlannerEntry>[];
      final pending = <DayPlannerEntry>[remaining.first];
      remaining.remove(pending.first);
      while (pending.isNotEmpty) {
        final entry = pending.removeLast();
        component.add(entry);
        final connected = remaining
            .where((other) => hasTimeOverlap(entry, other))
            .toList();
        for (final other in connected) {
          remaining.remove(other);
          pending.add(other);
        }
      }

      final positioned = assignLeftmostFreeLanes(
        component,
        lanePriority: lanePriority,
      );
      final columnCount = positioned.isEmpty
          ? 1
          : positioned
                .map((item) => item.lane + 1)
                .reduce((a, b) => a > b ? a : b);
      expanded.addAll(
        positioned.map(
          (item) =>
              (entry: item.entry, lane: item.lane, columnCount: columnCount),
        ),
      );
    }

    return expanded;
  }

  static int _defaultLanePriority(DayPlannerEntry entry) {
    if (entry.type == 'focus' || entry.type == 'buffer') return 1;
    if (_isFocusBreak(entry)) return 1;
    if (entry.type == 'calendar') {
      return entry.subtitle?.toLowerCase().contains('work') == true ? 1 : 3;
    }
    if (entry.type == 'personal') return 4;
    if (entry.type == 'movement') return 6;
    if (entry.type == 'break') return 6;
    return 3;
  }

  static List<({DayPlannerEntry entry, int slot})>
  assignZeroDurationMarkerSlots(
    Iterable<DayPlannerEntry> entries, {
    int Function(DayPlannerEntry entry)? lanePriority,
  }) {
    final occupiedByStart = <DateTime, Set<int>>{};
    final orderedEntries =
        entries
            .where((entry) => !entry.isAllDay && entry.isZeroDuration)
            .toList()
          ..sort((a, b) {
            final startCompare = a.start.compareTo(b.start);
            if (startCompare != 0) return startCompare;
            final priorityCompare =
                (lanePriority?.call(a) ?? _defaultLanePriority(a)).compareTo(
                  lanePriority?.call(b) ?? _defaultLanePriority(b),
                );
            if (priorityCompare != 0) return priorityCompare;
            return a.id.compareTo(b.id);
          });

    final positioned = <({DayPlannerEntry entry, int slot})>[];
    for (final entry in orderedEntries) {
      final occupiedSlots = occupiedByStart.putIfAbsent(
        entry.start,
        () => <int>{},
      );
      var slot = 0;
      while (occupiedSlots.contains(slot)) {
        slot++;
      }
      occupiedSlots.add(slot);
      positioned.add((entry: entry, slot: slot));
    }

    return positioned;
  }

  String _eventTooltipMessage(
    DayPlannerEntry entry,
    String categoryLabel,
    String timeLabel,
    String? subtitle, [
    List<String> labels = const <String>[],
  ]) {
    final details = <String>[
      entry.title,
      'Category: $categoryLabel',
      'Time: $timeLabel',
    ];
    final trimmedSubtitle = subtitle?.trim();
    if (trimmedSubtitle != null &&
        trimmedSubtitle.isNotEmpty &&
        trimmedSubtitle.toLowerCase() != categoryLabel.toLowerCase()) {
      details.add(trimmedSubtitle);
    }
    final visibleLabels = labels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList();
    if (visibleLabels.isNotEmpty) {
      details.add('Label: ${visibleLabels.join(', ')}');
    }
    return details.join('\n');
  }

  // Kept temporarily for compatibility with older timeline snapshots.
  // ignore: unused_element
  Widget _buildPlannerEntryCard(
    BuildContext context,
    DayPlannerEntry entry, {
    double height = 80,
  }) {
    final isTask = entry.type == 'task';
    final isCalendar = entry.type == 'calendar';
    final isAllDayCalendarEntry = isCalendar && entry.isAllDay;
    final now = DateTime.now();
    final workCalendarColor = const Color(0xFFD95F02);
    final workTaskColor = const Color(0xFFF28E2B);
    final homeColor = const Color(0xFF124B8A);
    final plannerColor = const Color(0xFF7C4DFF);
    final breakColor = const Color(0xFF455A64);
    final movementColor = const Color(0xFF2E8B57);
    final personalColor = const Color(0xFFB23A48);
    final isMovement = entry.type == 'movement';
    final isWalkingBreak = _isWalkingBreakEntry(entry);
    final isCompleted = entry.executionState == ExecutionState.completed;
    final isSkipped = entry.executionState == ExecutionState.skipped;
    final isDeferred = entry.executionState == ExecutionState.deferred;
    final isDismissed = entry.executionState == ExecutionState.dismissed;
    final isCompact = height < 76;
    // The card's internal padding reduces the usable action-column height.
    // Treat near-minimum cards as tiny before their nominal height reaches 46.
    final isTiny = height <= 50;
    final isPreferredConcurrent = preferredConcurrentEntryIds.contains(
      entry.id,
    );
    final categoryLabel = _eventCategoryLabel(entry);

    final isWorkTaskEntry =
        isTask && entry.task != null && isWorkTask(entry.task!);
    final isWorkCalendarEntry =
        isCalendar && (entry.subtitle?.toLowerCase().contains('work') ?? false);
    final isHomeTaskEntry =
        isTask && entry.task != null && !isWorkTask(entry.task!);
    final isHomeCalendarEntry =
        isCalendar && (entry.subtitle?.toLowerCase().contains('home') ?? false);

    final color = entry.type == 'personal'
        ? personalColor
        : entry.type == 'break'
        ? breakColor
        : entry.type == 'buffer'
        ? workTaskColor
        : entry.type == 'admin'
        ? workTaskColor
        : isWalkingBreak
        ? breakColor
        : isMovement
        ? movementColor
        : (isWorkTaskEntry || isWorkCalendarEntry)
        ? (isWorkCalendarEntry ? workCalendarColor : workTaskColor)
        : (isHomeTaskEntry || isHomeCalendarEntry)
        ? homeColor
        : plannerColor;
    final effectiveEnd = entry.end.isAfter(entry.start)
        ? entry.end
        : entry.start.add(const Duration(minutes: 5));
    final isCurrentEntry =
        !now.isBefore(entry.start) && now.isBefore(effectiveEnd);
    final isPastDue =
        entry.executionState == ExecutionState.pending &&
        entry.end.isBefore(now) &&
        entry.type != 'calendar';

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
    if (isPastDue) {
      subtitle = subtitle == null || subtitle.trim().isEmpty
          ? 'Past due'
          : 'Past due • $subtitle';
    }
    if (isDeferred) subtitle = 'Deferred • ${subtitle ?? 'Planner item'}';
    if (isDismissed) subtitle = 'Dismissed • ${subtitle ?? 'Planner item'}';

    final timeLabel = isAllDayCalendarEntry
        ? 'All day'
        : '${entry.start.hour.toString().padLeft(2, '0')}:${entry.start.minute.toString().padLeft(2, '0')}–${entry.end.hour.toString().padLeft(2, '0')}:${entry.end.minute.toString().padLeft(2, '0')}';

    return Tooltip(
      message: _eventTooltipMessage(
        entry,
        categoryLabel,
        timeLabel,
        subtitle,
        entry.labels,
      ),
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
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
              isCompleted || isSkipped || isDeferred || isDismissed
                  ? 28
                  : (isCurrentEntry ? 85 : 70),
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withAlpha(isCurrentEntry ? 255 : 210),
              width: isCalendar ? 2.5 : (isCurrentEntry ? 2.2 : 1),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                                decoration: isCompleted || isDismissed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isSkipped || isDismissed
                                    ? Colors.grey
                                    : isDeferred
                                    ? Colors.orange.shade800
                                    : null,
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
                        Text(
                          'Category: $categoryLabel',
                          style: TextStyle(
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.w700,
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
                  if (!isNarrowLane &&
                      (constraints.maxHeight >= 70 ||
                          (isCalendar && constraints.maxHeight >= 50)))
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
                                    constraints: const BoxConstraints.tightFor(
                                      width: 22,
                                      height: 22,
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
                                    constraints: const BoxConstraints.tightFor(
                                      width: 22,
                                      height: 22,
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
                                  if (!isCompact)
                                    PopupMenuButton<ExecutionState>(
                                      tooltip: 'More planner actions',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 22,
                                            height: 22,
                                          ),
                                      icon: const Icon(
                                        Icons.more_horiz,
                                        size: 15,
                                      ),
                                      onSelected: (state) =>
                                          onExecutePlannerEntry(entry, state),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: ExecutionState.deferred,
                                          child: Text('Defer'),
                                        ),
                                        PopupMenuItem(
                                          value: ExecutionState.dismissed,
                                          child: Text('Dismiss'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            if (isCalendar && !isAllDayCalendarEntry)
                              Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Builder(
                                    builder: (buttonContext) {
                                      return IconButton(
                                        tooltip: 'Event actions',
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          size: 19,
                                        ),
                                        onPressed: () async {
                                          final button =
                                              buttonContext.findRenderObject()
                                                  as RenderBox;
                                          final overlay =
                                              Overlay.of(
                                                    buttonContext,
                                                  ).context.findRenderObject()
                                                  as RenderBox;
                                          final topLeft = button.localToGlobal(
                                            Offset.zero,
                                            ancestor: overlay,
                                          );
                                          final bottomRight = button
                                              .localToGlobal(
                                                button.size.bottomRight(
                                                  Offset.zero,
                                                ),
                                                ancestor: overlay,
                                              );
                                          final action = await showMenu<String>(
                                            context: buttonContext,
                                            position: RelativeRect.fromRect(
                                              Rect.fromPoints(
                                                topLeft,
                                                bottomRight,
                                              ),
                                              Offset.zero & overlay.size,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 240,
                                            ),
                                            items: [
                                              PopupMenuItem<String>(
                                                value: 'pair',
                                                child: Text(
                                                  isPreferredConcurrent
                                                      ? 'Remove movement pairing'
                                                      : 'Pair movement with this event',
                                                ),
                                              ),
                                              if (isHomeCalendarEntry)
                                                PopupMenuItem<String>(
                                                  value: 'planning',
                                                  child: Text(
                                                    nonBlockingCalendarEventIds
                                                            .contains(entry.id)
                                                        ? 'Include in planning'
                                                        : 'Exclude from planning',
                                                  ),
                                                ),
                                              if (isHomeCalendarEntry)
                                                const PopupMenuItem<String>(
                                                  value: 'gym',
                                                  child: Text(
                                                    'Log as gym session',
                                                  ),
                                                ),
                                              const PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Text('Delete activity'),
                                              ),
                                            ],
                                          );
                                          if (action == 'pair') {
                                            final next = Set<String>.from(
                                              preferredConcurrentEntryIds,
                                            );
                                            if (!next.add(entry.id)) {
                                              next.remove(entry.id);
                                            }
                                            onPreferredConcurrentEntryIdsChanged(
                                              next,
                                            );
                                          } else if (action == 'remove') {
                                            onDeleteActivity(entry);
                                          } else if (action == 'planning') {
                                            final next = Set<String>.from(
                                              nonBlockingCalendarEventIds,
                                            );
                                            if (!next.add(entry.id)) {
                                              next.remove(entry.id);
                                            }
                                            onToggleCalendarPlanning(next);
                                          } else if (action == 'gym') {
                                            onLogHomeEventAsGym(entry);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (!isTiny &&
                                !isCompact &&
                                entry.type != 'calendar' &&
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
                                    onPressed: () => _showEditEntryTimeDialog(
                                      context,
                                      entry,
                                    ),
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
      ),
    );
  }

  Widget _buildCompactTimelineEventCard(
    BuildContext context,
    DayPlannerEntry entry, {
    required double height,
  }) {
    final isCalendar = entry.type == 'calendar';
    final isAllDay = isCalendar && entry.isAllDay;
    final isHomeCalendar =
        isCalendar && (entry.subtitle?.toLowerCase().contains('home') ?? false);
    final isExcludedFromPlanning =
        isHomeCalendar && !_isHomeCalendarIncludedInPlanning(entry);
    final isWalkingBreak = _isWalkingBreakEntry(entry);
    final isCompleted = entry.executionState == ExecutionState.completed;
    final isSkipped = entry.executionState == ExecutionState.skipped;
    final isDismissed = entry.executionState == ExecutionState.dismissed;
    final color = entry.type == 'personal'
        ? const Color(0xFFB23A48)
        : entry.type == 'break'
        ? const Color(0xFF455A64)
        : entry.type == 'buffer'
        ? const Color(0xFFF28E2B)
        : entry.type == 'admin'
        ? const Color(0xFFF28E2B)
        : isWalkingBreak
        ? const Color(0xFF455A64)
        : entry.type == 'movement'
        ? const Color(0xFF2E8B57)
        : entry.type == 'task'
        ? (entry.task != null && isWorkTask(entry.task!)
              ? const Color(0xFFF28E2B)
              : const Color(0xFF124B8A))
        : isCalendar
        ? isHomeCalendar
              ? const Color(0xFF124B8A)
              : const Color(0xFFD95F02)
        : const Color(0xFF5B65C5);
    final timeText = isAllDay
        ? 'All day'
        : entry.isZeroDuration
        ? _formatMinutes(entry.start.hour * 60 + entry.start.minute)
        : '${_formatMinutes(entry.start.hour * 60 + entry.start.minute)} - ${_formatMinutes(entry.end.hour * 60 + entry.end.minute)}';
    final categoryLabel = _eventCategoryLabel(entry);

    Future<void> showActions(BuildContext buttonContext) async {
      final actions = <String>[];
      if (!isCalendar) {
        actions.addAll(['complete', 'skip', 'defer', 'delete']);
        actions.add('edit');
        actions.add('lock');
      } else {
        if (!isAllDay) {
          actions.add('pair');
        }
        actions.add('delete');
      }
      if (actions.isEmpty) return;

      final button = buttonContext.findRenderObject() as RenderBox?;
      final overlay =
          Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
      if (button == null || overlay == null) return;
      final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
      final bottomRight = button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      );
      final selected = await showMenu<String>(
        context: buttonContext,
        position: RelativeRect.fromRect(
          Rect.fromPoints(topLeft, bottomRight),
          Offset.zero & overlay.size,
        ),
        constraints: const BoxConstraints(minWidth: 220),
        items: [
          if (!isCalendar) ...[
            PopupMenuItem(
              value: 'complete',
              child: Text(isCompleted ? 'Undo completion' : 'Mark complete'),
            ),
            const PopupMenuItem(value: 'skip', child: Text('Skip')),
            const PopupMenuItem(value: 'defer', child: Text('Defer')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete activity'),
            ),
            const PopupMenuItem(value: 'edit', child: Text('Edit time')),
            PopupMenuItem(
              value: 'lock',
              child: Text(entry.isLocked ? 'Unlock time' : 'Lock time'),
            ),
          ] else ...[
            if (isHomeCalendar)
              PopupMenuItem(
                value: 'planning',
                child: Text(
                  _isHomeCalendarIncludedInPlanning(entry)
                      ? 'Exclude from planning'
                      : 'Include in planning',
                ),
              ),
            if (isHomeCalendar)
              const PopupMenuItem(
                value: 'gym',
                child: Text('Log as gym session'),
              ),
            PopupMenuItem(
              value: 'pair',
              child: Text(
                preferredConcurrentEntryIds.contains(entry.id)
                    ? 'Remove movement pairing'
                    : 'Pair movement with this event',
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete activity'),
            ),
          ],
        ],
      );
      if (!context.mounted || selected == null) return;
      switch (selected) {
        case 'complete':
          onExecutePlannerEntry(
            entry,
            isCompleted ? ExecutionState.pending : ExecutionState.completed,
          );
        case 'skip':
          onExecutePlannerEntry(entry, ExecutionState.skipped);
        case 'defer':
          onExecutePlannerEntry(entry, ExecutionState.deferred);
        case 'edit':
          await _showEditEntryTimeDialog(context, entry);
        case 'lock':
          onTogglePlannerEntryLock(entry.id, !entry.isLocked);
        case 'pair':
          final next = Set<String>.from(preferredConcurrentEntryIds);
          if (!next.add(entry.id)) next.remove(entry.id);
          onPreferredConcurrentEntryIdsChanged(next);
        case 'planning':
          final next = Set<String>.from(nonBlockingCalendarEventIds);
          final included = Set<String>.from(includedCalendarEventIds);
          if (_isHomeCalendarIncludedInPlanning(entry)) {
            next.add(entry.id);
            included.remove(entry.id);
          } else {
            next.remove(entry.id);
            included.add(entry.id);
          }
          onToggleCalendarPlanning(next);
          onToggleIncludedCalendarPlanning?.call(included);
        case 'gym':
          onLogHomeEventAsGym(entry);
        case 'delete':
          onDeleteActivity(entry);
      }
    }

    return Tooltip(
      message: _eventTooltipMessage(
        entry,
        categoryLabel,
        timeText,
        entry.subtitle,
        entry.labels,
      ),
      waitDuration: const Duration(milliseconds: 350),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          height: isAllDay
              ? (height < 48 ? 48 : height)
              : height.clamp(1.0, double.infinity),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          decoration: BoxDecoration(
            color: color.withAlpha(
              isCompleted || isSkipped || isDismissed
                  ? 28
                  : (isExcludedFromPlanning ? 45 : 70),
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withAlpha(230),
              width: isCalendar ? 2.5 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showInlineDetails = constraints.maxWidth >= 220;
              return Row(
                children: [
                  Container(
                    width: 5,
                    height: entry.isZeroDuration ? 16 : 18,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  if (showInlineDetails) ...[
                    const SizedBox(width: 7),
                    Text(
                      timeText,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        decoration: isCompleted || isDismissed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (showInlineDetails)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, right: 2),
                        child: Text(
                          categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  if (isExcludedFromPlanning)
                    const Tooltip(
                      message: 'Excluded from planning',
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 15,
                        color: Colors.blueGrey,
                      ),
                    ),
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: 'Activity actions',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: entry.isZeroDuration ? 22 : 24,
                        height: entry.isZeroDuration ? 22 : 24,
                      ),
                      icon: const Icon(Icons.more_horiz, size: 18),
                      onPressed: () => showActions(buttonContext),
                    ),
                  ),
                ],
              );
            },
          ),
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

  Future<void> _showAddPersonalBlockDialog(
    BuildContext context,
    DateTime date,
  ) async {
    const personalBlockNameOptions = [
      'Annual leave',
      'Doctor appointment',
      'Dentist appointment',
      'School run',
      'Family commitment',
      'Travel time',
      'Personal errand',
      'Rest and recovery',
    ];
    var title = '';
    var startTime = const TimeOfDay(hour: 9, minute: 0);
    var endTime = const TimeOfDay(hour: 10, minute: 0);
    final result = await showDialog<(String, TimeOfDay, TimeOfDay)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add personal block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  if (query.isEmpty) {
                    return personalBlockNameOptions;
                  }
                  return personalBlockNameOptions.where(
                    (option) => option.toLowerCase().contains(query),
                  );
                },
                onSelected: (value) => title = value,
                fieldViewBuilder:
                    (context, fieldController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: fieldController,
                        focusNode: focusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Choose or type a personal event',
                        ),
                        onSubmitted: (_) => onFieldSubmitted(),
                        onChanged: (value) => title = value,
                      );
                    },
              ),
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
                  if (picked != null) setDialogState(() => startTime = picked);
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
                  if (picked != null) setDialogState(() => endTime = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmedTitle = title.trim();
                if (trimmedTitle.isEmpty) return;
                Navigator.of(
                  dialogContext,
                ).pop((trimmedTitle, startTime, endTime));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final startMinutes = result.$2.hour * 60 + result.$2.minute;
    final endMinutes = result.$3.hour * 60 + result.$3.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    onAddPersonalBlock(date, result.$1, startMinutes, endMinutes);
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
    final timelineContentHeight = height * 4;
    final allDayEntries = entries.where((entry) => entry.isAllDay).toList();

    final positionedEntries = assignExpandedTimelineColumns(
      entries,
      lanePriority: _lanePriority,
    );
    final laneCount = positionedEntries.isEmpty
        ? 1
        : positionedEntries
              .map((entry) => entry.columnCount)
              .reduce((a, b) => a > b ? a : b);
    final zeroDurationEntries = entries
        .where((entry) => !entry.isAllDay && entry.isZeroDuration)
        .toList();
    final zeroDurationMarkerSlots = assignZeroDurationMarkerSlots(
      zeroDurationEntries,
      lanePriority: _lanePriority,
    );
    final zeroDurationSlotMap = {
      for (final item in zeroDurationMarkerSlots) item.entry.id: item.slot,
    };
    const timeAxisWidth = 48.0;
    const laneGap = 4.0;
    const markerWidth = 120.0;
    const markerGap = 8.0;
    const markerSlotPitch = markerWidth + markerGap;
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
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 6),
                      itemCount: allDayEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => SizedBox(
                        width: 180,
                        child: _buildCompactTimelineEventCard(
                          context,
                          allDayEntries[index],
                          height: 76,
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
                final markerSlotCount = zeroDurationMarkerSlots.isEmpty
                    ? 1
                    : zeroDurationMarkerSlots
                          .map((marker) => marker.slot + 1)
                          .reduce((a, b) => a > b ? a : b);
                final minimumTimelineWidth =
                    timeAxisWidth +
                    (laneCount * 180) +
                    ((laneCount - 1) * laneGap);
                final markerMinimumWidth =
                    timeAxisWidth + (markerSlotCount * markerSlotPitch);
                final requiredTimelineWidth =
                    minimumTimelineWidth > markerMinimumWidth
                    ? minimumTimelineWidth
                    : markerMinimumWidth;
                final timelineWidth =
                    constraints.maxWidth > requiredTimelineWidth
                    ? constraints.maxWidth
                    : requiredTimelineWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  child: SizedBox(
                    width: timelineWidth,
                    height: timelineContentHeight,
                    child: _TimelineVerticalScrollView(
                      initialScrollOffset: timelineContentHeight / 4,
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
                                child: SizedBox(
                                  height: 18,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 0,
                                        left: timeAxisWidth,
                                        right: 0,
                                        child: Divider(
                                          color: timelineColor,
                                          height: 1,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
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
                                    ],
                                  ),
                                ),
                              ),
                            for (
                              var halfHour = 30;
                              halfHour < totalMinutes;
                              halfHour += 60
                            )
                              Positioned(
                                top:
                                    (halfHour / totalMinutes) *
                                    timelineContentHeight,
                                left: timeAxisWidth,
                                right: 0,
                                height: 1,
                                child: CustomPaint(
                                  painter: _DashedTimelineLinePainter(
                                    color: timelineColor.withAlpha(180),
                                  ),
                                ),
                              ),
                            for (final positioned in positionedEntries)
                              if (positioned.lane < laneCount)
                                Builder(
                                  builder: (context) {
                                    final visibleStart =
                                        positioned.entry.start.isBefore(start)
                                        ? start
                                        : positioned.entry.start;
                                    final visibleEnd =
                                        positioned.entry.end.isAfter(end)
                                        ? end
                                        : positioned.entry.end;
                                    final topMinutes = visibleStart
                                        .difference(start)
                                        .inMinutes
                                        .clamp(0, totalMinutes);
                                    final durationMinutes = visibleEnd
                                        .difference(visibleStart)
                                        .inMinutes
                                        .clamp(12, totalMinutes);
                                    final top =
                                        topMinutes /
                                        totalMinutes *
                                        timelineContentHeight;
                                    final cardHeight =
                                        durationMinutes /
                                        totalMinutes *
                                        timelineContentHeight;
                                    final eventLaneWidth =
                                        (timelineWidth -
                                            timeAxisWidth -
                                            ((positioned.columnCount - 1) *
                                                laneGap)) /
                                        positioned.columnCount;
                                    return Positioned(
                                      top: top,
                                      left:
                                          timeAxisWidth +
                                          positioned.lane *
                                              (eventLaneWidth + laneGap),
                                      width: eventLaneWidth,
                                      height: cardHeight.clamp(
                                        1.0,
                                        timelineContentHeight,
                                      ),
                                      child: _buildCompactTimelineEventCard(
                                        context,
                                        positioned.entry,
                                        height: cardHeight.clamp(
                                          1.0,
                                          timelineContentHeight,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            for (
                              var markerIndex = 0;
                              markerIndex < zeroDurationEntries.length;
                              markerIndex++
                            )
                              Builder(
                                builder: (context) {
                                  final marker =
                                      zeroDurationEntries[markerIndex];
                                  final slot =
                                      zeroDurationSlotMap[marker.id] ?? 0;
                                  final topMinutes = marker.start
                                      .difference(start)
                                      .inMinutes
                                      .clamp(0, totalMinutes);
                                  final top =
                                      topMinutes /
                                      totalMinutes *
                                      timelineContentHeight;
                                  final horizontalOffset =
                                      slot * markerSlotPitch;
                                  final x = timeAxisWidth + horizontalOffset;
                                  return Positioned(
                                    top: top - 10,
                                    left: x,
                                    width: markerWidth,
                                    height: 26,
                                    child: Tooltip(
                                      message: _eventTooltipMessage(
                                        marker,
                                        _eventCategoryLabel(marker),
                                        _formatTime(marker.start),
                                        marker.subtitle,
                                        marker.labels,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          if (context.mounted) {
                                            _showEditEntryTimeDialog(
                                              context,
                                              marker,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade700,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  marker.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
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
        final filteredCalendarEvents = events.where((event) {
          final isAppGeneratedEvent = event.labels.any(
            (label) => label.trim().toLowerCase() == 'adhd assistant',
          );
          if (isAppGeneratedEvent) {
            return false;
          }
          final isWorkCalendar = event.calendarSource == 'work';
          if (isWorkCalendar && !showWorkCalendarInPlanner) {
            return false;
          }
          if (!isWorkCalendar && !showHomeCalendarInPlanner) {
            return false;
          }

          final start = event.start?.toLocal();
          if (start == null) {
            return false;
          }
          if (removedPlannerEntryIds.contains('calendar-${event.id}') ||
              removedCalendarEventIds.contains(event.id)) {
            return false;
          }

          return true;
        }).toList();

        final filteredTasks = tasks.where((task) {
          final isWorkTaskValue = isWorkTask(task);
          if (isWorkTaskValue && !showWorkTasksInPlanner) {
            return false;
          }
          if (!isWorkTaskValue && !showHomeTasksInPlanner) {
            return false;
          }
          return true;
        }).toList();

        final manualDayContext = DayContext(
          gymMorning: gymAvailable,
          workLocation: wfhAvailable ? WorkLocation.home : WorkLocation.office,
          eveningAvailable: eveningAvailable,
        );
        final resolvedPlannerContext = PlannerContextResolver.resolve(
          day: selectedPlannerDate,
          manualContext: manualDayContext,
          calendarEvents: filteredCalendarEvents,
        );
        final dayContext = resolvedPlannerContext.dayContext;

        final plannerResult = DayPlannerService.buildPlan(
          tasks: filteredTasks,
          calendarEvents: filteredCalendarEvents,
          day: selectedPlannerDate,
          dayContext: dayContext,
          weeklyTotals: weeklyActivityTotals,
          gymCompletedToday: gymCompletedToday,
          daysSinceLastMobility: daysSinceLastMobility,
          preferredConcurrentEntryIds: preferredConcurrentEntryIds,
          nonBlockingCalendarEventIds: nonBlockingCalendarEventIds,
          includedCalendarEventIds: includedCalendarEventIds,
          workdayStartMinutes: workdayStartMinutes,
          workdayEndMinutes: workdayEndMinutes,
          entryOverrides: plannerEntryOverrides,
          excludedPlannerEntryIds: removedPlannerEntryIds,
          planningStart: planningStart,
          personalBlocks: personalBlocks,
          executionStates: executionStates,
          timeGrid: timeGrid,
        );
        if (onPlannerResultBuilt != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onPlannerResultBuilt?.call(
              selectedPlannerDate,
              plannerResult.entries,
            );
          });
        }
        final visiblePlannerEntries = plannerResult.entries.where((entry) {
          if (entry.executionState == ExecutionState.dismissed) {
            return false;
          }
          return switch (_plannerFilterCategory(entry)) {
            _PlannerFilterCategory.workCalendar => showWorkCalendarInPlanner,
            _PlannerFilterCategory.workTasks => showWorkTasksInPlanner,
            _PlannerFilterCategory.homeCalendar => showHomeCalendarInPlanner,
            _PlannerFilterCategory.homeTasks => showHomeTasksInPlanner,
            _PlannerFilterCategory.personal => showPersonalInPlanner,
            _PlannerFilterCategory.movement => showMovementInPlanner,
            _PlannerFilterCategory.breakEntry => showBreakInPlanner,
            _PlannerFilterCategory.other => true,
          };
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: availableHeight > 140 ? 104 : null,
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
                  const SizedBox(height: 10),
                  _buildContextSection(
                    context,
                    dayContext,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 8),
                  _buildTimelineFilters(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: visiblePlannerEntries.isEmpty
                        ? Center(
                            child: Text(
                              'Nothing to show with current filters.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, timelineConstraints) {
                              return _buildPlannerTimeline(
                                day: selectedPlannerDate,
                                entries: visiblePlannerEntries,
                                height: timelineConstraints.maxHeight,
                              );
                            },
                          ),
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

  Widget _buildTimelineFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline filters',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPlannerToggleChip(
                  label: 'Work calendar',
                  selected: showWorkCalendarInPlanner,
                  chipColor: const Color(0xFFD95F02),
                  onChanged: onShowWorkCalendarInPlannerChanged ?? (_) {},
                  width: 128,
                ),
                const SizedBox(width: 2),
                _buildPlannerToggleChip(
                  label: 'Work tasks',
                  selected: showWorkTasksInPlanner,
                  chipColor: const Color(0xFFF28E2B),
                  onChanged: onShowWorkTasksInPlannerChanged ?? (_) {},
                  width: 128,
                ),
                const SizedBox(width: 2),
                _buildPlannerToggleChip(
                  label: 'Home calendar',
                  selected: showHomeCalendarInPlanner,
                  chipColor: const Color(0xFF124B8A),
                  onChanged: onShowHomeCalendarInPlannerChanged ?? (_) {},
                  width: 128,
                ),
                const SizedBox(width: 2),
                _buildPlannerToggleChip(
                  label: 'Home tasks',
                  selected: showHomeTasksInPlanner,
                  chipColor: const Color(0xFF0D3B6E),
                  onChanged: onShowHomeTasksInPlannerChanged ?? (_) {},
                  width: 128,
                ),
                const SizedBox(width: 2),
                _buildPlannerToggleChip(
                  label: 'Movement',
                  selected: showMovementInPlanner,
                  chipColor: const Color(0xFF2E8B57),
                  onChanged: onShowMovementInPlannerChanged,
                  width: 128,
                ),
                const SizedBox(width: 2),
                _buildPlannerToggleChip(
                  label: 'Personal',
                  selected: showPersonalInPlanner,
                  chipColor: const Color(0xFFB23A48),
                  onChanged: onShowPersonalInPlannerChanged,
                  width: 128,
                ),
                const SizedBox(width: 2),
                _buildPlannerToggleChip(
                  label: 'Break',
                  selected: showBreakInPlanner,
                  chipColor: const Color(0xFF455A64),
                  onChanged: onShowBreakInPlannerChanged,
                  width: 128,
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildContextSection(
    BuildContext context,
    DayContext dayContext, {
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Planner context',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day context',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            _buildPlannerToggleChip(
                              label: dayContext.gymMorning
                                  ? 'Gym morning'
                                  : 'No Gym',
                              selected: dayContext.gymMorning,
                              chipColor: Colors.deepOrange,
                              onChanged: onGymAvailableChanged,
                            ),
                            const SizedBox(width: 6),
                            _buildPlannerToggleChip(
                              label:
                                  dayContext.workLocation == WorkLocation.home
                                  ? 'WFH'
                                  : 'Office',
                              selected:
                                  dayContext.workLocation == WorkLocation.home,
                              chipColor: Colors.blue,
                              onChanged: onWfhAvailableChanged,
                            ),
                            const SizedBox(width: 6),
                            _buildPlannerToggleChip(
                              label: dayContext.eveningAvailable
                                  ? 'Evening Available'
                                  : 'Evening Unavailable',
                              selected: dayContext.eveningAvailable,
                              chipColor: Colors.teal,
                              onChanged: onEveningAvailableChanged,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 38,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.blueGrey.shade200,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Work window',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  _pickWorkdayTime(context, isStart: true),
                              child: Text(_formatMinutes(workdayStartMinutes)),
                            ),
                            const Text('to', style: TextStyle(fontSize: 10)),
                            OutlinedButton(
                              onPressed: () =>
                                  _pickWorkdayTime(context, isStart: false),
                              child: Text(_formatMinutes(workdayEndMinutes)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
          if (quickCaptureSection != null) ...[
            quickCaptureSection!,
            const SizedBox(height: 14),
          ],
          nextActionWidget,
          const SizedBox(height: 14),
          _buildSectionLabel('Timeline'),
          SizedBox(
            height: 420,
            child: _buildPlannerTimeline(
              day: selectedPlannerDate,
              entries: visiblePlannerEntries,
              height: 420,
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionLabel('Today'),
          Text(
            plannerResult.summary,
            style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
          ),
          const SizedBox(height: 8),
          _buildExecutionSummary(executionSummary),
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
            dailyTotals: dailyActivityTotals,
            onGymAvailableChanged: onGymAvailableChanged,
            onWfhAvailableChanged: onWfhAvailableChanged,
            onEveningAvailableChanged: onEveningAvailableChanged,
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
                const Spacer(),
                IconButton(
                  tooltip: 'Add personal block',
                  icon: const Icon(Icons.add_box_outlined),
                  onPressed: () =>
                      _showAddPersonalBlockDialog(context, selectedPlannerDate),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      Text(
        plannerResult.summary,
        style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
      ),
    ];
  }
}

class _DashedTimelineLinePainter extends CustomPainter {
  const _DashedTimelineLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset((x + dashWidth).clamp(0, size.width), 0.5),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedTimelineLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TimelineVerticalScrollView extends StatefulWidget {
  const _TimelineVerticalScrollView({
    required this.initialScrollOffset,
    required this.child,
  });

  final double initialScrollOffset;
  final Widget child;

  @override
  State<_TimelineVerticalScrollView> createState() =>
      _TimelineVerticalScrollViewState();
}

class _TimelineVerticalScrollViewState
    extends State<_TimelineVerticalScrollView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      primary: false,
      child: widget.child,
    );
  }
}
