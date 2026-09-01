import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/activity_recommendation.dart';
import '../models/task.dart';
import '../services/day_planner_service.dart';
import '../services/movement_recommendation_service.dart';
import '../services/next_action_service.dart';
import '../services/planner_execution_service.dart';
import '../services/planner_context_resolver.dart';
import '../services/one_drive_sync_service.dart';
import '../services/storage_service.dart';
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
  // Shared preset names offered both when adding a personal block and when
  // changing an existing planned activity to a custom (non-task) one.
  static const personalBlockNameOptions = [
    'Annual leave',
    'Doctor appointment',
    'Dentist appointment',
    'School run',
    'Family commitment',
    'Travel time',
    'Personal errand',
    'Rest and recovery',
  ];

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
    this.wfhActivityOptions = const <String>[],
    this.officeActivityOptions = const <String>[],
    this.enabledActivityNames = const <String>[],
    this.onEnabledActivityNamesChanged,
    this.isHoliday = false,
    this.onHolidayChanged,
    required this.weeklyActivityTotals,
    required this.dailyActivityTotals,
    required this.daysSinceLastMobility,
    required this.gymCompletedToday,
    required this.executionStates,
    required this.preferredConcurrentEntryIds,
    this.excludedConcurrentEntryIds = const <String>{},
    required this.nonBlockingCalendarEventIds,
    this.includedCalendarEventIds = const <String>{},
    required this.removedPlannerEntryIds,
    required this.removedCalendarEventIds,
    this.removedCalendarEventKeys = const <String>{},
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
    this.onExcludedConcurrentEntryIdsChanged,
    required this.onToggleCalendarPlanning,
    this.onToggleIncludedCalendarPlanning,
    required this.onLogHomeEventAsGym,
    required this.onDeleteActivity,
    required this.onWorkdayHoursChanged,
    required this.onEditPlannerEntryTime,
    required this.onTogglePlannerEntryLock,
    this.onChangePlannerEntryActivity,
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
    this.onReplanFromNow,
    this.onReplanAll,
    this.onResetDay,
    this.showHeaderTitle = true,
    required this.hasFrozenPlanForDate,
    required this.frozenEntriesForDate,
    required this.frozenSummaryForDate,
    this.ignoreFrozenPlan = false,
    this.onPlanBuilt,
    this.onImportOutlook,
    this.onImportIcs,
    this.showImportIcsOption = true,
    this.onExportDay,
    this.onExportAll,
    this.isBusy = false,
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
  final List<String> wfhActivityOptions;
  final List<String> officeActivityOptions;
  final List<String> enabledActivityNames;
  final ValueChanged<Set<String>>? onEnabledActivityNamesChanged;
  final bool isHoliday;
  final ValueChanged<bool>? onHolidayChanged;
  final WeeklyActivityTotals weeklyActivityTotals;
  final DailyActivityTotals dailyActivityTotals;
  final int daysSinceLastMobility;
  final bool gymCompletedToday;
  final Map<String, ExecutionState> executionStates;
  final Set<String> preferredConcurrentEntryIds;
  final Set<String> excludedConcurrentEntryIds;
  final Set<String> nonBlockingCalendarEventIds;
  final Set<String> includedCalendarEventIds;
  final Set<String> removedPlannerEntryIds;
  final Set<String> removedCalendarEventIds;
  final Set<String> removedCalendarEventKeys;
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
  final ValueChanged<Set<String>>? onExcludedConcurrentEntryIdsChanged;
  final ValueChanged<Set<String>> onToggleCalendarPlanning;
  final ValueChanged<Set<String>>? onToggleIncludedCalendarPlanning;
  final ValueChanged<DayPlannerEntry> onLogHomeEventAsGym;
  final ValueChanged<DayPlannerEntry> onDeleteActivity;
  final ValueChanged<(int, int)> onWorkdayHoursChanged;
  // Called with (entryId, startMinutes, endMinutes) when the user edits an entry's time.
  final void Function(String entryId, int startMinutes, int endMinutes)
  onEditPlannerEntryTime;
  final void Function(String entryId, bool locked) onTogglePlannerEntryLock;
  // Reassigns a slot to a task (taskId) or a free-typed/preset name (customTitle).
  final void Function(String entryId, {String? taskId, String? customTitle})?
  onChangePlannerEntryActivity;
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
  final VoidCallback? onReplanFromNow;
  final VoidCallback? onReplanAll;
  // Undoes all manual edits/overrides for the currently selected day and
  // rebuilds it from scratch; only ever offered for the current day (offset
  // 0), never for future days.
  final VoidCallback? onResetDay;
  final bool showHeaderTitle;
  // Frozen-plan plumbing: once a day's plan is shown, it stays put (no
  // reshuffling on unrelated app changes) until the user explicitly replans.
  final bool Function(DateTime date) hasFrozenPlanForDate;
  final List<DayPlannerEntry> Function(DateTime date) frozenEntriesForDate;
  final String Function(DateTime date) frozenSummaryForDate;
  // True while a manual replan is in flight; forces a fresh rebuild for this
  // frame so the caller can capture+freeze the new plan.
  final bool ignoreFrozenPlan;
  final void Function(DateTime date, DayPlannerResult result)? onPlanBuilt;
  // Import/export menu buttons shown at the right end of the title row when
  // provided (only rendered alongside "Daily Timeline" when showHeaderTitle).
  final VoidCallback? onImportOutlook;
  final VoidCallback? onImportIcs;
  final bool showImportIcsOption;
  final VoidCallback? onExportDay;
  final VoidCallback? onExportAll;
  final bool isBusy;

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
              ? const Color(0xFF124B8A)
              : const Color(0xFFF28E2B))
        : isCalendar
        ? isHomeCalendar
              ? const Color(0xFFD95F02)
              : const Color(0xFF124B8A)
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
        actions.addAll(['complete', 'delete']);
        actions.add('edit');
        actions.add('lock');
        if (onChangePlannerEntryActivity != null) {
          actions.add('changeActivity');
        }
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
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete activity'),
            ),
            const PopupMenuItem(value: 'edit', child: Text('Edit time')),
            PopupMenuItem(
              value: 'lock',
              child: Text(entry.isLocked ? 'Unlock time' : 'Lock time'),
            ),
            if (onChangePlannerEntryActivity != null)
              const PopupMenuItem(
                value: 'changeActivity',
                child: Text('Change activity'),
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
            if (preferredConcurrentEntryIds.contains(entry.id))
              const PopupMenuItem(
                value: 'pair',
                child: Text('Remove movement pairing'),
              )
            else if (excludedConcurrentEntryIds.contains(entry.id))
              const PopupMenuItem(
                value: 'allowPair',
                child: Text('Allow movement pairing'),
              )
            else ...[
              const PopupMenuItem(
                value: 'pair',
                child: Text('Pair movement with this event'),
              ),
              if (onExcludedConcurrentEntryIdsChanged != null)
                const PopupMenuItem(
                  value: 'excludePair',
                  child: Text("Don't pair movement with this event"),
                ),
            ],
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
        case 'edit':
          await _showEditEntryTimeDialog(context, entry);
        case 'lock':
          onTogglePlannerEntryLock(entry.id, !entry.isLocked);
        case 'changeActivity':
          await _showChangeActivityDialog(context, entry);
        case 'pair':
          final next = Set<String>.from(preferredConcurrentEntryIds);
          if (!next.add(entry.id)) next.remove(entry.id);
          onPreferredConcurrentEntryIdsChanged(next);
          if (excludedConcurrentEntryIds.contains(entry.id)) {
            onExcludedConcurrentEntryIdsChanged?.call(
              Set<String>.from(excludedConcurrentEntryIds)..remove(entry.id),
            );
          }
        case 'excludePair':
          onExcludedConcurrentEntryIdsChanged?.call(
            Set<String>.from(excludedConcurrentEntryIds)..add(entry.id),
          );
          if (preferredConcurrentEntryIds.contains(entry.id)) {
            onPreferredConcurrentEntryIdsChanged(
              Set<String>.from(preferredConcurrentEntryIds)..remove(entry.id),
            );
          }
        case 'allowPair':
          final next = Set<String>.from(excludedConcurrentEntryIds)
            ..remove(entry.id);
          onExcludedConcurrentEntryIdsChanged?.call(next);
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
      message: entry.type != 'calendar' && !entry.isLocked
          ? '${_eventTooltipMessage(entry, categoryLabel, timeText, entry.subtitle, entry.labels)}\nDrag to reschedule'
          : _eventTooltipMessage(
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
              isCompleted || isDismissed
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
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

  Future<void> _showChooseActivitiesDialog(
    BuildContext context,
    List<String> availableOptions,
  ) async {
    final selected = Set<String>.from(enabledActivityNames);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Choose available activities'),
              content: availableOptions.isEmpty
                  ? const Text(
                      'No activities configured yet — add some in Settings '
                      '> Movement activities.',
                    )
                  : SizedBox(
                      width: 320,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in availableOptions)
                            CheckboxListTile(
                              value: selected.contains(option),
                              title: Text(option),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selected.add(option);
                                  } else {
                                    selected.remove(option);
                                  }
                                });
                                onEnabledActivityNamesChanged?.call(selected);
                              },
                            ),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _showChangeActivityDialog(
    BuildContext context,
    DayPlannerEntry entry,
  ) async {
    final availableTasks = tasks.where((task) => task.done != true).toList();
    final options = <_ChangeActivityOption>[
      _ChangeActivityOption.preset('Focus Time'),
      ...availableTasks.map(_ChangeActivityOption.task),
      ...personalBlockNameOptions.map(_ChangeActivityOption.preset),
    ];
    Task? selectedTask = entry.task;
    var typedTitle = entry.task == null ? entry.title : '';

    final result = await showDialog<({Task? task, String? title})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change "${entry.title}"'),
        content: SizedBox(
          width: 360,
          child: Autocomplete<_ChangeActivityOption>(
            initialValue: TextEditingValue(text: entry.title),
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              if (query.isEmpty) return options;
              return options.where(
                (option) => option.label.toLowerCase().contains(query),
              );
            },
            displayStringForOption: (option) => option.label,
            onSelected: (option) {
              selectedTask = option.task;
              typedTitle = option.task == null ? option.label : '';
            },
            fieldViewBuilder:
                (context, fieldController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: fieldController,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Activity',
                      hintText: 'Pick a task, choose a preset, or type a name',
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),
                    onChanged: (value) {
                      selectedTask = null;
                      typedTitle = value;
                    },
                  );
                },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmedTitle = typedTitle.trim();
              if (selectedTask == null && trimmedTitle.isEmpty) return;
              Navigator.of(dialogContext).pop((
                task: selectedTask,
                title: selectedTask == null ? trimmedTitle : null,
              ));
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (result == null) return;
    onChangePlannerEntryActivity?.call(
      entry.id,
      taskId: result.task?.id,
      customTitle: result.title,
    );
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
                    height: 56,
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
                          height: 46,
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
                                    final entry = positioned.entry;
                                    final effectiveCardHeight = cardHeight
                                        .clamp(1.0, timelineContentHeight);
                                    final card = _buildCompactTimelineEventCard(
                                      context,
                                      entry,
                                      height: effectiveCardHeight,
                                    );
                                    final isDraggable =
                                        entry.type != 'calendar' &&
                                        !entry.isLocked;
                                    final gridMinutes =
                                        timeGrid == TimeGrid.fifteenMinutes
                                        ? 15
                                        : 30;
                                    final entryStartMinutes = entry.start
                                        .difference(start)
                                        .inMinutes;
                                    final entryEndMinutes =
                                        entryStartMinutes +
                                        entry.end
                                            .difference(entry.start)
                                            .inMinutes;
                                    Widget content = card;
                                    if (isDraggable) {
                                      content = _DraggableTimelineEntry(
                                        width: eventLaneWidth,
                                        totalMinutes: totalMinutes,
                                        timelineContentHeight:
                                            timelineContentHeight,
                                        entryStartMinutes: entryStartMinutes,
                                        entryDurationMinutes:
                                            entryEndMinutes - entryStartMinutes,
                                        gridMinutes: gridMinutes,
                                        onCommit: (newStartMinutes) {
                                          onEditPlannerEntryTime(
                                            entry.id,
                                            newStartMinutes,
                                            newStartMinutes +
                                                (entryEndMinutes -
                                                    entryStartMinutes),
                                          );
                                        },
                                        child: card,
                                      );
                                    }
                                    if (isDraggable &&
                                        effectiveCardHeight >= 28) {
                                      content = Stack(
                                        children: [
                                          content,
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            height: 12,
                                            child: _TimelineResizeHandle(
                                              totalMinutes: totalMinutes,
                                              timelineContentHeight:
                                                  timelineContentHeight,
                                              gridMinutes: gridMinutes,
                                              movingMinutes: entryStartMinutes,
                                              minMinutes: 0,
                                              maxMinutes:
                                                  entryEndMinutes - gridMinutes,
                                              onCommit: (newStartMinutes) {
                                                onEditPlannerEntryTime(
                                                  entry.id,
                                                  newStartMinutes,
                                                  entryEndMinutes,
                                                );
                                              },
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            height: 12,
                                            child: _TimelineResizeHandle(
                                              totalMinutes: totalMinutes,
                                              timelineContentHeight:
                                                  timelineContentHeight,
                                              gridMinutes: gridMinutes,
                                              movingMinutes: entryEndMinutes,
                                              minMinutes:
                                                  entryStartMinutes +
                                                  gridMinutes,
                                              maxMinutes: totalMinutes,
                                              onCommit: (newEndMinutes) {
                                                onEditPlannerEntryTime(
                                                  entry.id,
                                                  entryStartMinutes,
                                                  newEndMinutes,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Positioned(
                                      top: top,
                                      left:
                                          timeAxisWidth +
                                          positioned.lane *
                                              (eventLaneWidth + laneGap),
                                      width: eventLaneWidth,
                                      height: effectiveCardHeight,
                                      child: content,
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
              removedCalendarEventIds.contains(event.id) ||
              removedCalendarEventKeys.contains(
                StorageService.calendarEventIdentityKey(
                  isAllDay: event.isAllDay,
                  title: event.subject,
                  start: event.start,
                  end: event.end,
                ),
              )) {
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

        final freshPlannerResult = DayPlannerService.buildPlan(
          tasks: filteredTasks,
          calendarEvents: filteredCalendarEvents,
          day: selectedPlannerDate,
          dayContext: dayContext,
          isHoliday: isHoliday,
          weeklyTotals: weeklyActivityTotals,
          gymCompletedToday: gymCompletedToday,
          daysSinceLastMobility: daysSinceLastMobility,
          preferredConcurrentEntryIds: preferredConcurrentEntryIds,
          excludedConcurrentEntryIds: excludedConcurrentEntryIds,
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
          enabledActivityNames: enabledActivityNames,
        );

        // Once a plan exists for a day it stays frozen in place (no
        // reshuffling from unrelated app activity); it only regenerates when
        // the caller explicitly requests a replan (ignoreFrozenPlan).
        final useFrozenPlan =
            !ignoreFrozenPlan && hasFrozenPlanForDate(selectedPlannerDate);
        final DayPlannerResult plannerResult;
        if (useFrozenPlan) {
          final dayBoundsStart = DateTime(
            selectedPlannerDate.year,
            selectedPlannerDate.month,
            selectedPlannerDate.day,
          ).add(Duration(minutes: workdayStartMinutes));
          final dayBoundsEnd = DateTime(
            selectedPlannerDate.year,
            selectedPlannerDate.month,
            selectedPlannerDate.day,
          ).add(Duration(minutes: workdayEndMinutes));
          var frozenEntries = frozenEntriesForDate(selectedPlannerDate);
          if (plannerEntryOverrides.isNotEmpty) {
            frozenEntries = DayPlannerService.applyEntryOverrides(
              frozenEntries,
              plannerEntryOverrides,
              dayBoundsStart,
              dayBoundsEnd,
              resolveTask: (id) {
                for (final candidate in tasks) {
                  if (candidate.id == id) return candidate;
                }
                return null;
              },
            );
          }
          frozenEntries = frozenEntries
              .where((entry) => !removedPlannerEntryIds.contains(entry.id))
              .map(
                (entry) => entry.copyWith(
                  executionState:
                      executionStates[entry.id] ?? ExecutionState.pending,
                ),
              )
              .toList();
          plannerResult = DayPlannerResult(
            entries: frozenEntries,
            summary: frozenSummaryForDate(selectedPlannerDate),
            recommendations: freshPlannerResult.recommendations,
            rolloverTasks: freshPlannerResult.rolloverTasks,
          );
        } else {
          plannerResult = freshPlannerResult;
          if (onPlanBuilt != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onPlanBuilt?.call(selectedPlannerDate, freshPlannerResult);
            });
          }
        }
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
              final headerAndFilters = [
                // No fixed height/clip here — the summary text length
                // varies, so let the header size to its actual content.
                ..._buildPlannerHeaderContent(
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
                const SizedBox(height: 10),
                _buildContextSection(
                  context,
                  dayContext,
                  width: double.infinity,
                ),
                const SizedBox(height: 8),
                _buildTimelineFilters(context),

                const SizedBox(height: 12),
              ];

              final timelineContent = visiblePlannerEntries.isEmpty
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
                    );

              if (isNarrow) {
                // The header/context/filters height isn't known up front on
                // mobile, so give the timeline a fixed height and let the
                // whole thing scroll instead of squeezing (and clipping)
                // the timeline into whatever space happens to be left.
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...headerAndFilters,
                      SizedBox(height: 460, child: timelineContent),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...headerAndFilters,
                  Expanded(child: timelineContent),
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

  Widget _buildTimelineFilters(BuildContext context) {
    final chips = [
      _buildPlannerToggleChip(
        label: 'Work calendar',
        selected: showWorkCalendarInPlanner,
        chipColor: const Color(0xFF124B8A),
        onChanged: onShowWorkCalendarInPlannerChanged ?? (_) {},
        width: 128,
      ),
      _buildPlannerToggleChip(
        label: 'Work tasks',
        selected: showWorkTasksInPlanner,
        chipColor: const Color(0xFF0D3B6E),
        onChanged: onShowWorkTasksInPlannerChanged ?? (_) {},
        width: 128,
      ),
      _buildPlannerToggleChip(
        label: 'Home calendar',
        selected: showHomeCalendarInPlanner,
        chipColor: const Color(0xFFD95F02),
        onChanged: onShowHomeCalendarInPlannerChanged ?? (_) {},
        width: 128,
      ),
      _buildPlannerToggleChip(
        label: 'Home tasks',
        selected: showHomeTasksInPlanner,
        chipColor: const Color(0xFFF28E2B),
        onChanged: onShowHomeTasksInPlannerChanged ?? (_) {},
        width: 128,
      ),
      _buildPlannerToggleChip(
        label: 'Movement',
        selected: showMovementInPlanner,
        chipColor: const Color(0xFF2E8B57),
        onChanged: onShowMovementInPlannerChanged,
        width: 128,
      ),
      _buildPlannerToggleChip(
        label: 'Personal',
        selected: showPersonalInPlanner,
        chipColor: const Color(0xFFB23A48),
        onChanged: onShowPersonalInPlannerChanged,
        width: 128,
      ),
      _buildPlannerToggleChip(
        label: 'Break',
        selected: showBreakInPlanner,
        chipColor: const Color(0xFF455A64),
        onChanged: onShowBreakInPlannerChanged,
        width: 128,
      ),
    ];

    // Chips wrap to fit the available width instead of scrolling
    // horizontally; collapsed by default on narrow/mobile, expanded on
    // wide/desktop/web.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !isNarrow,
          dense: true,
          visualDensity: VisualDensity.compact,
          minTileHeight: 32,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text(
            'Timeline filters',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          children: [Wrap(spacing: 4, runSpacing: 4, children: chips)],
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
        metric('Remaining', summary.remainingCount, Colors.blueGrey.shade700),
      ],
    );
  }

  Widget _buildContextSection(
    BuildContext context,
    DayContext dayContext, {
    double? width,
  }) {
    final dayContextColumn = Column(
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
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildPlannerToggleChip(
              label: dayContext.gymMorning ? 'Gym morning' : 'No Gym',
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
              label: dayContext.eveningAvailable
                  ? 'Evening Available'
                  : 'Evening Unavailable',
              selected: dayContext.eveningAvailable,
              chipColor: Colors.teal,
              onChanged: onEveningAvailableChanged,
            ),
            if (onHolidayChanged != null)
              _buildPlannerToggleChip(
                label: isHoliday ? 'Holiday' : 'Mark as Holiday',
                selected: isHoliday,
                chipColor: Colors.purple,
                onChanged: onHolidayChanged!,
              ),
            if (onEnabledActivityNamesChanged != null)
              ActionChip(
                avatar: const Icon(Icons.directions_walk, size: 16),
                label: const Text('Choose available activities'),
                onPressed: () => _showChooseActivitiesDialog(
                  context,
                  dayContext.workLocation == WorkLocation.home
                      ? wfhActivityOptions
                      : officeActivityOptions,
                ),
              ),
          ],
        ),
      ],
    );
    final workWindowColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work window',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
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
      ],
    );

    final contextContent = isNarrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dayContextColumn,
              const SizedBox(height: 10),
              workWindowColumn,
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                dayContextColumn,
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
                workWindowColumn,
              ],
            ),
          );

    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: !isNarrow,
            dense: true,
            visualDensity: VisualDensity.compact,
            minTileHeight: 32,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: const Icon(Icons.tune, size: 16),
            title: const Text(
              'Planner context',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            children: [contextContent],
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

  Widget _buildMenuTrigger(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
      ),
    );
  }

  List<Widget> _buildImportExportMenuButtons(BuildContext context) {
    final showImportMenu = onImportOutlook != null || onImportIcs != null;
    final showExportMenu = onExportDay != null || onExportAll != null;
    if (!showImportMenu && !showExportMenu) {
      return const [];
    }
    return [
      if (showImportMenu)
        PopupMenuButton<String>(
          enabled: !isBusy,
          tooltip: 'Import',
          child: _buildMenuTrigger(
            context,
            icon: Icons.calendar_month,
            label: 'Import',
          ),
          onSelected: (value) {
            if (value == 'outlook') {
              onImportOutlook?.call();
            } else if (value == 'ics') {
              onImportIcs?.call();
            }
          },
          itemBuilder: (context) => [
            if (onImportOutlook != null)
              const PopupMenuItem(
                value: 'outlook',
                child: Text('Import Outlook'),
              ),
            if (onImportIcs != null && showImportIcsOption)
              const PopupMenuItem(value: 'ics', child: Text('Import ICS')),
          ],
        ),
      if (showImportMenu && showExportMenu) const SizedBox(width: 6),
      if (showExportMenu)
        PopupMenuButton<String>(
          enabled: !isBusy,
          tooltip: 'Export',
          child: _buildMenuTrigger(
            context,
            icon: Icons.cloud_upload_outlined,
            label: 'Export',
          ),
          onSelected: (value) {
            if (value == 'day') {
              onExportDay?.call();
            } else if (value == 'all') {
              onExportAll?.call();
            }
          },
          itemBuilder: (context) => [
            if (onExportDay != null)
              const PopupMenuItem(value: 'day', child: Text('Export day')),
            if (onExportAll != null)
              const PopupMenuItem(value: 'all', child: Text('Export all')),
          ],
        ),
    ];
  }

  List<Widget> _buildPlannerActionButtons(
    BuildContext context,
    DateTime selectedPlannerDate,
  ) {
    return [
      if (onReplanFromNow != null || onReplanAll != null)
        PopupMenuButton<String>(
          enabled: !isBusy,
          tooltip: 'Replan',
          child: _buildMenuTrigger(
            context,
            icon: Icons.update,
            label: 'Replan',
          ),
          onSelected: (value) {
            if (value == 'day') {
              onReplanFromNow?.call();
            } else if (value == 'all') {
              onReplanAll?.call();
            }
          },
          itemBuilder: (context) => [
            if (onReplanFromNow != null)
              const PopupMenuItem(value: 'day', child: Text('Replan day')),
            if (onReplanAll != null)
              const PopupMenuItem(value: 'all', child: Text('Replan all')),
          ],
        ),
      if (onReplanFromNow != null || onReplanAll != null)
        const SizedBox(width: 6),
      OutlinedButton.icon(
        icon: const Icon(Icons.add_box_outlined, size: 18),
        label: const Text('Add block'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () =>
            _showAddPersonalBlockDialog(context, selectedPlannerDate),
      ),
      if (onResetDay != null && plannerDayOffset == 0) ...[
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset day'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
          ),
          onPressed: isBusy
              ? null
              : () => _confirmResetDay(context, selectedPlannerDate),
        ),
      ],
    ];
  }

  Future<void> _confirmResetDay(
    BuildContext context,
    DateTime selectedPlannerDate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset today\'s plan?'),
        content: const Text(
          'This undoes every manual change made to today\'s plan (edited '
          'times, locks, deletions, added blocks, completion state) and '
          're-imports calendars so the day can be replanned from scratch. '
          'This can be undone from the Undo button afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset day'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onResetDay?.call();
    }
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
      if (showHeaderTitle) ...[
        Row(
          children: [
            const Icon(Icons.view_timeline_outlined, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Daily Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            ..._buildPlannerActionButtons(context, selectedPlannerDate),
            const SizedBox(width: 6),
            ..._buildImportExportMenuButtons(context),
          ],
        ),
        const SizedBox(height: 12),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          const dateStyle = TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w800,
          );
          // Size the date box exactly to its text instead of a fixed
          // percentage, so the Today/replan/add buttons keep their space.
          final datePainter = TextPainter(
            text: TextSpan(
              text: formatPlannerDate(context, selectedPlannerDate),
              style: dateStyle,
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
          final dateWidth = datePainter.width + 8;
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
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dateStyle,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Next day',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: effectivePlannerDayOffset < maxPlannerOffset
                      ? () => onPlannerDayOffsetChanged(
                          effectivePlannerDayOffset + 1,
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: effectivePlannerDayOffset > 0
                      ? () => onPlannerDayOffsetChanged(0)
                      : null,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('Today'),
                ),
                const Spacer(),
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

// A selectable option in the "Change activity" dialog: either an existing
// task from the task list, or a free-typed/preset custom activity name.
class _ChangeActivityOption {
  _ChangeActivityOption.task(this.task) : presetName = null;
  _ChangeActivityOption.preset(String name) : presetName = name, task = null;

  final Task? task;
  final String? presetName;

  String get label => task?.task ?? presetName ?? '';
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

// Immediate (not long-press) drag to reschedule a timeline entry vertically.
// `Draggable` uses an eager multi-drag recognizer that claims the gesture on
// the very first pointer movement, so it reliably wins the gesture arena
// against the timeline's own vertical ScrollView without needing a delay —
// a plain GestureDetector.onVerticalDrag* here would race the ScrollView and
// feel sluggish/inconsistent (which is why long-press was tried first).
class _DraggableTimelineEntry extends StatefulWidget {
  const _DraggableTimelineEntry({
    required this.child,
    required this.width,
    required this.totalMinutes,
    required this.timelineContentHeight,
    required this.entryStartMinutes,
    required this.entryDurationMinutes,
    required this.gridMinutes,
    required this.onCommit,
  });

  final Widget child;
  final double width;
  final int totalMinutes;
  final double timelineContentHeight;
  final int entryStartMinutes;
  final int entryDurationMinutes;
  final int gridMinutes;
  final ValueChanged<int> onCommit;

  @override
  State<_DraggableTimelineEntry> createState() =>
      _DraggableTimelineEntryState();
}

class _DraggableTimelineEntryState extends State<_DraggableTimelineEntry> {
  double _accumulatedDy = 0;

  void _commit() {
    final minutesPerPixel = widget.totalMinutes / widget.timelineContentHeight;
    final deltaMinutes =
        ((_accumulatedDy * minutesPerPixel) / widget.gridMinutes).round() *
        widget.gridMinutes;
    final maxStart = widget.totalMinutes - widget.entryDurationMinutes;
    final newStart = (widget.entryStartMinutes + deltaMinutes).clamp(
      0,
      maxStart < 0 ? 0 : maxStart,
    );
    _accumulatedDy = 0;
    if (newStart != widget.entryStartMinutes) {
      widget.onCommit(newStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<Object>(
      axis: Axis.vertical,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: widget.width,
          child: Opacity(opacity: 0.85, child: widget.child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
      onDragStarted: () {
        HapticFeedback.selectionClick();
        _accumulatedDy = 0;
      },
      onDragUpdate: (details) => _accumulatedDy += details.delta.dy,
      onDragEnd: (_) => _commit(),
      child: widget.child,
    );
  }
}

// Grab handle at a card's top/bottom edge to resize its start/end time.
// Same immediate-drag rationale as `_DraggableTimelineEntry` above.
class _TimelineResizeHandle extends StatefulWidget {
  const _TimelineResizeHandle({
    required this.totalMinutes,
    required this.timelineContentHeight,
    required this.gridMinutes,
    required this.movingMinutes,
    required this.minMinutes,
    required this.maxMinutes,
    required this.onCommit,
  });

  final int totalMinutes;
  final double timelineContentHeight;
  final int gridMinutes;
  final int movingMinutes;
  final int minMinutes;
  final int maxMinutes;
  final ValueChanged<int> onCommit;

  @override
  State<_TimelineResizeHandle> createState() => _TimelineResizeHandleState();
}

class _TimelineResizeHandleState extends State<_TimelineResizeHandle> {
  double _accumulatedDy = 0;
  bool _dragging = false;

  void _commit() {
    final minutesPerPixel = widget.totalMinutes / widget.timelineContentHeight;
    final rawDelta = _accumulatedDy * minutesPerPixel;
    final snappedDelta =
        (rawDelta / widget.gridMinutes).round() * widget.gridMinutes;
    final clampedMax = widget.maxMinutes < widget.minMinutes
        ? widget.minMinutes
        : widget.maxMinutes;
    final newMinutes = (widget.movingMinutes + snappedDelta).clamp(
      widget.minMinutes,
      clampedMax,
    );
    _accumulatedDy = 0;
    setState(() => _dragging = false);
    if (newMinutes != widget.movingMinutes) {
      widget.onCommit(newMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handleBar = Container(
      width: 28,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade600.withAlpha(_dragging ? 255 : 150),
        borderRadius: BorderRadius.circular(999),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: Draggable<Object>(
        axis: Axis.vertical,
        feedback: Material(color: Colors.transparent, child: handleBar),
        childWhenDragging: const SizedBox.shrink(),
        onDragStarted: () {
          HapticFeedback.selectionClick();
          _accumulatedDy = 0;
          setState(() => _dragging = true);
        },
        onDragUpdate: (details) => _accumulatedDy += details.delta.dy,
        onDragEnd: (_) => _commit(),
        child: Align(alignment: Alignment.center, child: handleBar),
      ),
    );
  }
}
