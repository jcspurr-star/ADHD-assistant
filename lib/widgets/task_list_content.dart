import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/recommendation_service.dart';
import 'task_details_pane.dart';
import 'task_list_item_card.dart';

class TaskListContent extends StatelessWidget {
  const TaskListContent({
    super.key,
    required this.tasks,
    required this.visibleTaskIndices,
    required this.selectedTaskCategory,
    required this.groupTasksByPriority,
    required this.manualSortMode,
    required this.selectedTaskPaneIndex,
    required this.taskListScrollController,
    required this.getPriorityColor,
    required this.getPriorityLabel,
    required this.formatDueDate,
    required this.buildTaskPanels,
    required this.onToggleTask,
    required this.onToggleExpanded,
    required this.onSelectTaskPaneIndex,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onReorderVisibleTasks,
  });

  final List<Task> tasks;
  final List<int> visibleTaskIndices;
  final String selectedTaskCategory;
  final bool groupTasksByPriority;
  final bool manualSortMode;
  final int? selectedTaskPaneIndex;
  final ScrollController taskListScrollController;
  final Color Function(String priority) getPriorityColor;
  final String Function(String priority) getPriorityLabel;
  final String Function(String? raw) formatDueDate;
  final Widget Function(int taskIndex) buildTaskPanels;
  final void Function(int taskIndex, bool? value) onToggleTask;
  final void Function(int taskIndex) onToggleExpanded;
  final void Function(int? taskIndex) onSelectTaskPaneIndex;
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
    if (visibleTaskIndices.isEmpty) {
      return Center(
        child: Text(
          selectedTaskCategory == 'All tasks'
              ? 'No tasks yet.'
              : 'No tasks in this category.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final useTwoPaneLayout = MediaQuery.of(context).size.width >= 1100;
    int? effectiveSelectedTaskIndex = selectedTaskPaneIndex;
    if (useTwoPaneLayout &&
        (effectiveSelectedTaskIndex == null ||
            !visibleTaskIndices.contains(effectiveSelectedTaskIndex))) {
      effectiveSelectedTaskIndex = null;
    }

    Widget buildTaskListItem(BuildContext context, int taskIndex) {
      final task = tasks[taskIndex];
      final baseAccentColor = getPriorityColor(task.priority);
      final cardColor = task.done ? Colors.grey.shade100 : Colors.white;
      final isSelectedInPane =
          useTwoPaneLayout && taskIndex == effectiveSelectedTaskIndex;
      final borderColor = isSelectedInPane
          ? Colors.blue.shade400
          : task.done
          ? Colors.grey.shade300
          : baseAccentColor.withAlpha(150);
      final gutterWidth = useTwoPaneLayout ? 26.0 : 22.0;
      final gutterColor = task.done
          ? Colors.grey.shade400
          : getPriorityColor(task.priority);
      final dueDateLabel = formatDueDate(task.dueDate);
      final planDateLabel = formatDueDate(task.doDate);
      final progressPercent =
          (RecommendationService.getTaskProgress(task) * 100).round();

      return TaskListItemCard(
        key: ValueKey('${taskIndex}_${task.task}'),
        task: task,
        gutterWidth: gutterWidth,
        gutterColor: gutterColor,
        cardColor: cardColor,
        borderColor: borderColor,
        baseAccentColor: baseAccentColor,
        isSelected: isSelectedInPane,
        priorityLabel: getPriorityLabel(task.priority),
        progressPercent: progressPercent,
        categoryLabel: task.category == 'None' ? null : task.category,
        planDateLabel: planDateLabel.isEmpty ? null : planDateLabel,
        dueDateLabel: dueDateLabel.isEmpty ? null : dueDateLabel,
        onToggle: (value) {
          onToggleTask(taskIndex, value);
        },
        onOpen: () {
          if (useTwoPaneLayout) {
            onSelectTaskPaneIndex(
              selectedTaskPaneIndex == taskIndex ? null : taskIndex,
            );
          } else {
            onToggleExpanded(taskIndex);
          }
        },
        onEdit: () {
          onEditTask(taskIndex);
        },
        onDelete: () {
          onDeleteTask(taskIndex);
        },
        showReorderDrag: !groupTasksByPriority && manualSortMode,
        reorderIndex: taskIndex,
        expandedContent: !useTwoPaneLayout && task.expanded
            ? buildTaskPanels(taskIndex)
            : null,
      );
    }

    Widget buildSimpleList(List<int> indices) {
      return ListView.builder(
        controller: taskListScrollController,
        padding: EdgeInsets.zero,
        itemCount: indices.length,
        itemBuilder: (context, listIndex) {
          return buildTaskListItem(context, indices[listIndex]);
        },
      );
    }

    Widget baseList;

    if (groupTasksByPriority) {
      final grouped = <String, List<int>>{
        'high': [],
        'medium': [],
        'low': [],
        'other': [],
      };

      for (final index in visibleTaskIndices) {
        final priority = tasks[index].priority;
        if (grouped.containsKey(priority)) {
          grouped[priority]!.add(index);
        } else {
          grouped['other']!.add(index);
        }
      }

      final groupedOrder = <int>[
        ...grouped['high']!,
        ...grouped['medium']!,
        ...grouped['low']!,
        ...grouped['other']!,
      ];

      baseList = ListView.builder(
        controller: taskListScrollController,
        padding: EdgeInsets.zero,
        itemCount: groupedOrder.length,
        itemBuilder: (context, listIndex) {
          return buildTaskListItem(context, groupedOrder[listIndex]);
        },
      );
    } else if (!manualSortMode) {
      baseList = buildSimpleList(visibleTaskIndices);
    } else {
      baseList = ReorderableListView.builder(
        scrollController: taskListScrollController,
        padding: EdgeInsets.zero,
        buildDefaultDragHandles: false,
        itemCount: visibleTaskIndices.length,
        onReorderItem: (oldIndex, newIndex) async {
          await onReorderVisibleTasks(oldIndex, newIndex, visibleTaskIndices);
        },
        itemBuilder: (context, listIndex) {
          return buildTaskListItem(context, visibleTaskIndices[listIndex]);
        },
      );
    }

    if (!useTwoPaneLayout) {
      return baseList;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: baseList),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: TaskDetailsPane(
            hasSelection: effectiveSelectedTaskIndex != null,
            title: effectiveSelectedTaskIndex == null
                ? null
                : tasks[effectiveSelectedTaskIndex].task,
            child: effectiveSelectedTaskIndex == null
                ? null
                : buildTaskPanels(effectiveSelectedTaskIndex),
          ),
        ),
      ],
    );
  }
}
