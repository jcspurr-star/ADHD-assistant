import 'package:flutter/material.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.showOverview,
    required this.showTaskList,
    required this.isGenerating,
    required this.priorityCardsTotalWidth,
    required this.taskTabsScrollController,
    required this.taskTabs,
    required this.buildTaskListContent,
    required this.hasAnyExpandedTask,
    required this.taskSortLabel,
    required this.onSelectTaskSortMode,
    required this.onToggleExpandAll,
  });

  final bool showOverview;
  final bool showTaskList;
  final bool isGenerating;
  final double priorityCardsTotalWidth;
  final ScrollController taskTabsScrollController;
  final List<Widget> taskTabs;
  final Widget Function() buildTaskListContent;
  final bool hasAnyExpandedTask;
  final String taskSortLabel;
  final ValueChanged<String> onSelectTaskSortMode;
  final Future<void> Function() onToggleExpandAll;

  @override
  Widget build(BuildContext context) {
    if (!showTaskList) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chromeHeight =
            (showOverview ? 27.0 : 0.0) +
            44.0 +
            10.0 +
            (isGenerating ? 36.0 : 0.0);
        final computedListHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - chromeHeight).clamp(180.0, 5000.0)
            : 520.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showOverview) const SizedBox(height: 16),
            if (showOverview)
              const Divider(height: 1, thickness: 1, color: Colors.grey),
            if (showOverview) const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: priorityCardsTotalWidth,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: SingleChildScrollView(
                          controller: taskTabsScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(children: taskTabs),
                        ),
                      ),
                    ),
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
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onToggleExpandAll();
                      },
                      icon: Icon(
                        hasAnyExpandedTask
                            ? Icons.unfold_less
                            : Icons.unfold_more,
                        size: 16,
                      ),
                      label: Text(
                        hasAnyExpandedTask ? 'Collapse all' : 'Expand all',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
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
            SizedBox(
              height: computedListHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: priorityCardsTotalWidth,
                  child: buildTaskListContent(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
