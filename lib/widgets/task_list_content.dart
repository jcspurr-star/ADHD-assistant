import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/recommendation_service.dart';
import 'task_details_pane.dart';
import 'task_summary_card.dart';
import 'task_tile.dart';

class TaskListContent extends StatelessWidget {
  const TaskListContent({
    super.key,
    required this.tasks,
    required this.visibleTaskIndices,
    required this.selectedTaskCategory,
    required this.groupTasksByPriority,
    required this.cardViewEnabled,
    required this.archiveViewEnabled,
    required this.manualSortMode,
    required this.selectedTaskPaneIndex,
    required this.taskListScrollController,
    required this.getPriorityColor,
    required this.getPriorityLabel,
    required this.categories,
    required this.formatDueDate,
    required this.formatStartDate,
    required this.buildTaskPanels,
    required this.onToggleTask,
    required this.onToggleExpanded,
    required this.onSelectTaskPaneIndex,
    required this.onPriorityChanged,
    required this.onSetDueDate,
    required this.onSetPlanDate,
    required this.onStartTaskToday,
    required this.onSetTaskEffort,
    required this.onSetNextSessionEffort,
    required this.onCategoryChanged,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onCategorizeForMenu,
    required this.onToggleAbsolutePriority,
    required this.onToggleExcludeWhenOverdue,
    required this.onToggleWaitingOnOthers,
    required this.onToggleSillyModeExempt,
    required this.onReorderVisibleTasks,
  });

  final List<Task> tasks;
  final List<int> visibleTaskIndices;
  final String selectedTaskCategory;
  final bool groupTasksByPriority;
  final bool cardViewEnabled;
  final bool archiveViewEnabled;
  final bool manualSortMode;
  final int? selectedTaskPaneIndex;
  final ScrollController taskListScrollController;
  final Color Function(String priority) getPriorityColor;
  final String Function(String priority) getPriorityLabel;
  final List<String> categories;
  final String Function(String? raw) formatDueDate;
  final String Function(String? raw) formatStartDate;
  final Widget Function(int taskIndex) buildTaskPanels;
  final void Function(int taskIndex, bool? value) onToggleTask;
  final void Function(int taskIndex) onToggleExpanded;
  final void Function(int? taskIndex) onSelectTaskPaneIndex;
  final void Function(int taskIndex, String value) onPriorityChanged;
  final Future<void> Function(int taskIndex) onSetDueDate;
  final Future<void> Function(int taskIndex) onSetPlanDate;
  final void Function(int taskIndex) onStartTaskToday;
  final Future<void> Function(int taskIndex, int? minutes) onSetTaskEffort;
  final Future<void> Function(int taskIndex, int? minutes)
  onSetNextSessionEffort;
  final void Function(int taskIndex, String value) onCategoryChanged;
  final void Function(int taskIndex) onEditTask;
  final void Function(int taskIndex) onDeleteTask;
  final void Function(int taskIndex) onCategorizeForMenu;
  final void Function(int taskIndex) onToggleAbsolutePriority;
  final void Function(int taskIndex) onToggleExcludeWhenOverdue;
  final void Function(int taskIndex) onToggleWaitingOnOthers;
  final void Function(int taskIndex) onToggleSillyModeExempt;
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
          archiveViewEnabled
              ? 'No completed tasks yet.'
              : selectedTaskCategory == 'All tasks'
              ? 'No tasks yet.'
              : 'No tasks in this category.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final useTwoPaneLayout = MediaQuery.of(context).size.width >= 1100;

    if (cardViewEnabled) {
      return _buildCardView(useTwoPaneLayout);
    }

    int? effectiveSelectedTaskIndex = selectedTaskPaneIndex;
    if (useTwoPaneLayout &&
        (effectiveSelectedTaskIndex == null ||
            !visibleTaskIndices.contains(effectiveSelectedTaskIndex))) {
      effectiveSelectedTaskIndex = null;
    }

