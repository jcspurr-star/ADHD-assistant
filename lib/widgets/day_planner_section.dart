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

class DayPlannerSection extends StatelessWidget {
  const DayPlannerSection({
    super.key,
    required this.upcomingOutlookEventsFuture,
    required this.loadUpcomingOutlookEvents,
    required this.outlookLookAheadDays,
    required this.plannerDayOffset,
    required this.showWorkInPlanner,
    required this.showHomeInPlanner,
    required this.showMovementInPlanner,
    required this.showBreakInPlanner,
    required this.showFocusInPlanner,
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
    required this.removedPlannerEntryIds,
    required this.removedCalendarEventIds,
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
    required this.onShowWorkInPlannerChanged,
    required this.onShowHomeInPlannerChanged,
    required this.onShowMovementInPlannerChanged,
    required this.onShowBreakInPlannerChanged,
    required this.onShowFocusInPlannerChanged,
    required this.onShowPersonalInPlannerChanged,
    required this.onGymAvailableChanged,
    required this.onWfhAvailableChanged,
    required this.onEveningAvailableChanged,
    required this.onCompleteRecommendation,
    required this.onViewActivityHistory,
    required this.onPreferredConcurrentEntryIdsChanged,
    required this.onToggleCalendarPlanning,
    required this.onLogHomeEventAsGym,
    required this.onRemovePlannerEntry,
    required this.onWorkdayHoursChanged,
    required this.onEditPlannerEntryTime,
    required this.onTogglePlannerEntryLock,
    required this.onAddPersonalBlock,
    required this.onImportCalendar,
    required this.onResetPlanner,
    required this.onExecutePlannerEntry,
    required this.onOpenTask,
    this.dashboardMode = false,
    this.onOpenPlanner,
    this.timeGrid = TimeGrid.fifteenMinutes,
    this.onTimeGridChanged,
  });

  final Future<List<OutlookCalendarEvent>>? upcomingOutlookEventsFuture;
  final Future<List<OutlookCalendarEvent>> Function() loadUpcomingOutlookEvents;
  final int outlookLookAheadDays;
  final int plannerDayOffset;
  final bool showWorkInPlanner;
  final bool showHomeInPlanner;
  final bool showMovementInPlanner;
  final bool showBreakInPlanner;
  final bool showFocusInPlanner;
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
  final Set<String> removedPlannerEntryIds;
  final Set<String> removedCalendarEventIds;
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
  final ValueChanged<bool> onShowWorkInPlannerChanged;
  final ValueChanged<bool> onShowHomeInPlannerChanged;
  final ValueChanged<bool> onShowMovementInPlannerChanged;
  final ValueChanged<bool> onShowBreakInPlannerChanged;
  final ValueChanged<bool> onShowFocusInPlannerChanged;
  final ValueChanged<bool> onShowPersonalInPlannerChanged;
  final ValueChanged<bool> onGymAvailableChanged;
  final ValueChanged<bool> onWfhAvailableChanged;
  final ValueChanged<bool> onEveningAvailableChanged;
  final ValueChanged<ActivityRecommendation> onCompleteRecommendation;
  final VoidCallback onViewActivityHistory;
  final ValueChanged<Set<String>> onPreferredConcurrentEntryIdsChanged;
  final ValueChanged<Set<String>> onToggleCalendarPlanning;
  final ValueChanged<DayPlannerEntry> onLogHomeEventAsGym;
  final ValueChanged<String> onRemovePlannerEntry;
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
  final VoidCallback onImportCalendar;
  final VoidCallback onResetPlanner;
  final void Function(DayPlannerEntry entry, ExecutionState state)
  onExecutePlannerEntry;
  final ValueChanged<Task> onOpenTask;
  final bool dashboardMode;
  final VoidCallback? onOpenPlanner;
  final TimeGrid timeGrid;
  final ValueChanged<TimeGrid>? onTimeGridChanged;

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

  String _eventCategoryLabel(DayPlannerEntry entry) {
    if (entry.type == 'personal') return 'Personal';
    if (entry.type == 'movement') return 'Movement';
    if (entry.type == 'break') return 'Break';
    if (entry.type == 'buffer') return 'Focus';
    if (entry.type == 'task') {
      return entry.task != null && isWorkTask(entry.task!) ? 'Work' : 'Home';
    }
    if (entry.type == 'calendar') {
      return entry.subtitle?.toLowerCase().contains('work') == true
          ? 'Work'
          : 'Home';
    }
    return entry.type;
  }

