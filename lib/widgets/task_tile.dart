import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;

  final bool isGenerating;
  final double progress;
  final List<String> categories;
  final String category;
  final ValueChanged<bool?> onToggle;
  final int reorderableIndex;
  final String priority;
  final ValueChanged<String?> onPriorityChanged;
  final VoidCallback? onOpen;
  final VoidCallback onDueDate;
  final VoidCallback onPlanDate;
  final ValueChanged<int?> onTotalEffortChanged;
  final ValueChanged<int?> onNextSessionEffortChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAbsolutePriority;
  final VoidCallback onToggleExcludeWhenOverdue;
  final VoidCallback onToggleWaitingOnOthers;
  final String dueDateText;
  final String planDateText;
  final int? nextSessionEffortMinutes;
  final int? totalEffortMinutes;
  final bool allowReorderDrag;
  static const double _metaWidthWithLabel = 106;
  static const double _metaWidthCompact = 106;
  static const List<int> _totalEffortOptions = [
    5,
    15,
    30,
    45,
    60,
    90,
    120,
    180,
    240,
    360,
    480,
  ];
  static const List<int> _nextSessionEffortOptions = [
    5,
    15,
    30,
    45,
    60,
    90,
    120,
    180,
    240,
  ];

  const TaskTile({
    super.key,
    required this.task,
    required this.isGenerating,
    required this.categories,
    required this.category,
    required this.onToggle,
    required this.reorderableIndex,
    required this.priority,
    required this.onPriorityChanged,
    this.onOpen,
    required this.onDueDate,
    required this.onPlanDate,
    required this.onTotalEffortChanged,
    required this.onNextSessionEffortChanged,
    required this.onCategoryChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAbsolutePriority,
    required this.onToggleExcludeWhenOverdue,
    required this.onToggleWaitingOnOthers,
    required this.progress,
    required this.dueDateText,
    required this.planDateText,
    required this.nextSessionEffortMinutes,
    required this.totalEffortMinutes,
    this.allowReorderDrag = true,
  });

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget buildOverflowScrollableText(
    String value, {
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Text(
        value,
        maxLines: 1,
        softWrap: false,
        textAlign: textAlign,
        style: style,
      ),
    );
  }

  Widget buildMetaLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 3),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget buildDueDateControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMetaLabel('Due date'),
        GestureDetector(
          onTap: onDueDate,
          child: Tooltip(
            message: 'Due date: when this task must be finished.',
            child: Container(
              height: 32,
              width: showLabel ? _metaWidthWithLabel : _metaWidthCompact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    dueDateText.isEmpty
                        ? Icons.calendar_today_outlined
                        : Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: buildOverflowScrollableText(
                      dueDateText.isEmpty ? 'No date' : dueDateText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: dueDateText.isEmpty
                            ? Colors.grey.shade600
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPlanDateControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMetaLabel('Plan date'),
        GestureDetector(
          onTap: onPlanDate,
          child: Tooltip(
            message:
                'Plan date: when this task should start surfacing for action.',
            child: Container(
              height: 32,
              width: showLabel ? _metaWidthWithLabel : _metaWidthCompact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    planDateText.isEmpty
                        ? Icons.event_available_outlined
                        : Icons.event_available,
                    size: 14,
                    color: Colors.indigo.shade600,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: buildOverflowScrollableText(
                      planDateText.isEmpty ? 'No plan' : planDateText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: planDateText.isEmpty
                            ? Colors.grey.shade600
                            : Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCategoryControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMetaLabel('Category'),
        Tooltip(
          message: 'Category: what area of life or work this task belongs to.',
          child: Container(
            height: 32,
            width: showLabel ? _metaWidthWithLabel : _metaWidthCompact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: categories.contains(category) ? category : null,
                hint: const Text(
                  'Category',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                dropdownColor: Colors.white,
                focusColor: Colors.transparent,
                isExpanded: true,
                isDense: true,
                iconSize: 14,
                itemHeight: kMinInteractiveDimension,
                selectedItemBuilder: (BuildContext context) {
                  return categories.map((categoryValue) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        categoryValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }).toList();
                },
                items: categories.map((categoryValue) {
                  return DropdownMenuItem<String>(
                    value: categoryValue,
                    child: Text(
                      categoryValue,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }).toList(),
                onChanged: onCategoryChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPriorityControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMetaLabel('Priority'),
        Tooltip(
          message: 'Priority: how important or urgent this task is overall.',
          child: Container(
            height: 32,
            width: showLabel ? _metaWidthWithLabel : _metaWidthCompact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: priority,
                hint: const Text(
                  'Priority',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                dropdownColor: Colors.white,
                focusColor: Colors.transparent,
                isExpanded: true,
                isDense: true,
                iconSize: 16,
                selectedItemBuilder: (BuildContext context) {
                  return ['high', 'medium', 'low'].map((value) {
                    final label = value == 'high'
                        ? 'High'
                        : value == 'medium'
                        ? 'Medium'
                        : 'Low';
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: getPriorityColor(value),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: getPriorityColor(value),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: const [
                  DropdownMenuItem(
                    value: 'high',
                    child: _PriorityOption(color: Colors.red, label: 'High'),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: _PriorityOption(
                      color: Colors.orange,
                      label: 'Medium',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'low',
                    child: _PriorityOption(color: Colors.green, label: 'Low'),
                  ),
                ],
                onChanged: onPriorityChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String formatEffortLabel(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return '';
    }
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }

  Widget buildEffortControl({
    required bool showLabel,
    required String title,
    required int? value,
    required String hint,
    required String tooltip,
    required Color color,
    required List<int> options,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMetaLabel(title),
        Tooltip(
          message: tooltip,
          child: Container(
            height: 32,
            width: showLabel ? _metaWidthWithLabel : _metaWidthCompact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: value,
                hint: Text(
                  hint,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                dropdownColor: Colors.white,
                focusColor: Colors.transparent,
                isExpanded: true,
                isDense: true,
                iconSize: 14,
                selectedItemBuilder: (BuildContext context) {
                  return [null, ...options].map((minutes) {
                    final label = minutes == null
                        ? hint
                        : formatEffortLabel(minutes);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: minutes == null ? Colors.grey.shade600 : color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  ...options.map((minutes) {
                    return DropdownMenuItem<int?>(
                      value: minutes,
                      child: Text(
                        formatEffortLabel(minutes),
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    );
                  }),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildControlWrap({
    required bool showLabel,
    required bool includeCompletion,
  }) {
    final controls = <Widget>[
      if (includeCompletion) buildCompletionControl(showLabel: showLabel),
      buildPlanDateControl(showLabel: showLabel),
      buildDueDateControl(showLabel: showLabel),
      buildEffortControl(
        showLabel: showLabel,
        title: 'Total effort',
        value: totalEffortMinutes,
        hint: 'Total',
        tooltip:
            'Whole-task effort: roughly how much time the full task will take overall.',
        color: Colors.teal.shade700,
        options: _totalEffortOptions,
        onChanged: onTotalEffortChanged,
      ),
      buildEffortControl(
        showLabel: showLabel,
        title: 'Next session effort',
        value: nextSessionEffortMinutes,
        hint: 'Next',
        tooltip:
            'Next-session effort: how large the next scheduled work block should be.',
        color: Colors.cyan.shade800,
        options: _nextSessionEffortOptions,
        onChanged: onNextSessionEffortChanged,
      ),
      buildPriorityControl(showLabel: showLabel),
      buildCategoryControl(showLabel: showLabel),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: controls,
    );
  }

  Widget buildCompletionControl({required bool showLabel}) {
    final effectiveProgress = task.subtasks.isEmpty
        ? (task.done ? 1.0 : 0.0)
        : progress.clamp(0.0, 1.0);
    final percent = (effectiveProgress * 100).round();
    final accent = task.done ? Colors.green.shade700 : Colors.blue.shade700;
    const ringSize = 26.0;
    const boxHeight = 32.0;
    final boxWidth = showLabel ? _metaWidthWithLabel : _metaWidthCompact;

    return Tooltip(
      message:
          '${task.done ? 'Mark incomplete' : 'Mark completed'} ($percent% complete)',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onToggle(!task.done),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel) buildMetaLabel('Complete'),
            Container(
              height: boxHeight,
              width: boxWidth,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: effectiveProgress,
                        strokeWidth: 3.4,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTrailingActions({bool compactHeader = false}) {
    final iconSize = compactHeader ? 16.0 : 20.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            task.absolutePriority ? Icons.priority_high : Icons.low_priority,
            size: iconSize,
            color: task.absolutePriority ? Colors.deepPurple.shade600 : null,
          ),
          tooltip: task.absolutePriority
              ? 'Absolute priority: scheduled first until due date (tap to clear)'
              : 'Make absolute priority: schedule total effort first until due date',
          visualDensity: VisualDensity.compact,
          onPressed: onToggleAbsolutePriority,
        ),
        IconButton(
          icon: Icon(
            task.excludeWhenOverdue
                ? Icons.event_busy
                : Icons.event_busy_outlined,
            size: iconSize,
            color: task.excludeWhenOverdue ? Colors.red.shade600 : null,
          ),
          tooltip: task.excludeWhenOverdue
              ? "Won't carry over once overdue (tap to allow)"
              : 'Allow carry-over when overdue (tap to block)',
          visualDensity: VisualDensity.compact,
          onPressed: onToggleExcludeWhenOverdue,
        ),
        IconButton(
          icon: Icon(
            task.waitingOnOthers ? Icons.hourglass_full : Icons.hourglass_empty,
            size: iconSize,
            color: task.waitingOnOthers ? Colors.blue.shade600 : null,
          ),
          tooltip: task.waitingOnOthers
              ? 'Waiting on others (tap to make eligible for planning)'
              : 'Mark as waiting on others (excludes from planning)',
          visualDensity: VisualDensity.compact,
          onPressed: onToggleWaitingOnOthers,
        ),
        IconButton(
          icon: Icon(Icons.edit, size: iconSize),
          tooltip: 'Edit task',
          visualDensity: VisualDensity.compact,
          onPressed: onEdit,
        ),
        IconButton(
          icon: Icon(Icons.delete, size: iconSize),
          tooltip: 'Delete task',
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
        ),
      ],
    );
  }

  Widget buildReorderGrabber({required bool useTallCompactStyle}) {
    final handleWidth = useTallCompactStyle ? 28.0 : 30.0;
    final handleIconSize = useTallCompactStyle ? 18.0 : 18.0;
    final handleHeight = useTallCompactStyle ? 56.0 : 34.0;

    return ReorderableDragStartListener(
      index: reorderableIndex,
      child: Tooltip(
        message: 'Drag to reorder',
        child: Container(
          height: handleHeight,
          width: handleWidth,
          margin: EdgeInsets.only(left: useTallCompactStyle ? 2 : 4),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Center(
            child: Icon(
              Icons.drag_indicator,
              size: handleIconSize,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 620;
    const titleBoxHeight = 34.0;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: titleBoxHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      task.task,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              buildTrailingActions(),
              if (allowReorderDrag) const SizedBox(width: 4),
              if (allowReorderDrag)
                buildReorderGrabber(useTallCompactStyle: false),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isNarrow ? 6 : 4),
                buildControlWrap(showLabel: true, includeCompletion: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  final Color color;
  final String label;

  const _PriorityOption({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
