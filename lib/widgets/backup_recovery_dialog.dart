import 'package:flutter/material.dart';

class BackupRecoveryDialog extends StatefulWidget {
  const BackupRecoveryDialog({
    super.key,
    required this.history,
    required this.backupPreviews,
    required this.onRestore,
    required this.onMerge,
  });

  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> backupPreviews;
  final Future<void> Function(Map<String, dynamic> backupEntry) onRestore;
  final Future<void> Function(
    List<Map<String, dynamic>> selectedTasks,
    List<Map<String, dynamic>> selectedNoteEntries,
    List<String> selectedInboxEntries,
  )
  onMerge;

  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> history,
    required List<Map<String, dynamic>> backupPreviews,
    required Future<void> Function(Map<String, dynamic> backupEntry) onRestore,
    required Future<void> Function(
      List<Map<String, dynamic>> selectedTasks,
      List<Map<String, dynamic>> selectedNoteEntries,
      List<String> selectedInboxEntries,
    )
    onMerge,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BackupRecoveryDialog(
          history: history,
          backupPreviews: backupPreviews,
          onRestore: onRestore,
          onMerge: onMerge,
        );
      },
    );
  }

  @override
  State<BackupRecoveryDialog> createState() => _BackupRecoveryDialogState();
}

class _BackupRecoveryDialogState extends State<BackupRecoveryDialog> {
  static const String _recentBackupType = 'recent';
  static const String _dailyBackupType = 'daily';

