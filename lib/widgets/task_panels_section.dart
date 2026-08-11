import 'package:flutter/material.dart';

import '../models/task.dart';
import 'subtask_tile.dart';

class TaskPanelsSection extends StatelessWidget {
  const TaskPanelsSection({
    super.key,
    required this.task,
    required this.selectedTab,
    required this.isNarrow,
    required this.isGenerating,
    required this.defaultStarterStepCount,
    required this.subtaskController,
    required this.formatDueDate,
    required this.onSelectTab,
    required this.onReorderSubtasks,
    required this.onToggleSubtask,
    required this.onSetSubtaskDate,
    required this.onEditSubtask,
    required this.onDeleteSubtask,
    required this.onAddSubtask,
    required this.onGenerateTaskSubtasks,
    required this.onConfirmDeleteStarterSteps,
    required this.onRegenerateStarterSteps,
    required this.onGenerateStarterScript,
    required this.onEditStarterScript,
  });

  final Task task;
  final int selectedTab;
  final bool isNarrow;
  final bool isGenerating;
  final int defaultStarterStepCount;
  final TextEditingController subtaskController;
  final String Function(String? value) formatDueDate;

  final Future<void> Function(int tabIndex) onSelectTab;
  final Future<void> Function(int oldIndex, int newIndex) onReorderSubtasks;
  final Future<void> Function(int subtaskIndex, bool? value) onToggleSubtask;
  final Future<void> Function(int subtaskIndex) onSetSubtaskDate;
  final Future<void> Function(int subtaskIndex) onEditSubtask;
  final void Function(int subtaskIndex) onDeleteSubtask;
  final Future<void> Function() onAddSubtask;
  final VoidCallback onGenerateTaskSubtasks;
  final VoidCallback onConfirmDeleteStarterSteps;
  final VoidCallback onRegenerateStarterSteps;
  final Future<void> Function() onGenerateStarterScript;
  final Future<void> Function() onEditStarterScript;

  Widget _buildTaskPanel({
    required String title,
    required Color color,
    required Widget headerAction,
    required Widget body,
    bool showHeader = true,
  }) {
    return Card(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  headerAction,
                ],
              ),
            if (showHeader) const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTabButton({required String label, required int tabIndex}) {
    final isSelected = selectedTab == tabIndex;

    return OutlinedButton(
      onPressed: () async {
        await onSelectTab(tabIndex);
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: isSelected ? Colors.blue.shade600 : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.grey.shade800,
        side: BorderSide(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtasksBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.subtasks.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: task.subtasks.length,
            onReorderItem: (oldIndex, newIndex) async {
              await onReorderSubtasks(oldIndex, newIndex);
            },
            itemBuilder: (context, subIndex) {
              return SubtaskTile(
                key: ValueKey(
                  '${task.task}_${task.subtasks[subIndex].text}_$subIndex',
                ),
                index: subIndex + 1,
                reorderableIndex: subIndex,
                subtask: task.subtasks[subIndex],
                plannedDateText: formatDueDate(task.subtasks[subIndex].doDate),
                onChanged: (value) async {
                  await onToggleSubtask(subIndex, value);
                },
                onDate: () async {
                  await onSetSubtaskDate(subIndex);
                },
                onEdit: () async {
                  await onEditSubtask(subIndex);
                },
                onDelete: () {
                  onDeleteSubtask(subIndex);
                },
              );
            },
          ),
        const SizedBox(height: 10),
        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.5,
                child: TextField(
                  controller: subtaskController,
                  style: const TextStyle(fontSize: 10),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async {
                    await onAddSubtask();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Add a subtask…',
                    hintStyle: TextStyle(fontSize: 10),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    await onAddSubtask();
                  },
                  child: const Text('Add', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          )
        else
          LayoutBuilder(
            builder: (context, panelConstraints) {
              return Row(
                children: [
                  SizedBox(
                    width: panelConstraints.maxWidth * 0.5,
                    child: TextField(
                      controller: subtaskController,
                      style: const TextStyle(fontSize: 10),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) async {
                        await onAddSubtask();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Add a subtask…',
                        hintStyle: TextStyle(fontSize: 10),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await onAddSubtask();
                    },
                    child: const Text('Add', style: TextStyle(fontSize: 10)),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isGenerating ? null : onGenerateTaskSubtasks,
            icon: Icon(
              Icons.psychology_alt_outlined,
              color: isGenerating ? Colors.grey : Colors.blue,
              size: 18,
            ),
            label: const Text('Auto generate', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );

    final starterStepsBody = task.aiSubtasks.isEmpty
        ? const Text(
            'ADHD this will generate automatically when you open this tab.',
            style: TextStyle(color: Colors.grey),
          )
        : Column(
            children: List.generate(task.aiSubtasks.length, (aiIndex) {
              final aiSubtask = task.aiSubtasks[aiIndex];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade200,
                  child: Text(
                    '${aiIndex + 1}',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                title: Text(aiSubtask.text),
              );
            }),
          );

    Widget starterLine({required String label, required String value}) {
      final displayValue = value.trim().isEmpty ? 'Not set yet' : value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 13,
                color: value.trim().isEmpty
                    ? Colors.grey.shade500
                    : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    final starterScriptBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        starterLine(label: 'First tiny step', value: task.starterTinyStep),
        starterLine(
          label: 'Setup checklist',
          value: task.starterSetupChecklist,
        ),
        starterLine(label: 'If stuck, do this', value: task.starterIfStuck),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isGenerating
                  ? null
                  : () async {
                      await onGenerateStarterScript();
                    },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate starter script'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await onEditStarterScript();
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Edit starter script'),
            ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTaskPanel(
          title: selectedTab == 0
              ? 'Subtasks'
              : selectedTab == 1
              ? 'ADHD this'
              : 'Starter script',
          color: selectedTab == 1 ? Colors.blue.shade50 : Colors.grey.shade100,
          headerAction: const SizedBox.shrink(),
          showHeader: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildDetailTabButton(label: 'Subtasks', tabIndex: 0),
                  const SizedBox(width: 6),
                  _buildDetailTabButton(label: 'ADHD this', tabIndex: 1),
                  const SizedBox(width: 6),
                  _buildDetailTabButton(label: 'Starter script', tabIndex: 2),
                  const Spacer(),
                  if (selectedTab == 1 && task.aiSubtasks.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      tooltip: 'Delete ADHD this',
                      onPressed: onConfirmDeleteStarterSteps,
                    ),
                  if (selectedTab == 1)
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: isGenerating ? Colors.grey : Colors.blue,
                      ),
                      tooltip: 'Regenerate ADHD this',
                      onPressed: isGenerating ? null : onRegenerateStarterSteps,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (selectedTab == 0)
                subtasksBody
              else if (selectedTab == 1)
                starterStepsBody
              else
                starterScriptBody,
            ],
          ),
        ),
      ],
    );
  }
}
