import 'package:flutter/material.dart';

import '../models/task.dart';

class TasksOverviewSection extends StatelessWidget {
  const TasksOverviewSection({
    super.key,
    required this.isNarrow,
    required this.priorityCardsTotalWidth,
    required this.priorityCardCount,
    required this.priorityCardSpacing,
    required this.getTopTasks,
    required this.buildPriorityCard,
    required this.prioritizeWorkOnWeekdays,
    required this.isWeekday,
    required this.onToggleWorkdayPriorityMode,
    required this.buildCaptureInboxSection,
    required this.buildOutlookSection,
    required this.buildDailyCheckinSection,
  });

  final bool isNarrow;
  final double priorityCardsTotalWidth;
  final int priorityCardCount;
  final double priorityCardSpacing;
  final List<Task> Function(int count) getTopTasks;
  final Widget Function(int position, Task? task) buildPriorityCard;
  final bool prioritizeWorkOnWeekdays;
  final bool isWeekday;
  final VoidCallback onToggleWorkdayPriorityMode;
  final Widget buildCaptureInboxSection;
  final Widget buildOutlookSection;
  final Widget buildDailyCheckinSection;

  @override
  Widget build(BuildContext context) {
    final topTasks = getTopTasks(priorityCardCount);
    final cards = List.generate(priorityCardCount, (position) {
      final task = position < topTasks.length ? topTasks[position] : null;
      final child = buildPriorityCard(position, task);

      return Padding(
        padding: EdgeInsets.only(
          right: position == priorityCardCount - 1 ? 0 : priorityCardSpacing,
        ),
        child: child,
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: priorityCardsTotalWidth,
            child: buildCaptureInboxSection,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: priorityCardsTotalWidth,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onToggleWorkdayPriorityMode,
                  icon: Icon(
                    prioritizeWorkOnWeekdays
                        ? Icons.work_history
                        : Icons.format_list_bulleted,
                    size: 18,
                  ),
                  label: Text(
                    prioritizeWorkOnWeekdays
                        ? 'Workday priority'
                        : 'All-task priority',
                  ),
                ),
                Text(
                  isWeekday
                      ? 'Weekday: Work tasks are boosted when enabled'
                      : 'Weekend: showing all tasks regardless',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: priorityCardsTotalWidth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isNarrow
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: cards,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cards,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: priorityCardsTotalWidth,
            child: buildOutlookSection,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: priorityCardsTotalWidth,
            child: buildDailyCheckinSection,
          ),
        ),
      ],
    );
  }
}
