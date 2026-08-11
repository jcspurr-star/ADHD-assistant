import 'package:flutter/material.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.showOverview,
    required this.showTaskList,
    required this.isGenerating,
    required this.priorityCardsTotalWidth,
    required this.buildTaskComposerSection,
    required this.taskTabsScrollController,
    required this.taskTabs,
    required this.buildTaskListContent,
    required this.taskSortLabel,
    required this.onSelectTaskSortMode,
    required this.groupByPriority,
    required this.onGroupByPriorityChanged,
  });

  final bool showOverview;
  final bool showTaskList;
  final bool isGenerating;
  final double priorityCardsTotalWidth;
  final Widget buildTaskComposerSection;
  final ScrollController taskTabsScrollController;
  final List<Widget> taskTabs;
  final Widget Function() buildTaskListContent;
  final String taskSortLabel;
  final ValueChanged<String> onSelectTaskSortMode;
  final bool groupByPriority;
  final ValueChanged<bool> onGroupByPriorityChanged;

  @override
  Widget build(BuildContext context) {
    if (!showTaskList) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFullWidth = constraints.maxWidth >= 1100;
        final contentWidth = useFullWidth
            ? constraints.maxWidth
            : priorityCardsTotalWidth
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble();
        final chromeHeight =
            (showOverview ? 27.0 : 0.0) +
            120.0 +
            12.0 +
            44.0 +
            10.0 +
            (isGenerating ? 36.0 : 0.0);
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final computedListHeight = hasBoundedHeight
            ? (constraints.maxHeight - chromeHeight).clamp(180.0, 5000.0)
            : 520.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showOverview) const SizedBox(height: 16),
            if (showOverview)
              const Divider(height: 1, thickness: 1, color: Colors.grey),
            if (showOverview) const SizedBox(height: 10),
            buildTaskComposerSection,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: contentWidth,
                child: SizedBox(
                  height: 44,
                  child: SingleChildScrollView(
                    controller: taskTabsScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...taskTabs,
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: 'Sort task list',
                          onSelected: onSelectTaskSortMode,
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'manual',
                              child: Text('Standard order'),
                            ),
                            PopupMenuItem<String>(
                              value: 'dueDate',
                              child: Text('Sort by due date'),
                            ),
                            PopupMenuItem<String>(
                              value: 'priority',
                              child: Text('Sort by priority'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sort,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  taskSortLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Group by priority'),
                          selected: groupByPriority,
                          onSelected: onGroupByPriorityChanged,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (isGenerating)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Generating starter steps...'),
                  ],
                ),
              ),
            if (hasBoundedHeight)
              Expanded(
                child: SizedBox(
                  width: contentWidth,
                  child: buildTaskListContent(),
                ),
              )
            else
              SizedBox(
                height: computedListHeight,
                child: SizedBox(
                  width: contentWidth,
                  child: buildTaskListContent(),
                ),
              ),
          ],
        );
      },
    );
  }
}