    Widget buildTaskListItem(
      BuildContext context,
      int taskIndex, {
      required int reorderableIndex,
    }) {
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
      final gutterColor = task.done
          ? Colors.grey.shade400
          : getPriorityColor(task.priority);
      final dueDateLabel = formatDueDate(task.dueDate);
      final planDateLabel = formatStartDate(task.doDate);
      void openTask() {
        if (useTwoPaneLayout) {
          onSelectTaskPaneIndex(
            selectedTaskPaneIndex == taskIndex ? null : taskIndex,
          );
        } else {
          onToggleExpanded(taskIndex);
        }
      }

      return Padding(
        key: ValueKey('${taskIndex}_${task.task}'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelectedInPane ? 1.6 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 6, color: gutterColor),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TaskTile(
                        task: task,
                        dueDateText: dueDateLabel,
                        planDateText: planDateLabel,
                        nextSessionEffortMinutes: task.nextSessionEffortMinutes,
                        totalEffortMinutes: task.effortMinutes,
                        progress: RecommendationService.getTaskProgress(task),
                        categories: categories,
                        category: task.category,
                        priority: task.priority,
                        isGenerating: false,
                        onToggle: (value) {
                          onToggleTask(taskIndex, value);
                        },
                        reorderableIndex: reorderableIndex,
                        onOpen: openTask,
                        onPriorityChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          onPriorityChanged(taskIndex, value);
                        },
                        onDueDate: () {
                          onSetDueDate(taskIndex);
                        },
                        onPlanDate: () {
                          onSetPlanDate(taskIndex);
                        },
                        onStartToday: () {
                          onStartTaskToday(taskIndex);
                        },
                        onTotalEffortChanged: (minutes) {
                          onSetTaskEffort(taskIndex, minutes);
                        },
                        onNextSessionEffortChanged: (minutes) {
                          onSetNextSessionEffort(taskIndex, minutes);
                        },
                        onCategoryChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          onCategoryChanged(taskIndex, value);
                        },
                        onEdit: () {
                          onEditTask(taskIndex);
                        },
                        onDelete: () {
                          onDeleteTask(taskIndex);
                        },
                        onCategorizeForMenu: () {
                          onCategorizeForMenu(taskIndex);
                        },
                        onToggleAbsolutePriority: () {
                          onToggleAbsolutePriority(taskIndex);
                        },
                        onToggleExcludeWhenOverdue: () {
                          onToggleExcludeWhenOverdue(taskIndex);
                        },
                        onToggleWaitingOnOthers: () {
                          onToggleWaitingOnOthers(taskIndex);
                        },
                        onToggleSillyModeExempt: () {
                          onToggleSillyModeExempt(taskIndex);
                        },
                        allowReorderDrag:
                            !groupTasksByPriority && manualSortMode,
                      ),
                      if (!useTwoPaneLayout && task.expanded) ...[
                        const SizedBox(height: 8),
                        buildTaskPanels(taskIndex),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildIndicesList(List<int> indices, {required bool scrollable}) {
      final orderedIndices = groupTasksByPriority
          ? _groupedOrder(indices)
          : indices;

      if (groupTasksByPriority || !manualSortMode) {
        return ListView.builder(
          controller: scrollable ? taskListScrollController : null,
          shrinkWrap: !scrollable,
          physics: scrollable ? null : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: orderedIndices.length,
          itemBuilder: (context, listIndex) {
            return buildTaskListItem(
              context,
              orderedIndices[listIndex],
              reorderableIndex: listIndex,
            );
          },
        );
      }

      return ReorderableListView.builder(
        scrollController: scrollable ? taskListScrollController : null,
        shrinkWrap: !scrollable,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        buildDefaultDragHandles: false,
        itemCount: orderedIndices.length,
        onReorderItem: (oldIndex, newIndex) async {
          await onReorderVisibleTasks(oldIndex, newIndex, orderedIndices);
        },
        itemBuilder: (context, listIndex) {
          return buildTaskListItem(
            context,
            orderedIndices[listIndex],
            reorderableIndex: listIndex,
          );
        },
      );
    }

    Widget baseList;

    if (archiveViewEnabled) {
      baseList = buildIndicesList(visibleTaskIndices, scrollable: true);
    } else {
      final readyIndices = visibleTaskIndices
          .where((index) => tasks[index].hasCompletePlanningMetadata)
          .toList();
      final holdingIndices = visibleTaskIndices
          .where((index) => !tasks[index].hasCompletePlanningMetadata)
          .toList();

      baseList = ListView(
        controller: taskListScrollController,
        padding: EdgeInsets.zero,
        children: [
          _buildReadinessSectionHeader(
            'Ready tasks',
            readyIndices.length,
            icon: Icons.check_circle,
            color: Colors.green.shade700,
          ),
          if (readyIndices.isEmpty)
            _buildEmptySectionHint('No tasks ready to plan yet.')
          else
            buildIndicesList(readyIndices, scrollable: false),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildReadinessSectionHeader(
            'Tasks holding area',
            holdingIndices.length,
            icon: Icons.inventory_2_outlined,
            color: Colors.blueGrey.shade600,
          ),
          if (holdingIndices.isEmpty)
            _buildEmptySectionHint(
              'Nothing waiting \u2014 every task has priority, a date, and an effort estimate.',
            )
          else
            buildIndicesList(holdingIndices, scrollable: false),
        ],
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

  List<int> _groupedOrder(List<int> indices) {
    final grouped = <String, List<int>>{
      'high': [],
      'medium': [],
      'low': [],
      'other': [],
    };
    for (final index in indices) {
      final priority = tasks[index].priority;
      if (grouped.containsKey(priority)) {
        grouped[priority]!.add(index);
      } else {
        grouped['other']!.add(index);
      }
    }
    return [
      ...grouped['high']!,
      ...grouped['medium']!,
      ...grouped['low']!,
      ...grouped['other']!,
    ];
  }

  Widget _buildReadinessSectionHeader(
    String title,
    int count, {
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySectionHint(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  // Card view: a wrapping grid of small square summary cards. Tapping a card
  // "opens" it — duplicating it at the top as a normal row tile (with its
  // subtask panel shown the same way row view does) — without removing the
  // card from the grid. Tapping that row tile again closes it.
  Widget _buildCardView(bool useTwoPaneLayout) {
    final orderedIndices = groupTasksByPriority
        ? _groupedOrder(visibleTaskIndices)
        : visibleTaskIndices;
    final openedIndex =
        selectedTaskPaneIndex != null &&
            visibleTaskIndices.contains(selectedTaskPaneIndex)
        ? selectedTaskPaneIndex
        : null;

    Widget buildOpenedTile(int taskIndex) {
      final task = tasks[taskIndex];
      final baseAccentColor = getPriorityColor(task.priority);
      final cardColor = task.done ? Colors.grey.shade100 : Colors.white;
      final dueDateLabel = formatDueDate(task.dueDate);
      final planDateLabel = formatStartDate(task.doDate);
      return Container(
        key: ValueKey('opened_${taskIndex}_${task.task}'),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade400, width: 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 6, color: baseAccentColor),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskTile(
                      task: task,
                      dueDateText: dueDateLabel,
                      planDateText: planDateLabel,
                      nextSessionEffortMinutes: task.nextSessionEffortMinutes,
                      totalEffortMinutes: task.effortMinutes,
                      progress: RecommendationService.getTaskProgress(task),
                      categories: categories,
                      category: task.category,
                      priority: task.priority,
                      isGenerating: false,
                      onToggle: (value) {
                        onToggleTask(taskIndex, value);
                      },
                      reorderableIndex: 0,
                      // Tapping the duplicated row tile closes it again — the
                      // matching card in the grid below stays put.
                      onOpen: () => onSelectTaskPaneIndex(null),
                      onPriorityChanged: (value) {
                        if (value == null) return;
                        onPriorityChanged(taskIndex, value);
                      },
                      onDueDate: () {
                        onSetDueDate(taskIndex);
                      },
                      onPlanDate: () {
                        onSetPlanDate(taskIndex);
                      },
                      onStartToday: () {
                        onStartTaskToday(taskIndex);
                      },
                      onTotalEffortChanged: (minutes) {
                        onSetTaskEffort(taskIndex, minutes);
                      },
                      onNextSessionEffortChanged: (minutes) {
                        onSetNextSessionEffort(taskIndex, minutes);
                      },
                      onCategoryChanged: (value) {
                        if (value == null) return;
                        onCategoryChanged(taskIndex, value);
                      },
                      onEdit: () {
                        onEditTask(taskIndex);
                      },
                      onDelete: () {
                        onDeleteTask(taskIndex);
                      },
                      onCategorizeForMenu: () {
                        onCategorizeForMenu(taskIndex);
                      },
                      onToggleAbsolutePriority: () {
                        onToggleAbsolutePriority(taskIndex);
                      },
                      onToggleExcludeWhenOverdue: () {
                        onToggleExcludeWhenOverdue(taskIndex);
                      },
                      onToggleWaitingOnOthers: () {
                        onToggleWaitingOnOthers(taskIndex);
                      },
                      onToggleSillyModeExempt: () {
                        onToggleSillyModeExempt(taskIndex);
                      },
                      allowReorderDrag: false,
                    ),
                    if (!useTwoPaneLayout) ...[
                      const SizedBox(height: 8),
                      buildTaskPanels(taskIndex),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final cardsGrid = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: orderedIndices.map((taskIndex) {
        final task = tasks[taskIndex];
        return TaskSummaryCard(
          key: ValueKey('card_${taskIndex}_${task.task}'),
          task: task,
          priorityColor: getPriorityColor(task.priority),
          priorityLabel: getPriorityLabel(task.priority),
          dueDateText: formatDueDate(task.dueDate),
          isSelected: taskIndex == openedIndex,
          // Tapping the already-opened card closes it too, same as tapping
          // the duplicated row tile.
          onTap: () => onSelectTaskPaneIndex(
            taskIndex == openedIndex ? null : taskIndex,
          ),
        );
      }).toList(),
    );

    Widget buildGrid(List<int> indices) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: indices.map((taskIndex) {
          final task = tasks[taskIndex];
          return TaskSummaryCard(
            key: ValueKey('card_${taskIndex}_${task.task}'),
            task: task,
            priorityColor: getPriorityColor(task.priority),
            priorityLabel: getPriorityLabel(task.priority),
            dueDateText: formatDueDate(task.dueDate),
            isSelected: taskIndex == openedIndex,
            onTap: () => onSelectTaskPaneIndex(
              taskIndex == openedIndex ? null : taskIndex,
            ),
          );
        }).toList(),
      );
    }

    final sectionedGrids = archiveViewEnabled
        ? cardsGrid
        : Builder(
            builder: (context) {
              final readyIndices = orderedIndices
                  .where((index) => tasks[index].hasCompletePlanningMetadata)
                  .toList();
              final holdingIndices = orderedIndices
                  .where((index) => !tasks[index].hasCompletePlanningMetadata)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadinessSectionHeader(
                    'Ready tasks',
                    readyIndices.length,
                    icon: Icons.check_circle,
                    color: Colors.green.shade700,
                  ),
                  if (readyIndices.isEmpty)
                    _buildEmptySectionHint('No tasks ready to plan yet.')
                  else
                    buildGrid(readyIndices),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _buildReadinessSectionHeader(
                    'Tasks holding area',
                    holdingIndices.length,
                    icon: Icons.inventory_2_outlined,
                    color: Colors.blueGrey.shade600,
                  ),
                  if (holdingIndices.isEmpty)
                    _buildEmptySectionHint(
                      'Nothing waiting \u2014 every task has priority, a date, and an effort estimate.',
                    )
                  else
                    buildGrid(holdingIndices),
                ],
              );
            },
          );

    final cardsColumn = SingleChildScrollView(
      controller: taskListScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // In the two-pane layout the opened tile moves into the details
          // pane instead, above its subtasks, so it isn't shown twice.
          if (openedIndex != null && !useTwoPaneLayout)
            buildOpenedTile(openedIndex),
          sectionedGrids,
        ],
      ),
    );

    if (!useTwoPaneLayout) {
      return cardsColumn;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: cardsColumn),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: TaskDetailsPane(
            hasSelection: openedIndex != null,
            child: openedIndex == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildOpenedTile(openedIndex),
                      buildTaskPanels(openedIndex),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
