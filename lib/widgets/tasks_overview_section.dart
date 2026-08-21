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
    required this.buildDayPlannerSection,
    required this.buildTimerSection,
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
  final Widget buildDayPlannerSection;
  final Widget buildTimerSection;

  @override
  Widget build(BuildContext context) {
    final showWebRightColumnLayout =
        !isNarrow && MediaQuery.of(context).size.width >= 1200;
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

    Widget buildPrioritySection({required bool useFullWidth}) {
      final highPriorityCount = topTasks
          .where((task) => task.priority == 'high')
          .length;
      final dueSoonCount = topTasks.where((task) {
        final dueDate = DateTime.tryParse(task.dueDate ?? '');
        if (dueDate == null) {
          return false;
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final daysUntil = dueDay.difference(today).inDays;
        return daysUntil >= 0 && daysUntil <= 2;
      }).length;

      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
          const SizedBox(height: 8),
          Container(
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cards,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: useFullWidth
                ? Row(
                    children: [
                      Icon(
                        Icons.insights,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${topTasks.length} showing  •  $highPriorityCount high  •  $dueSoonCount due soon',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Priority snapshot',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topTasks.length} showing  •  $highPriorityCount high  •  $dueSoonCount due soon',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tip: tap a card to open it in the full task list.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );

      if (useFullWidth) {
        return content;
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: priorityCardsTotalWidth, child: content),
      );
    }

    Widget buildPrimaryTilesColumn({required bool includePrioritySection}) {
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
          if (includePrioritySection) ...[
            const SizedBox(height: 8),
            buildPrioritySection(useFullWidth: false),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: priorityCardsTotalWidth,
              child: buildOutlookSection,
            ),
          ),
        ],
      );
    }

    Widget buildWebColumnShell({required Widget child}) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(170),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.withAlpha(70), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );
    }

    if (showWebRightColumnLayout) {
      const topRowHeight = 275.0;
      final bottomRowHeight = (MediaQuery.of(context).size.height * 0.64).clamp(
        430.0,
        680.0,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: topRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: buildWebColumnShell(
                    child: SizedBox.expand(child: buildCaptureInboxSection),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildWebColumnShell(
                    child: SizedBox.expand(
                      child: SingleChildScrollView(
                        primary: false,
                        child: buildPrioritySection(useFullWidth: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildWebColumnShell(
                    child: SizedBox.expand(child: buildTimerSection),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: bottomRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: buildWebColumnShell(
                    child: SizedBox.expand(child: buildOutlookSection),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildWebColumnShell(
                    child: SizedBox.expand(child: buildDayPlannerSection),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildWebColumnShell(
                    child: SizedBox.expand(child: buildDailyCheckinSection),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPrimaryTilesColumn(includePrioritySection: true),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: priorityCardsTotalWidth,
            child: buildDayPlannerSection,
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