  String selectedBackupType = _recentBackupType;
  int selectedBackupIndex = 0;
  final Set<int> selectedTaskIndexes = <int>{};
  final Set<int> selectedNoteEntryIndexes = <int>{};
  final Set<int> selectedInboxEntryIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    if (_filteredHistory(_recentBackupType).isEmpty &&
        _filteredHistory(_dailyBackupType).isNotEmpty) {
      selectedBackupType = _dailyBackupType;
    }
  }

  List<int> _filteredHistory(String backupType) {
    return widget.history
        .asMap()
        .entries
        .where(
          (entry) =>
              _normalizeBackupType(entry.value['backup_type']) == backupType,
        )
        .map((entry) => entry.key)
        .toList();
  }

  String _normalizeBackupType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();
    if (raw == _dailyBackupType) {
      return _dailyBackupType;
    }
    return _recentBackupType;
  }

  String _backupTypeLabel(String backupType) {
    return backupType == _dailyBackupType
        ? 'Daily backups (30 days)'
        : 'Recent backups (12 snapshots)';
  }

  String _formatBackupLabel(String? rawTimestamp, int index) {
    if (rawTimestamp == null || rawTimestamp.isEmpty) {
      return 'Backup ${index + 1}';
    }

    final parsed = DateTime.tryParse(rawTimestamp)?.toLocal();
    if (parsed == null) {
      return 'Backup ${index + 1} • $rawTimestamp';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final backupDay = DateTime(parsed.year, parsed.month, parsed.day);
    final dayDiff = today.difference(backupDay).inDays;

    final dateLabel = switch (dayDiff) {
      0 => 'Today',
      1 => 'Yesterday',
      _ =>
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}',
    };

    final timeLabel =
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';

    return 'Backup ${index + 1} • $dateLabel at $timeLabel';
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndices = _filteredHistory(selectedBackupType);
    final effectiveSelectedIndex = filteredIndices.isEmpty
        ? -1
        : selectedBackupIndex.clamp(0, filteredIndices.length - 1);
    final selectedHistoryIndex = effectiveSelectedIndex == -1
        ? -1
        : filteredIndices[effectiveSelectedIndex];
    final currentPreview = selectedHistoryIndex == -1
        ? {
            'hasBackup': false,
            'backupTimestamp': null,
            'missingTasks': const <Map<String, dynamic>>[],
            'missingNoteEntries': const <Map<String, dynamic>>[],
            'missingInboxEntries': const <String>[],
          }
        : widget.backupPreviews[selectedHistoryIndex];
    final hasBackup = currentPreview['hasBackup'] == true;
    final backupTimestamp = currentPreview['backupTimestamp']?.toString();
    final missingTasks = List<Map<String, dynamic>>.from(
      currentPreview['missingTasks'] ?? const <Map<String, dynamic>>[],
    );
    final missingNoteEntries = List<Map<String, dynamic>>.from(
      currentPreview['missingNoteEntries'] ?? const <Map<String, dynamic>>[],
    );
    final missingInboxEntries = List<String>.from(
      currentPreview['missingInboxEntries'] ?? const <String>[],
    );

    return AlertDialog(
      title: const Text('Recover backup items'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<String>(
                initialValue: selectedBackupType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Backup list',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: _recentBackupType,
                    child: Text(
                      '${_backupTypeLabel(_recentBackupType)} (${_filteredHistory(_recentBackupType).length})',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: _dailyBackupType,
                    child: Text(
                      '${_backupTypeLabel(_dailyBackupType)} (${_filteredHistory(_dailyBackupType).length})',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedBackupType = value;
                    selectedBackupIndex = 0;
                    selectedTaskIndexes.clear();
                    selectedNoteEntryIndexes.clear();
                    selectedInboxEntryIndexes.clear();
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<int>(
                initialValue: effectiveSelectedIndex == -1
                    ? null
                    : effectiveSelectedIndex,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Backup version',
                  border: OutlineInputBorder(),
                ),
                items: filteredIndices.asMap().entries.map((entry) {
                  final index = entry.key;
                  final historyEntry = widget.history[entry.value];
                  final timestamp = historyEntry['timestamp']?.toString();
                  final label = _formatBackupLabel(timestamp, index);
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedBackupIndex = value;
                    selectedTaskIndexes.clear();
                    selectedNoteEntryIndexes.clear();
                    selectedInboxEntryIndexes.clear();
                  });
                },
              ),
            ),
            if (filteredIndices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No ${_backupTypeLabel(selectedBackupType).toLowerCase()} available yet.',
                ),
              ),
            if (backupTimestamp != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Backup created: ${_formatBackupLabel(backupTimestamp, effectiveSelectedIndex == -1 ? 0 : effectiveSelectedIndex).replaceFirst(RegExp(r'^Backup \d+ • '), '')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasBackup)
                      const Text(
                        'This backup does not contain recoverable state.',
                      ),
                    if (missingTasks.isNotEmpty) ...[
                      const Text(
                        'Missing tasks',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...missingTasks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final task = entry.value;
                        final label = (task['task'] ?? '').toString();
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(label.isEmpty ? 'Unnamed task' : label),
                          value: selectedTaskIndexes.contains(index),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedTaskIndexes.add(index);
                              } else {
                                selectedTaskIndexes.remove(index);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 10),
                    ],
                    if (missingNoteEntries.isNotEmpty) ...[
                      const Text(
                        'Missing notes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...missingNoteEntries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final note = entry.value;
                        final title = (note['title'] ?? '').toString();
                        final content = (note['content'] ?? '').toString();
                        final label = title.isEmpty ? content : title;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(label.isEmpty ? 'Untitled note' : label),
                          subtitle: content.isEmpty
                              ? null
                              : Text(
                                  content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          value: selectedNoteEntryIndexes.contains(index),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedNoteEntryIndexes.add(index);
                              } else {
                                selectedNoteEntryIndexes.remove(index);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 10),
                    ],
                    if (missingInboxEntries.isNotEmpty) ...[
                      const Text(
                        'Missing inbox items',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...missingInboxEntries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final value = entry.value;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(value),
                          value: selectedInboxEntryIndexes.contains(index),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedInboxEntryIndexes.add(index);
                              } else {
                                selectedInboxEntryIndexes.remove(index);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (selectedHistoryIndex == -1) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context);
            await widget.onRestore(widget.history[selectedHistoryIndex]);
          },
          child: const Text('Restore selected backup'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final selectedTasks = missingTasks
                .asMap()
                .entries
                .where((entry) => selectedTaskIndexes.contains(entry.key))
                .map((entry) => entry.value)
                .toList();
            final selectedNoteEntries = missingNoteEntries
                .asMap()
                .entries
                .where((entry) => selectedNoteEntryIndexes.contains(entry.key))
                .map((entry) => entry.value)
                .toList();
            final selectedInboxEntries = missingInboxEntries
                .asMap()
                .entries
                .where((entry) => selectedInboxEntryIndexes.contains(entry.key))
                .map((entry) => entry.value)
                .toList();

            await widget.onMerge(
              selectedTasks,
              selectedNoteEntries,
              selectedInboxEntries,
            );
          },
          child: const Text('Merge selected'),
        ),
      ],
    );
  }
}
