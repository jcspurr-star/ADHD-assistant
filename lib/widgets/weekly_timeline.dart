import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';
import '../services/day_planner_service.dart';
import '../services/one_drive_sync_service.dart';

typedef WeeklyEventCardBuilder =
    Widget Function(
      BuildContext context,
      DayPlannerEntry entry, {
      required double height,
    });

class WeeklyTimeline extends StatefulWidget {
  const WeeklyTimeline({
    super.key,
    required this.today,
    required this.selectedDate,
    required this.height,
    required this.startOffset,
    required this.maxStartOffset,
    required this.entriesByDay,
    required this.allDayEntriesByDay,
    required this.positionedByDay,
    required this.dayWidths,
    required this.weeklyDayContexts,
    required this.weeklyHolidayDates,
    required this.onWeeklyDayContextChanged,
    required this.onWeeklyTimelineStartOffsetChanged,
    required this.eventCardBuilder,
  });

  final DateTime today;
  final DateTime selectedDate;
  final double height;
  final int startOffset;
  final int maxStartOffset;
  final Map<DateTime, List<DayPlannerEntry>> entriesByDay;
  final Map<DateTime, List<DayPlannerEntry>> allDayEntriesByDay;
  final Map<
    DateTime,
    List<({DayPlannerEntry entry, int lane, int columnCount})>
  >
  positionedByDay;
  final Map<DateTime, double> dayWidths;
  final Map<DateTime, DayContext> weeklyDayContexts;
  final Set<DateTime> weeklyHolidayDates;
  final void Function(DateTime date, String setting, bool value)?
  onWeeklyDayContextChanged;
  final ValueChanged<int>? onWeeklyTimelineStartOffsetChanged;
  final WeeklyEventCardBuilder eventCardBuilder;

  @override
  State<WeeklyTimeline> createState() => _WeeklyTimelineState();
}

