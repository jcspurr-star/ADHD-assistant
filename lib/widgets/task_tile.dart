import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;

  final bool isGenerating;
  final double progress;
  final bool compactView;
  final List<String> categories;
  final String category;
  final ValueChanged<bool?> onToggle;
  final int reorderableIndex;
  final String priority;
  final ValueChanged<String?> onPriorityChanged;
  final VoidCallback onDueDate;
  final VoidCallback onPlanDate;
  final ValueChanged<int?> onTotalEffortChanged;
  final ValueChanged<int?> onNextSessionEffortChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String dueDateText;
  final String planDateText;
  final int? nextSessionEffortMinutes;
  final int? totalEffortMinutes;
  final bool allowReorderDrag;
  static const double _metaWidthWithLabel = 106;
  static const double _metaWidthCompact = 106;
  static const double _detailFontSize = 14;
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
    required this.compactView,
    required this.categories,
    required this.category,
    required this.onToggle,
    required this.reorderableIndex,
    required this.priority,
    required this.onPriorityChanged,
    required this.onDueDate,
    required this.onPlanDate,
    required this.onTotalEffortChanged,
    required this.onNextSessionEffortChanged,
    required this.onCategoryChanged,
    required this.onEdit,
    required this.onDelete,
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
      padding: EdgeInsets.only(left: 2, bottom: compactView ? 2 : 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compactView ? 9 : 10,
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
              height: compactView ? 32 : 36,
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
              height: compactView ? 32 : 36,
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
            height: compactView ? 32 : 36,
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
            height: compactView ? 32 : 36,
            width: showLabel ? _metaWidthWithLabel : _metaWidthCompact,
            padding: EdgeInsets.symmetric(horizontal: compactView ? 4 : 6),
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
                        ? (compactView ? 'Med' : 'Medium')
                        : 'Low';
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: compactView ? 6 : 8,
                          height: compactView ? 6 : 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: getPriorityColor(value),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SizedBox(width: compactView ? 2 : 4),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compactView ? 9 : 10,
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
            height: compactView ? 32 : 36,
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

    if (compactView) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < controls.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              controls[i],
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: controls,
    );
  }

  Widget buildCompletionControl({
    required bool showLabel,
    bool useTallCompactStyle = false,
  }) {
    final effectiveProgress = task.subtasks.isEmpty
        ? (task.done ? 1.0 : 0.0)
        : progress.clamp(0.0, 1.0);
    final percent = (effectiveProgress * 100).round();
    final accent = task.done ? Colors.green.shade700 : Colors.blue.shade700;
    final ringSize = compactView ? (useTallCompactStyle ? 50.0 : 26.0) : 28.0;
    final boxHeight = compactView ? (useTallCompactStyle ? 78.0 : 32.0) : 36.0;
    final boxWidth = compactView
        ? (useTallCompactStyle ? 64.0 : _metaWidthCompact)
        : (showLabel ? _metaWidthWithLabel : _metaWidthCompact);

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
              padding: EdgeInsets.symmetric(
                horizontal: compactView && useTallCompactStyle ? 4 : 6,
              ),
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
                        strokeWidth: compactView
                            ? (useTallCompactStyle ? 5.2 : 3.4)
                            : 3.8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: compactView
                              ? (useTallCompactStyle ? 10.5 : 7.5)
                              : 8.5,
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
    final compactConstraints = compactHeader
        ? const BoxConstraints(minWidth: 20, minHeight: 20)
        : const BoxConstraints(minWidth: 24, minHeight: 24);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit, size: iconSize),
          tooltip: 'Edit task',
          visualDensity: compactView ? VisualDensity.compact : null,
          padding: compactView ? EdgeInsets.zero : null,
          constraints: compactView ? compactConstraints : null,
          onPressed: onEdit,
        ),
        IconButton(
          icon: Icon(Icons.delete, size: iconSize),
          tooltip: 'Delete task',
          visualDensity: compactView ? VisualDensity.compact : null,
          padding: compactView ? EdgeInsets.zero : null,
          constraints: compactView ? compactConstraints : null,
          onPressed: onDelete,
        ),
      ],
    );
  }

  Widget buildReorderGrabber({required bool useTallCompactStyle}) {
    return ReorderableDragStartListener(
      index: reorderableIndex,
      child: Tooltip(
        message: 'Drag to reorder',
        child: Container(
          width: useTallCompactStyle ? 24 : 22,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(left: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Center(
            child: Icon(
              Icons.drag_indicator,
              size: useTallCompactStyle ? 18 : 16,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        if (compactView) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildCompletionControl(
                  showLabel: false,
                  useTallCompactStyle: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: buildOverflowScrollableText(
                              task.task,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          buildTrailingActions(compactHeader: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      buildControlWrap(
                        showLabel: false,
                        includeCompletion: false,
                      ),
                    ],
                  ),
                ),
                if (allowReorderDrag)
                  buildReorderGrabber(useTallCompactStyle: true),
              ],
            ),
          );
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          horizontalTitleGap: 8,
          minLeadingWidth: 26,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      Text(
                        task.task,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildControlWrap(
                        showLabel: true,
                        includeCompletion: true,
                      ),
                    ] else ...[
                      Text(
                        task.task,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      buildControlWrap(
                        showLabel: true,
                        includeCompletion: true,
                      ),
                    ],

                    if (task.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 2),
                      Text(
                        "${(progress * 100).round()}%",
                        style: const TextStyle(
                          fontSize: _detailFontSize,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildTrailingActions(),
              if (allowReorderDrag) const SizedBox(width: 4),
              if (allowReorderDrag)
                SizedBox(
                  height: 56,
                  child: buildReorderGrabber(useTallCompactStyle: false),
                ),
            ],
          ),
        );
      },
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
