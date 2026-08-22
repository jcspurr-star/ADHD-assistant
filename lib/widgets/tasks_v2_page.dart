import 'package:flutter/material.dart';

import '../models/task.dart';

class TasksV2Page extends StatefulWidget {
  const TasksV2Page({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onSaveTasks,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onSetArchived,
    required this.onToggleSubtask,
    required this.onAddSubtask,
    required this.onEditSubtask,
    required this.onDeleteSubtask,
  });

  final List<Task> tasks;
  final Future<void> Function(String title) onAddTask;
  final Future<void> Function() onSaveTasks;
  final Future<void> Function(int index, bool value) onToggleTask;
  final Future<void> Function(int index) onEditTask;
  final Future<void> Function(int index) onDeleteTask;
  final Future<void> Function(int index, bool archived) onSetArchived;
  final Future<void> Function(int taskIndex, int subtaskIndex, bool value)
  onToggleSubtask;
  final Future<void> Function(int taskIndex, String text) onAddSubtask;
  final Future<void> Function(int taskIndex, int subtaskIndex) onEditSubtask;
  final Future<void> Function(int taskIndex, int subtaskIndex) onDeleteSubtask;

  @override
  State<TasksV2Page> createState() => _TasksV2PageState();
}

class _TasksV2PageState extends State<TasksV2Page> {
  final _searchController = TextEditingController();
  final _addController = TextEditingController();
  final _scrollController = ScrollController();
  bool _kanban = false;
  bool _completedExpanded = false;
  bool _archivedExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Task> get _filteredTasks {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.tasks;
    return widget.tasks.where((task) {
      return task.task.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          task.notes.toLowerCase().contains(query) ||
          task.tags.any((tag) => tag.toLowerCase().contains(query)) ||
          task.subtasks.any(
            (subtask) => subtask.text.toLowerCase().contains(query),
          );
    }).toList();
  }

  int _indexOf(Task task) =>
      widget.tasks.indexWhere((item) => item.id == task.id);

  Future<void> _addTask() async {
    final title = _addController.text.trim();
    if (title.isEmpty) return;
    await widget.onAddTask(title);
    if (mounted) _addController.clear();
  }

