import 'package:flutter/material.dart';

import '../models/task.dart';
import 'task_list_view.dart';
import 'tasks_overview_section.dart';

class TasksViewSection extends StatelessWidget {
  const TasksViewSection({
    super.key,
    required this.showOverview,
    required this.showTaskList,
    required this.isNarrow,
    required this.priorityCardsTotalWidth,
    required this.priorityCardSpacing,
    required this.isGenerating,
    required this.prioritizeWorkOnWeekdays,
    required this.isWeekday,
    required this.taskTabsScrollController,
    required this.taskTabs,
    required this.taskSortLabel,
    required this.groupTasksByPriority,
    required this.onGroupByPriorityChanged,
    required this.onSelectTaskSortMode,
    required this.getTopTasks,
    required this.buildPriorityCard,
    required this.onToggleWorkdayPriorityMode,
    required this.buildCaptureInboxSection,
    required this.buildOutlookSection,
    required this.buildDailyCheckinSection,
    required this.buildDayPlannerSection,
    required this.buildTimerSection,
    required this.buildTaskComposerSection,
    required this.buildTaskListContent,
  });

  final bool showOverview;
  final bool showTaskList;
  final bool isNarrow;
  final double priorityCardsTotalWidth;
  final double priorityCardSpacing;
  final bool isGenerating;
  final bool prioritizeWorkOnWeekdays;
  final bool isWeekday;
  final ScrollController taskTabsScrollController;
  final List<Widget> taskTabs;
  final String taskSortLabel;
  final bool groupTasksByPriority;
  final ValueChanged<bool> onGroupByPriorityChanged;
  final ValueChanged<String> onSelectTaskSortMode;

  final List<Task> Function(int count) getTopTasks;
  final Widget Function(int position, Task? task) buildPriorityCard;
  final Future<void> Function() onToggleWorkdayPriorityMode;

  final Widget buildCaptureInboxSection;
  final Widget buildOutlookSection;
  final Widget buildDailyCheckinSection;
  final Widget buildDayPlannerSection;
  final Widget buildTimerSection;
  final Widget buildTaskComposerSection;
  final Widget Function() buildTaskListContent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        if (showOverview)
          TasksOverviewSection(
            isNarrow: isNarrow,
            priorityCardsTotalWidth: priorityCardsTotalWidth,
            priorityCardSpacing: priorityCardSpacing,
            getTopTasks: getTopTasks,
            buildPriorityCard: buildPriorityCard,
            prioritizeWorkOnWeekdays: prioritizeWorkOnWeekdays,
            isWeekday: isWeekday,
            onToggleWorkdayPriorityMode: onToggleWorkdayPriorityMode,
            buildCaptureInboxSection: buildCaptureInboxSection,
            buildOutlookSection: buildOutlookSection,
            buildDailyCheckinSection: buildDailyCheckinSection,
            buildDayPlannerSection: buildDayPlannerSection,
            buildTimerSection: buildTimerSection,
          ),
        if (showTaskList)
          Expanded(
            child: TaskListView(
              showOverview: showOverview,
              showTaskList: showTaskList,
              isGenerating: isGenerating,
              priorityCardsTotalWidth: priorityCardsTotalWidth,
              buildTaskComposerSection: buildTaskComposerSection,
              taskTabsScrollController: taskTabsScrollController,
              taskTabs: taskTabs,
              buildTaskListContent: buildTaskListContent,
              taskSortLabel: taskSortLabel,
              groupByPriority: groupTasksByPriority,
              onGroupByPriorityChanged: onGroupByPriorityChanged,
              onSelectTaskSortMode: onSelectTaskSortMode,
            ),
          ),
      ],
    );
  }
}
