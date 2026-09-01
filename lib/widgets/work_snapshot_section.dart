import 'package:flutter/material.dart';

// A work task's due date or a work meeting's date, plotted on the 3-month
// timeline.
class WorkTimelineItem {
  const WorkTimelineItem({
    required this.title,
    required this.date,
    required this.isMeeting,
  });

  final String title;
  final DateTime date;
  final bool isMeeting;
}

// A work task with time planned on it somewhere in the viewed work week.
class WorkWeekTaskSummary {
  const WorkWeekTaskSummary({
    required this.title,
    required this.plannedTime,
    required this.workDays,
  });

  final String title;
  final Duration plannedTime;
  final List<DateTime> workDays;
}

// A work calendar meeting scheduled in the viewed work week.
class WorkWeekMeeting {
  const WorkWeekMeeting({
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
}

// Read-only snapshot of work commitments — a summary of a work week's
// meetings + planned tasks (navigable up to the planner's look-ahead
// limit), and a physical timeline of task due dates/meetings over the next
// 3 months, laid out week-by-week in parallel columns under each month —
// handy to share/screenshot during manager check-ins.
class WorkSnapshotSection extends StatelessWidget {
  const WorkSnapshotSection({
    super.key,
    required this.weekLabel,
    required this.canGoToPreviousWeek,
    required this.canGoToNextWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.weeklyTaskSummaries,
    required this.weeklyMeetings,
    required this.timelineItems,
  });

  final String weekLabel;
  final bool canGoToPreviousWeek;
  final bool canGoToNextWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final List<WorkWeekTaskSummary> weeklyTaskSummaries;
  final List<WorkWeekMeeting> weeklyMeetings;
  final List<WorkTimelineItem> timelineItems;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'am' : 'pm';
    return '$hour:$minute$suffix';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inMinutes ~/ 60;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }

  Widget _subsectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String subtitle,
    required String trailing,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(fontWeight: FontWeight.w800, color: accentColor),
          ),
        ],
      ),
    );
  }

  Widget _compactRow({
    required String title,
    required String trailing,
    required Color accentColor,
    bool italic = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accentColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(DateTime day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildMeetingsByDay() {
    final dayGroups = <DateTime, List<WorkWeekMeeting>>{};
    for (final meeting in weeklyMeetings) {
      final day = DateTime(
        meeting.start.year,
        meeting.start.month,
        meeting.start.day,
      );
      (dayGroups[day] ??= []).add(meeting);
    }
    final sortedDays = dayGroups.keys.toList()..sort();

    final children = <Widget>[];
    for (var i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final meetings = dayGroups[day]!
        ..sort((a, b) => a.start.compareTo(b.start));
      if (i > 0) {
        children.add(const Divider(height: 20));
      }
      children.add(_dayHeader(day));
      for (final meeting in meetings) {
        children.add(
          _compactRow(
            title: meeting.title,
            trailing:
                '${_formatTime(meeting.start)} - ${_formatTime(meeting.end)}',
            accentColor: Colors.indigo.shade700,
          ),
        );
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildMeetingsColumn() {
    if (weeklyMeetings.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subsectionHeader('Meetings'),
          Text(
            'No work meetings for this work week.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_subsectionHeader('Meetings'), _buildMeetingsByDay()],
    );
  }

  Widget _buildTasksColumn() {
    if (weeklyTaskSummaries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subsectionHeader('Tasks in progress'),
          Text(
            'No work tasks planned for this work week.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subsectionHeader('Tasks in progress'),
        for (final summary in weeklyTaskSummaries)
          _infoCard(
            title: summary.title,
            subtitle: summary.workDays
                .map((day) => _weekdays[day.weekday - 1])
                .toSet()
                .join(', '),
            trailing: _formatDuration(summary.plannedTime),
            accentColor: Colors.teal.shade700,
          ),
      ],
    );
  }

  Widget _buildWeekSummary() {
    if (weeklyMeetings.isEmpty && weeklyTaskSummaries.isEmpty) {
      return Text(
        'No work meetings or planned work tasks for this work week yet.',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tasks in progress on the left, Meetings on the right — side by
        // side when there's room, stacked (tasks first) on narrow screens.
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTasksColumn()),
              const SizedBox(width: 16),
              Expanded(child: _buildMeetingsColumn()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTasksColumn(),
            const SizedBox(height: 16),
            _buildMeetingsColumn(),
          ],
        );
      },
    );
  }

  Widget _buildWeekColumn(DateTime weekStart, List<WorkTimelineItem> items) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label =
        '${weekStart.day} ${_months[weekStart.month - 1]} - '
        '${weekEnd.day} ${_months[weekEnd.month - 1]}';

    final dayGroups = <DateTime, List<WorkTimelineItem>>{};
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      (dayGroups[day] ??= []).add(item);
    }
    final sortedDays = dayGroups.keys.toList()..sort();

    final dayWidgets = <Widget>[];
    for (var i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final dayItems = dayGroups[day]!
        ..sort((a, b) => a.date.compareTo(b.date));
      if (i > 0) {
        dayWidgets.add(const Divider(height: 16));
      }
      dayWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${day.day} ${_months[day.month - 1]}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final item in dayItems) {
        dayWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5, right: 6),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.isMeeting
                        ? Colors.indigo.shade400
                        : Colors.teal.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: item.isMeeting
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const Divider(height: 14),
          ...dayWidgets,
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (timelineItems.isEmpty) {
      return Text(
        'No work tasks or meetings due in the next 3 months.',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }
    final monthGroups = <String, List<WorkTimelineItem>>{};
    for (final item in timelineItems) {
      final key = '${_months[item.date.month - 1]} ${item.date.year}';
      (monthGroups[key] ??= []).add(item);
    }
    final sections = <Widget>[];
    for (final monthGroup in monthGroups.entries) {
      final weekGroups = <DateTime, List<WorkTimelineItem>>{};
      for (final item in monthGroup.value) {
        final itemDay = DateTime(
          item.date.year,
          item.date.month,
          item.date.day,
        );
        final weekStart = itemDay.subtract(Duration(days: itemDay.weekday - 1));
        (weekGroups[weekStart] ??= []).add(item);
      }
      final sortedWeekStarts = weekGroups.keys.toList()..sort();
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            monthGroup.key,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      );
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: sortedWeekStarts.map((weekStart) {
              final items = weekGroups[weekStart]!
                ..sort((a, b) => a.date.compareTo(b.date));
              return _buildWeekColumn(weekStart, items);
            }).toList(),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Work Snapshot',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'A quick view of your work commitments — handy to share in a '
            'manager check-in.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              _sectionHeader(weekLabel),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous week',
                onPressed: canGoToPreviousWeek ? onPreviousWeek : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week',
                onPressed: canGoToNextWeek ? onNextWeek : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildWeekSummary(),
          const SizedBox(height: 24),
          _sectionHeader('Tasks and meetings due dates'),
          const SizedBox(height: 8),
          _buildTimeline(),
        ],
      ),
    );
  }
}