class _WeeklyTimelineState extends State<WeeklyTimeline> {
  static const allDayHeight = 44.0;
  static const contextHeight = 34.0;
  static const timeAxisWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final dayHeight = (widget.height - 34).clamp(120.0, 600.0);
    final timelineContentHeight = dayHeight * 4;
    final days = List<DateTime>.generate(
      5,
      (index) => widget.today.add(Duration(days: widget.startOffset + index)),
    );
    final weeklyContent = _buildWeeklyContent(
      context,
      days,
      timelineContentHeight,
    );

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              tooltip: 'Previous days',
              onPressed: widget.startOffset > 0
                  ? () => widget.onWeeklyTimelineStartOffsetChanged?.call(
                      (widget.startOffset - 1).clamp(0, 31),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Stack(
                children: [
                  _SharedVerticalScrollView(
                    child: SizedBox(
                      height:
                          28 +
                          allDayHeight +
                          contextHeight +
                          timelineContentHeight,
                      child: weeklyContent,
                    ),
                  ),
                  _buildStickyHeaders(days),
                  _buildInteractiveContextRow(days),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              tooltip: 'Next days',
              onPressed: widget.startOffset < widget.maxStartOffset
                  ? () => widget.onWeeklyTimelineStartOffsetChanged?.call(
                      (widget.startOffset + 1).clamp(0, 31),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyContent(
    BuildContext context,
    List<DateTime> days,
    double timelineHeight,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeAxis(timelineHeight),
        for (var index = 0; index < days.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          _buildDayColumn(context, days[index], timelineHeight),
        ],
      ],
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    DateTime date,
    double timelineHeight,
  ) {
    final dayWidth = widget.dayWidths[date] ?? 0;
    final entries = widget.entriesByDay[date] ?? const <DayPlannerEntry>[];
    final positioned =
        widget.positionedByDay[date] ??
        const <({DayPlannerEntry entry, int lane, int columnCount})>[];
    final columnCount = positioned.isEmpty
        ? 1
        : positioned
              .map((item) => item.columnCount)
              .reduce((a, b) => a > b ? a : b);
    final columnWidth = (dayWidth - 8 - ((columnCount - 1) * 4)) / columnCount;

    return SizedBox(
      width: dayWidth,
      child: Column(
        children: [
          _buildDayHeader(date, date == widget.selectedDate, dayWidth),
          _buildAllDayBlock(
            widget.allDayEntriesByDay[date] ?? const [],
            dayWidth,
          ),
          _buildContextRow(date, dayWidth),
          SizedBox(
            height: timelineHeight,
            child: Stack(
              children: [
                for (var hour = 0; hour <= 24; hour++)
                  Positioned(
                    top: (hour / 24) * timelineHeight,
                    left: 0,
                    right: 0,
                    child: Divider(height: 1, color: Colors.blueGrey.shade100),
                  ),
                for (final item in positioned)
                  Builder(
                    builder: (context) {
                      final entry = item.entry;
                      final startMinutes =
                          entry.start.hour * 60 + entry.start.minute;
                      final durationMinutes = entry.end
                          .difference(entry.start)
                          .inMinutes
                          .clamp(15, 1440);
                      final top = (startMinutes / 1440) * timelineHeight;
                      final cardHeight =
                          (durationMinutes / 1440) * timelineHeight;
                      final effectiveHeight = cardHeight.clamp(
                        20.0,
                        timelineHeight,
                      );
                      final overlapsCalendar = entries.any(
                        (other) =>
                            other.type == 'calendar' &&
                            entry.start.isBefore(other.end) &&
                            entry.end.isAfter(other.start),
                      );
                      final card = widget.eventCardBuilder(
                        context,
                        entry,
                        height: effectiveHeight,
                      );
                      return Positioned(
                        top: top,
                        left: 4 + item.lane * (columnWidth + 4),
                        width: columnWidth,
                        height: effectiveHeight,
                        child: entry.type != 'calendar' && overlapsCalendar
                            ? Opacity(opacity: 0.72, child: card)
                            : card,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAxis(double timelineHeight) {
    return SizedBox(
      width: timeAxisWidth,
      child: Column(
        children: [
          const SizedBox(height: 28 + allDayHeight + contextHeight),
          SizedBox(
            height: timelineHeight,
            child: Stack(
              children: [
                for (var hour = 0; hour <= 24; hour++)
                  Positioned(
                    top: (hour / 24) * timelineHeight,
                    left: 2,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeaders(List<DateTime> days) {
    return Positioned(
      top: 0,
      left: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            SizedBox(
              width: timeAxisWidth,
              height: 28 + allDayHeight + contextHeight,
            ),
            for (var index = 0; index < days.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              SizedBox(
                width: widget.dayWidths[days[index]] ?? 0,
                child: Column(
                  children: [
                    _buildDayHeader(
                      days[index],
                      days[index] == widget.selectedDate,
                      widget.dayWidths[days[index]] ?? 0,
                    ),
                    _buildAllDayBlock(
                      widget.allDayEntriesByDay[days[index]] ?? const [],
                      widget.dayWidths[days[index]] ?? 0,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveContextRow(List<DateTime> days) {
    return Positioned(
      top: 28 + allDayHeight,
      left: timeAxisWidth,
      child: Row(
        children: [
          for (var index = 0; index < days.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            _buildContextRow(days[index], widget.dayWidths[days[index]] ?? 0),
          ],
        ],
      ),
    );
  }

  Widget _buildDayHeader(DateTime date, bool selected, double width) {
    return Container(
      width: width,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.teal.shade700 : Colors.blueGrey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Text(
        '${_weekdayLabel(date.weekday)} ${date.day}',
        style: TextStyle(
          color: selected ? Colors.white : Colors.blueGrey.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildAllDayBlock(List<DayPlannerEntry> entries, double width) {
    return Container(
      width: width,
      height: allDayHeight,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: entries.isEmpty
          ? Text(
              'No all-day events',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Colors.blueGrey.shade400),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...entries
                    .take(2)
                    .map(
                      (entry) => Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ),
                if (entries.length > 2)
                  Text(
                    '+${entries.length - 2} more',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal.shade700,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildContextRow(DateTime date, double width) {
    final context = widget.weeklyDayContexts[date];
    if (context == null) return SizedBox(width: width, height: contextHeight);

    Widget iconButton({
      required IconData icon,
      required bool selected,
      required String tooltip,
      required String setting,
    }) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          iconSize: 16,
          onPressed: widget.onWeeklyDayContextChanged == null
              ? null
              : () =>
                    widget.onWeeklyDayContextChanged!(date, setting, !selected),
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? Colors.teal.shade600
                : Colors.blueGrey.shade100,
            foregroundColor: selected ? Colors.white : Colors.blueGrey.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          icon: Icon(icon),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: contextHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            iconButton(
              icon: Icons.fitness_center,
              selected: context.gymMorning,
              tooltip: context.gymMorning ? 'Gym available' : 'No gym',
              setting: 'gym',
            ),
            iconButton(
              icon: context.workLocation == WorkLocation.home
                  ? Icons.home
                  : Icons.business,
              selected: context.workLocation == WorkLocation.home,
              tooltip: context.workLocation == WorkLocation.home
                  ? 'WFH'
                  : 'Office',
              setting: 'wfh',
            ),
            iconButton(
              icon: Icons.nights_stay,
              selected: context.eveningAvailable,
              tooltip: context.eveningAvailable
                  ? 'Evening available'
                  : 'Evening unavailable',
              setting: 'evening',
            ),
            iconButton(
              icon: Icons.beach_access,
              selected: widget.weeklyHolidayDates.contains(date),
              tooltip: widget.weeklyHolidayDates.contains(date)
                  ? 'Holiday'
                  : 'Not a holiday',
              setting: 'holiday',
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }
}

class _SharedVerticalScrollView extends StatefulWidget {
  const _SharedVerticalScrollView({required this.child});

  final Widget child;

  @override
  State<_SharedVerticalScrollView> createState() =>
      _SharedVerticalScrollViewState();
}

class _SharedVerticalScrollViewState extends State<_SharedVerticalScrollView> {
  final ScrollController _controller = ScrollController();

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
