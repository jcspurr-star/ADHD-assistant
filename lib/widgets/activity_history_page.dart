import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';
import '../services/activity_tracking_service.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({
    super.key,
    required this.initialLogs,
    required this.onLogsChanged,
  });

  final List<ActivityLogEntry> initialLogs;
  final Future<void> Function(List<ActivityLogEntry>) onLogsChanged;

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  late List<ActivityLogEntry> logs;
  ActivityLogEntry? lastDeleted;

  @override
  void initState() {
    super.initState();
    logs = List<ActivityLogEntry>.from(widget.initialLogs);
  }

  String _pillarLabel(ActivityPillar pillar) => switch (pillar) {
    ActivityPillar.walking => 'Walking',
    ActivityPillar.standing => 'Standing',
    ActivityPillar.gym => 'Gym',
    ActivityPillar.zwift => 'Zwift',
    ActivityPillar.mobility => 'Mobility',
  };

  String _sourceLabel(ActivitySource source) => switch (source) {
    ActivitySource.recommendation => 'Recommendation',
    ActivitySource.manual => 'Manual',
    ActivitySource.plannerTimeline => 'Planner timeline',
  };

  String _formatDay(DateTime day) {
    final today = ActivityTrackingService.dateOnly(DateTime.now());
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${day.day}/${day.month}/${day.year}';
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _saveLogs(List<ActivityLogEntry> next) async {
    setState(() => logs = next);
    await widget.onLogsChanged(next);
  }

  Future<void> _delete(ActivityLogEntry entry) async {
    lastDeleted = entry;
    await _saveLogs(ActivityTrackingService.withoutId(logs, entry.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Activity removed.'),
        action: SnackBarAction(label: 'Undo', onPressed: _undoDelete),
      ),
    );
  }

  Future<void> _undoDelete() async {
    final deleted = lastDeleted;
    if (deleted == null) return;
    lastDeleted = null;
    final next = [...logs, deleted]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    await _saveLogs(next);
  }

  Future<void> _addManualActivity() async {
    var pillar = ActivityPillar.walking;
    final minutesController = TextEditingController(text: '15');
    final saved = await showDialog<ActivityLogEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ActivityPillar>(
                initialValue: pillar,
                decoration: const InputDecoration(labelText: 'Pillar'),
                items: ActivityPillar.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_pillarLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => pillar = value);
                },
              ),
              if (pillar == ActivityPillar.walking ||
                  pillar == ActivityPillar.standing)
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(minutesController.text);
                if ((pillar == ActivityPillar.walking ||
                        pillar == ActivityPillar.standing) &&
                    (minutes == null || minutes <= 0)) {
                  return;
                }
                final entry = ActivityTrackingService.createManualEntry(
                  pillar: pillar,
                  minutes: minutes,
                );
                if (entry != null) Navigator.pop(dialogContext, entry);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != null) await _saveLogs([...logs, saved]);
  }

  @override
  Widget build(BuildContext context) {
    final totals = ActivityTrackingService.calculateWeeklyTotals(logs);
    final grouped = ActivityTrackingService.groupByDay(logs);
    final progress = ActivityTrackingService.generateInsights(totals);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity history'),
        actions: [
          IconButton(
            tooltip: 'Log activity',
            onPressed: _addManualActivity,
            icon: const Icon(Icons.add_task),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'This Week',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildSummary(totals),
          const SizedBox(height: 12),
          for (final insight in progress)
            ListTile(
              dense: true,
              leading: const Icon(Icons.insights_outlined),
              title: Text(insight),
            ),
          const SizedBox(height: 8),
          if (grouped.isEmpty)
            const Center(child: Text('No activity logged yet.'))
          else
            for (final group in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _formatDay(group.key),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final entry in group.value) _buildEntry(entry),
            ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualActivity,
        icon: const Icon(Icons.add),
        label: const Text('Log activity'),
      ),
    );
  }

  Widget _buildSummary(WeeklyActivityTotals totals) {
    final values = <String>[
      'Walking\n${totals.walkingMinutes} mins',
      'Standing\n${totals.standingMinutes} min',
      'Gym\n${totals.gymSessions} sessions',
      'Zwift\n${totals.zwiftSessions} sessions',
      'Mobility\n${totals.mobilitySessions} sessions',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(value),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEntry(ActivityLogEntry entry) {
    final duration = entry.minutes == null ? '' : '${entry.minutes} mins';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(_pillarLabel(entry.pillar)),
        subtitle: Text(
          [
            if (duration.isNotEmpty) duration,
            _formatTime(entry.completedAt),
            'Source: ${_sourceLabel(entry.source)}',
          ].join(' • '),
        ),
        trailing: IconButton(
          tooltip: 'Delete activity',
          onPressed: () => _delete(entry),
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}