  String _eventTooltipMessage(
    DayPlannerEntry entry,
    String categoryLabel,
    String timeLabel,
    String? subtitle,
  ) {
    final details = <String>[
      entry.title,
      'Category: $categoryLabel',
      'Time: $timeLabel',
    ];
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      details.add(subtitle.trim());
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
    final workColor = const Color(0xFF008E7A);
    final homeColor = const Color(0xFF124B8A);
    final plannerColor = const Color(0xFF7C4DFF);
    final breakColor = const Color(0xFF8A6D1D);
    final focusColor = const Color(0xFF6B4E9B);
    final movementColor = const Color(0xFFB05A00);
    final personalColor = const Color(0xFFB23A48);
    final isMovement = entry.type == 'movement';
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
        ? focusColor
        : isMovement
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
      message: _eventTooltipMessage(entry, categoryLabel, timeLabel, subtitle),
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
                        if (!isCompact && !isNarrowLane)
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
                                                value: 'remove',
                                                child: Text(
                                                  'Remove from this plan',
                                                ),
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
                                            onRemovePlannerEntry(entry.id);
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
    final isCompleted = entry.executionState == ExecutionState.completed;
    final isSkipped = entry.executionState == ExecutionState.skipped;
    final isDismissed = entry.executionState == ExecutionState.dismissed;
    final color = entry.type == 'personal'
        ? const Color(0xFFB23A48)
        : entry.type == 'break'
        ? const Color(0xFF8A6D1D)
        : entry.type == 'buffer'
        ? const Color(0xFF6B4E9B)
        : entry.type == 'movement'
        ? const Color(0xFFB05A00)
        : entry.type == 'task'
        ? (entry.task != null && isWorkTask(entry.task!)
              ? const Color(0xFF008E7A)
              : const Color(0xFF124B8A))
        : isCalendar
        ? isHomeCalendar
              ? const Color(0xFF124B8A)
              : const Color(0xFF008E7A)
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
        actions.addAll(['complete', 'skip', 'defer', 'dismiss']);
        actions.add('edit');
        actions.add('lock');
      } else if (!isAllDay) {
        actions.addAll(['pair', 'remove']);
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
            const PopupMenuItem(
              value: 'complete',
              child: Text('Mark complete'),
            ),
            const PopupMenuItem(value: 'skip', child: Text('Skip')),
            const PopupMenuItem(value: 'defer', child: Text('Defer')),
            const PopupMenuItem(value: 'dismiss', child: Text('Dismiss')),
            const PopupMenuItem(value: 'edit', child: Text('Edit time')),
            PopupMenuItem(
              value: 'lock',
              child: Text(entry.isLocked ? 'Unlock time' : 'Lock time'),
            ),
          ] else if (!isAllDay) ...[
            if (isHomeCalendar)
              PopupMenuItem(
                value: 'planning',
                child: Text(
                  nonBlockingCalendarEventIds.contains(entry.id)
                      ? 'Include in planning'
                      : 'Exclude from planning',
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
              value: 'remove',
              child: Text('Remove from this plan'),
            ),
          ],
        ],
      );
      if (!context.mounted || selected == null) return;
      switch (selected) {
        case 'complete':
          onExecutePlannerEntry(entry, ExecutionState.completed);
        case 'skip':
          onExecutePlannerEntry(entry, ExecutionState.skipped);
        case 'defer':
          onExecutePlannerEntry(entry, ExecutionState.deferred);
        case 'dismiss':
          onExecutePlannerEntry(entry, ExecutionState.dismissed);
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
          if (!next.add(entry.id)) next.remove(entry.id);
          onToggleCalendarPlanning(next);
        case 'gym':
          onLogHomeEventAsGym(entry);
        case 'remove':
          onRemovePlannerEntry(entry.id);
      }
    }

    return Tooltip(
      message: _eventTooltipMessage(
        entry,
        categoryLabel,
        timeText,
        entry.subtitle,
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
              isCompleted || isSkipped || isDismissed ? 28 : 70,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(190)),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: entry.isZeroDuration ? 16 : 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
              if (height >= 36)
                Padding(
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
              if (!isAllDay)
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: 'Event actions',
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

    final positionedEntries = <({DayPlannerEntry entry, int lane})>[];
    final laneEnds = <DateTime>[];
    final sortedEntries = entries.where((entry) => !entry.isAllDay).toList()
      ..sort((a, b) {
        final startCompare = a.start.compareTo(b.start);
        if (startCompare != 0) return startCompare;
        final aPersonal = a.type == 'personal';
        final bPersonal = b.type == 'personal';
        if (aPersonal != bPersonal) return aPersonal ? -1 : 1;
        final aLunch = a.type == 'break' && a.id.startsWith('break-lunch-');
        final bLunch = b.type == 'break' && b.id.startsWith('break-lunch-');
        if (aLunch != bLunch) return aLunch ? -1 : 1;
        return b.end.compareTo(a.end);
      });
    final personalEntries = sortedEntries
        .where((entry) => entry.type == 'personal')
        .toList();
    for (final entry in sortedEntries) {
      final visualDuration = entry.end
          .difference(entry.start)
          .inMinutes
          .clamp(12, totalMinutes);
      final laneEnd = entry.start.add(Duration(minutes: visualDuration));
      var lane = 0;
      final isExcludedHomeEvent =
          entry.type == 'calendar' &&
          entry.category == PlannerEventCategory.informational;
      final hasOverlappingEvent = sortedEntries.any(
        (other) =>
            !identical(other, entry) &&
            other.type != 'personal' &&
            entry.start.isBefore(other.end) &&
            entry.end.isAfter(other.start),
      );
      if (isExcludedHomeEvent && hasOverlappingEvent) {
        lane = 1;
        if (laneEnds.isEmpty) laneEnds.add(entry.start);
      }
      if (entry.type != 'personal' &&
          personalEntries.any(
            (personal) =>
                entry.start.isBefore(personal.end) &&
                entry.end.isAfter(personal.start),
          )) {
        lane = 1;
      }
      while (lane < laneEnds.length && entry.start.isBefore(laneEnds[lane])) {
        lane++;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(laneEnd);
      } else {
        laneEnds[lane] = laneEnd;
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
                                    return Positioned(
                                      top: top,
                                      left:
                                          timeAxisWidth +
                                          positioned.lane *
                                              (laneWidth + laneGap),
                                      width: laneWidth,
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
          if (removedPlannerEntryIds.contains('calendar-${event.id}') ||
              removedCalendarEventIds.contains(event.id)) {
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
          workdayStartMinutes: workdayStartMinutes,
          workdayEndMinutes: workdayEndMinutes,
          entryOverrides: plannerEntryOverrides,
          personalBlocks: personalBlocks,
          executionStates: executionStates,
          timeGrid: timeGrid,
        );
        final visiblePlannerEntries = plannerResult.entries.where((entry) {
          if (entry.executionState == ExecutionState.dismissed) {
            return false;
          }
          if (entry.type == 'personal' && !showPersonalInPlanner) {
            return false;
          }
          if (entry.type == 'movement' && !showMovementInPlanner) {
            return false;
          }
          if (entry.type == 'break' && !showBreakInPlanner) {
            return false;
          }
          if (entry.type == 'buffer' && !showFocusInPlanner) {
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
                  ? (availableHeight - 150)
                        .clamp(0.0, double.infinity)
                        .toDouble()
                  : (availableHeight - 52)
                        .clamp(0.0, double.infinity)
                        .toDouble();
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
                  _buildTimelineFilters(),
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

  Widget _buildTimelineFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
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
            chipColor: const Color(0xFF124B8A),
            onChanged: onShowHomeInPlannerChanged,
          ),
          _buildPlannerToggleChip(
            label: 'Movement',
            selected: showMovementInPlanner,
            chipColor: const Color(0xFFB05A00),
            onChanged: onShowMovementInPlannerChanged,
          ),
          _buildPlannerToggleChip(
            label: 'Personal',
            selected: showPersonalInPlanner,
            chipColor: const Color(0xFFB23A48),
            onChanged: onShowPersonalInPlannerChanged,
          ),
          _buildPlannerToggleChip(
            label: 'Break',
            selected: showBreakInPlanner,
            chipColor: const Color(0xFF8A6D1D),
            onChanged: onShowBreakInPlannerChanged,
          ),
          _buildPlannerToggleChip(
            label: 'Focus',
            selected: showFocusInPlanner,
            chipColor: const Color(0xFF6B4E9B),
            onChanged: onShowFocusInPlannerChanged,
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
              if (onTimeGridChanged != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Time grid',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('15 min'),
                      selected: timeGrid == TimeGrid.fifteenMinutes,
                      onSelected: (_) =>
                          onTimeGridChanged!(TimeGrid.fifteenMinutes),
                    ),
                    ChoiceChip(
                      label: const Text('30 min'),
                      selected: timeGrid == TimeGrid.thirtyMinutes,
                      onSelected: (_) =>
                          onTimeGridChanged!(TimeGrid.thirtyMinutes),
                    ),
                  ],
                ),
              ],
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
                  tooltip: 'Import work calendar',
                  icon: const Icon(Icons.upload_file_outlined),
                  onPressed: onImportCalendar,
                ),
                IconButton(
                  tooltip: 'Reset and replan this day',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onResetPlanner,
                ),
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