  String _dueLabel(Task task) {
    if (task.dueDate == null || task.dueDate!.trim().isEmpty) return '';
    final due = DateTime.tryParse(task.dueDate!);
    if (due == null) return 'Due ${task.dueDate}';
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay == day) return 'Due today';
    return 'Due ${dueDay.month}/${dueDay.day}';
  }

  Color _priorityColor(Task task) {
    return switch (task.priority) {
      'high' => Colors.red.shade700,
      'medium' => Colors.orange.shade700,
      'low' => Colors.green.shade700,
      _ => Colors.blueGrey.shade500,
    };
  }

  String _priorityLabel(Task task) {
    final value = task.priority.trim();
    if (value.isEmpty) return 'Medium';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  bool _isWaiting(Task task) {
    final snoozed = task.snoozedUntilUtc;
    if (snoozed == null || snoozed.isEmpty) return false;
    final until = DateTime.tryParse(snoozed);
    return until != null && until.isAfter(DateTime.now());
  }

  bool _completedToday(Task task) {
    final completedAt = task.completedAtUtc == null
        ? null
        : DateTime.tryParse(task.completedAtUtc!);
    if (completedAt == null) return true;
    final local = completedAt.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Future<void> _openDetails(Task task) async {
    final index = _indexOf(task);
    if (index < 0 || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskV2Details(
        task: task,
        onSave: widget.onSaveTasks,
        onToggleTask: (value) => widget.onToggleTask(index, value),
        onEditTask: () => widget.onEditTask(index),
        onDeleteTask: () => widget.onDeleteTask(index),
        onSetArchived: (value) => widget.onSetArchived(index, value),
        onToggleSubtask: (subtaskIndex, value) =>
            widget.onToggleSubtask(index, subtaskIndex, value),
        onAddSubtask: (text) => widget.onAddSubtask(index, text),
        onEditSubtask: (subtaskIndex) =>
            widget.onEditSubtask(index, subtaskIndex),
        onDeleteSubtask: (subtaskIndex) =>
            widget.onDeleteSubtask(index, subtaskIndex),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _taskTile(Task task) {
    final index = _indexOf(task);
    final due = _dueLabel(task);
    final subtaskLabel =
        '${task.subtasks.length} subtask${task.subtasks.length == 1 ? '' : 's'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _openDetails(task),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: _priorityColor(task)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.task,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _priorityLabel(task),
                        subtaskLabel,
                        if (due.isNotEmpty) due,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: task.done,
                onChanged: index < 0
                    ? null
                    : (value) => widget.onToggleTask(index, value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Task> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final collapsed = title == 'Completed today'
        ? !_completedExpanded
        : title == 'Archived'
        ? !_archivedExpanded
        : false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: title == 'Completed today'
              ? () => setState(() => _completedExpanded = !_completedExpanded)
              : title == 'Archived'
              ? () => setState(() => _archivedExpanded = !_archivedExpanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                if (title == 'Completed today' || title == 'Archived')
                  Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          for (final task in tasks) _taskTile(task),
      ],
    );
  }

  Widget _kanbanColumn(String title, List<Task> tasks, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$title (${tasks.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final task in tasks) _taskTile(task),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;
    final archived = tasks.where((task) => task.archived).toList();
    final completed = tasks
        .where((task) => task.done && !task.archived && _completedToday(task))
        .toList();
    final active = tasks.where((task) => !task.done && !task.archived).toList();
    final inbox = active
        .where(
          (task) => task.category.trim().isEmpty || task.category == 'None',
        )
        .toList();
    final activeWithoutInbox = active
        .where((task) => !inbox.contains(task))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks V2'),
        actions: [
          IconButton(
            tooltip: _kanban ? 'List view' : 'Kanban view',
            icon: Icon(
              _kanban ? Icons.view_list_outlined : Icons.view_kanban_outlined,
            ),
            onPressed: () => setState(() => _kanban = !_kanban),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search tasks, descriptions, or subtasks',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    onSubmitted: (_) => _addTask(),
                    decoration: const InputDecoration(
                      hintText: 'Add a task',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _kanban
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 12),
                      _kanbanColumn('Inbox', inbox, Icons.inbox_outlined),
                      _kanbanColumn(
                        'Active',
                        activeWithoutInbox
                            .where((task) => !_isWaiting(task))
                            .toList(),
                        Icons.radio_button_unchecked,
                      ),
                      _kanbanColumn(
                        'Waiting',
                        active.where(_isWaiting).toList(),
                        Icons.schedule_outlined,
                      ),
                      _kanbanColumn(
                        'Completed',
                        completed,
                        Icons.check_circle_outline,
                      ),
                      const SizedBox(width: 4),
                    ],
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    children: [
                      _section('Inbox', inbox),
                      _section('Active tasks', activeWithoutInbox),
                      _section('Completed today', completed),
                      _section('Archived', archived),
                      if (tasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No matching tasks.')),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskV2Details extends StatefulWidget {
  const _TaskV2Details({
    required this.task,
    required this.onSave,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onSetArchived,
    required this.onToggleSubtask,
    required this.onAddSubtask,
    required this.onEditSubtask,
    required this.onDeleteSubtask,
  });

  final Task task;
  final Future<void> Function() onSave;
  final Future<void> Function(bool value) onToggleTask;
  final Future<void> Function() onEditTask;
  final Future<void> Function() onDeleteTask;
  final Future<void> Function(bool value) onSetArchived;
  final Future<void> Function(int index, bool value) onToggleSubtask;
  final Future<void> Function(String text) onAddSubtask;
  final Future<void> Function(int index) onEditSubtask;
  final Future<void> Function(int index) onDeleteSubtask;

  @override
  State<_TaskV2Details> createState() => _TaskV2DetailsState();
}

class _TaskV2DetailsState extends State<_TaskV2Details> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _notesController = TextEditingController(text: widget.task.notes);
    _tagsController = TextEditingController(text: widget.task.tags.join(', '));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _saveMetadata() async {
    widget.task.description = _descriptionController.text.trim();
    widget.task.notes = _notesController.text.trim();
    widget.task.tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    await widget.onSave();
  }

  Future<void> _addSubtask() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add subtask'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
          decoration: const InputDecoration(hintText: 'Subtask'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.trim().isNotEmpty) {
      await widget.onAddSubtask(text.trim());
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.task,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Separate tags with commas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Completed',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Switch(
                  value: widget.task.done,
                  onChanged: (value) async {
                    await widget.onToggleTask(value);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Archived',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Switch(
                  value: widget.task.archived,
                  onChanged: (value) async {
                    await widget.onSetArchived(value);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subtasks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Add subtask',
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (widget.task.subtasks.isEmpty) const Text('No subtasks yet.'),
            for (var index = 0; index < widget.task.subtasks.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: widget.task.subtasks[index].done,
                  onChanged: (value) =>
                      widget.onToggleSubtask(index, value ?? false),
                ),
                title: Text(
                  widget.task.subtasks[index].text,
                  style: TextStyle(
                    decoration: widget.task.subtasks[index].done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') widget.onEditSubtask(index);
                    if (value == 'delete') widget.onDeleteSubtask(index);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await _saveMetadata();
                    await widget.onEditTask();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit title'),
                ),
                FilledButton.icon(
                  onPressed: _saveMetadata,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                TextButton.icon(
                  onPressed: widget.onDeleteTask,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
