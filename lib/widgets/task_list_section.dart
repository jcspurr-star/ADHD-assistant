import 'package:flutter/material.dart';

import '../models/task.dart';
import 'task_list_content.dart';

class TaskListSection extends StatelessWidget {
  const TaskListSection({
    super.key,
    required this.tasks,
    required this.visibleTaskIndices,
    required this.selectedTaskCategory,
    required this.groupTasksByPriority,
    required this.selectedTaskSortModeIsManual,
    required this.selectedTaskPaneIndex,
    required this.taskListScrollController,
    required this.getPriorityColor,
    required this.getPriorityLabel,
    required this.categories,
    required this.formatDueDate,
    required this.buildTaskPanels,
    required this.onToggleTask,
    required this.onToggleExpanded,
    required this.onSelectTaskPaneIndex,
    required this.onPriorityChanged,
    required this.onSetDueDate,
    required this.onSetPlanDate,
    required this.onSetTaskEffort,
    required this.onSetNextSessionEffort,
    required this.onCategoryChanged,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onReorderVisibleTasks,
  });

  final List<Task> tasks;
  final List<int> visibleTaskIndices;
  final String selectedTaskCategory;
  final bool groupTasksByPriority;
  final bool selectedTaskSortModeIsManual;
  final int? selectedTaskPaneIndex;
  final ScrollController taskListScrollController;
  final Color Function(String priority) getPriorityColor;
  final String Function(String priority) getPriorityLabel;
  final List<String> categories;
  final String Function(String? raw) formatDueDate;
  final Widget Function(int taskIndex) buildTaskPanels;
  final void Function(int taskIndex, bool? value) onToggleTask;
  final void Function(int taskIndex) onToggleExpanded;
  final void Function(int? taskIndex) onSelectTaskPaneIndex;
  final void Function(int taskIndex, String value) onPriorityChanged;
  final Future<void> Function(int taskIndex) onSetDueDate;
  final Future<void> Function(int taskIndex) onSetPlanDate;
  final Future<void> Function(int taskIndex, int? minutes) onSetTaskEffort;
  final Future<void> Function(int taskIndex, int? minutes)
  onSetNextSessionEffort;
  final void Function(int taskIndex, String value) onCategoryChanged;
  final void Function(int taskIndex) onEditTask;
  final void Function(int taskIndex) onDeleteTask;
  final Future<void> Function(
    int oldIndex,
    int newIndex,
    List<int> visibleTaskIndices,
  )
  onReorderVisibleTasks;

  @override
  Widget build(BuildContext context) {
    return TaskListContent(
      tasks: tasks,
      visibleTaskIndices: visibleTaskIndices,
      selectedTaskCategory: selectedTaskCategory,
      groupTasksByPriority: groupTasksByPriority,
      manualSortMode: selectedTaskSortModeIsManual,
      selectedTaskPaneIndex: selectedTaskPaneIndex,
      taskListScrollController: taskListScrollController,
      getPriorityColor: getPriorityColor,
      getPriorityLabel: getPriorityLabel,
      categories: categories,
      formatDueDate: formatDueDate,
      buildTaskPanels: buildTaskPanels,
      onToggleTask: onToggleTask,
      onToggleExpanded: onToggleExpanded,
      onSelectTaskPaneIndex: onSelectTaskPaneIndex,
      onPriorityChanged: onPriorityChanged,
      onSetDueDate: onSetDueDate,
      onSetPlanDate: onSetPlanDate,
      onSetTaskEffort: onSetTaskEffort,
      onSetNextSessionEffort: onSetNextSessionEffort,
      onCategoryChanged: onCategoryChanged,
      onEditTask: onEditTask,
      onDeleteTask: onDeleteTask,
      onReorderVisibleTasks: onReorderVisibleTasks,
    );
  }
}
