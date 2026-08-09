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
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onToggleExpanded;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String dueDateText;
  static const double _metaWidthWithLabel = 96;
  static const double _metaWidthCompact = 89;
  static const double _compactLeadingControlsWidth = 66;
  static const double _detailFontSize = 14;

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
    required this.onCategoryChanged,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDelete,
    required this.progress,
    required this.dueDateText,
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

  Widget buildDueDateControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onDueDate,
          child: Tooltip(
            message: dueDateText.isEmpty ? 'Set due date' : 'Change due date',
            child: Container(
              height: 36,
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

  Widget buildCategoryControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
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
      ],
    );
  }

  Widget buildPriorityControl({required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
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
                return const ['high', 'medium', 'low'].map((value) {
                  return Row(
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
                      Text(
                        value == 'high'
                            ? 'High'
                            : value == 'medium'
                            ? 'Medium'
                            : 'Low',
                        style: TextStyle(
                          fontSize: 10,
                          color: getPriorityColor(value),
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
                  child: _PriorityOption(color: Colors.orange, label: 'Medium'),
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
      ],
    );
  }

  Widget buildMetadataStack({
    required bool showLabel,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        buildDueDateControl(showLabel: showLabel),
        const SizedBox(height: 8),
        buildCategoryControl(showLabel: showLabel),
        const SizedBox(height: 8),
        buildPriorityControl(showLabel: showLabel),
      ],
    );
  }

  Widget buildCompactMetadataRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDueDateControl(showLabel: false),
        const SizedBox(width: 2),
        buildCategoryControl(showLabel: false),
        const SizedBox(width: 2),
        buildPriorityControl(showLabel: false),
      ],
    );
  }

  Widget buildCompletionControl() {
    return Tooltip(
      message: task.done ? 'Mark incomplete' : 'Mark completed',
      child: SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: task.done,
          onChanged: onToggle,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        ),
      ),
    );
  }

  Widget buildExpandControl() {
    return IconButton(
      icon: Icon(task.expanded ? Icons.expand_less : Icons.expand_more),
      tooltip: task.expanded ? 'Collapse details' : 'Expand details',
      visualDensity: compactView ? VisualDensity.compact : null,
      padding: compactView ? EdgeInsets.zero : null,
      constraints: compactView
          ? const BoxConstraints(minWidth: 28, minHeight: 28)
          : null,
      onPressed: onToggleExpanded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: compactView ? 4 : 8),
          horizontalTitleGap: compactView ? 10 : 8,
          minLeadingWidth: compactView ? 0 : 26,
          minVerticalPadding: compactView ? 4 : null,
          leading: compactView
              ? SizedBox(
                  width: _compactLeadingControlsWidth,
                  child: Row(
                    children: [
                      buildExpandControl(),
                      const SizedBox(width: 2),
                      buildCompletionControl(),
                    ],
                  ),
                )
              : null,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    compactView
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: buildOverflowScrollableText(
                                  task.task,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: buildCompactMetadataRow(),
                                ),
                              ),
                            ],
                          )
                        : isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.task,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  buildExpandControl(),
                                  buildCompletionControl(),
                                  buildDueDateControl(showLabel: true),
                                  buildCategoryControl(showLabel: true),
                                  buildPriorityControl(showLabel: true),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.task,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  buildExpandControl(),
                                  const SizedBox(width: 6),
                                  buildCompletionControl(),
                                  const SizedBox(width: 6),
                                  buildDueDateControl(showLabel: true),
                                  const SizedBox(width: 6),
                                  buildCategoryControl(showLabel: true),
                                  const SizedBox(width: 6),
                                  buildPriorityControl(showLabel: true),
                                ],
                              ),
                            ],
                          ),

                    if (!compactView && task.subtasks.isNotEmpty) ...[
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
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit task',
                visualDensity: compactView ? VisualDensity.compact : null,
                padding: compactView ? EdgeInsets.zero : null,
                constraints: compactView
                    ? const BoxConstraints(minWidth: 28, minHeight: 28)
                    : null,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete task',
                visualDensity: compactView ? VisualDensity.compact : null,
                padding: compactView ? EdgeInsets.zero : null,
                constraints: compactView
                    ? const BoxConstraints(minWidth: 28, minHeight: 28)
                    : null,
                onPressed: onDelete,
              ),
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: reorderableIndex,
                child: Tooltip(
                  message: 'Drag to reorder',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
