import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_entry.dart';
import '../models/task.dart';
import 'firebase_sync_service.dart';
import 'one_drive_sync_service.dart';

class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _notesKey = 'notes';
  static const String _noteEntriesKey = 'note_entries';
  static const String _inboxEntriesKey = 'inbox_entries';
  static const String _dailyCheckinsByDateKey = 'daily_checkins_by_date';
  static const String _legacySymptomRatingsByDateKey =
      'symptom_ratings_by_date';
  static const String _symptomRatingsByDateKey = 'symptom_ratings_by_date';
  static const String _categoriesKey = 'categories';
  static const String _starterPromptKey = 'starter_step_prompt';
  static const String _taskSubtaskPromptKey = 'task_subtask_prompt';
  static const String _priorityCardCountKey = 'priority_card_count';
  static const String _outlookLookAheadDaysKey = 'outlook_look_ahead_days';
  static const String _contextTodayOptionsKey = 'context_today_options';
  static const String _otherMedicationOptionsKey = 'other_medication_options';
  static const String _dopamineCrashSymptomOptionsKey =
      'dopamine_crash_symptom_options';
  static const String _dopamineCrashAdditionalSymptomOptionsKey =
      'dopamine_crash_additional_symptom_options';
  static const String _updatedAtKey = 'app_state_updated_at_utc';
  static const String _sourceDeviceKey = 'app_state_source_device';
  static const String _localBackupKey = 'app_state_local_backup';
  static const String _latestBackupAtKey = 'app_state_latest_backup_at_utc';
  static const String _localBackupHistoryKey = 'app_state_local_backup_history';
  static const int _maxBackupSnapshots = 5;

  static bool get isOutlookConfigured => OneDriveSyncService.isConfigured;

  static Future<bool> isOutlookLinked() {
    return OneDriveSyncService.isSignedIn();
  }

  static Future<OneDriveDeviceCodeSession> beginOutlookLink() {
    return OneDriveSyncService.beginDeviceCodeFlow();
  }

  static Future<bool> completeOutlookLink([
    OneDriveDeviceCodeSession? session,
  ]) {
    return OneDriveSyncService.completeDeviceCodeFlow(session);
  }

  static Future<void> unlinkOutlook() {
    return OneDriveSyncService.signOut();
  }

  static Future<bool> syncWithCloudNow() async {
    return _syncDownThenUp();
  }

  static Map<String, dynamic>? choosePreferredStateSnapshot(
    Map<String, dynamic>? localState,
    Map<String, dynamic>? remoteState,
  ) {
    if (localState == null && remoteState == null) {
      return null;
    }
    if (localState == null) {
      return remoteState;
    }
    if (remoteState == null) {
      return localState;
    }

    final localTimestamp = _stateTimestamp(localState);
    final remoteTimestamp = _stateTimestamp(remoteState);

    if (localTimestamp != null && remoteTimestamp != null) {
      final localIsNewer = localTimestamp.isAfter(remoteTimestamp);
      final remoteIsNewer = remoteTimestamp.isAfter(localTimestamp);

      if (localIsNewer) {
        if (_looksLikeFallbackState(localState) &&
            !_looksLikeFallbackState(remoteState) &&
            _stateRichness(remoteState) > _stateRichness(localState)) {
          return remoteState;
        }
        return localState;
      }
      if (remoteIsNewer) {
        if (_looksLikeFallbackState(remoteState) &&
            !_looksLikeFallbackState(localState) &&
            _stateRichness(localState) > _stateRichness(remoteState)) {
          return localState;
        }
        return remoteState;
      }
    }

    final localRichness = _stateRichness(localState);
    final remoteRichness = _stateRichness(remoteState);

    if (remoteRichness > localRichness) {
      return remoteState;
    }
    if (localRichness > remoteRichness) {
      return localState;
    }

    if (remoteTimestamp != null && localTimestamp != null) {
      if (remoteTimestamp.isAtSameMomentAs(localTimestamp)) {
        return _richerByContent(localState, remoteState)
            ? localState
            : remoteState;
      }
    }

    return remoteState;
  }

  static bool _looksLikeFallbackState(Map<String, dynamic> state) {
    final notes = (state['notes'] ?? '').toString().trim();
    final noteEntries = state['note_entries'];
    final inboxEntries = state['inbox_entries'];
    final dailyCheckins = state['daily_checkins_by_date'];
    final categories = state['categories'];

    if (notes.isNotEmpty) {
      return false;
    }
    if (noteEntries is List && noteEntries.isNotEmpty) {
      return false;
    }
    if (inboxEntries is List && inboxEntries.isNotEmpty) {
      return false;
    }
    if (dailyCheckins is Map && dailyCheckins.isNotEmpty) {
      return false;
    }
    if (categories is List && categories.isNotEmpty) {
      return false;
    }

    final tasks = state['tasks'];
    if (tasks is! List) {
      return false;
    }

    final normalizedTasks = tasks.map((entry) {
      if (entry is! Map) {
        return <String, dynamic>{};
      }
      final taskMap = Map<String, dynamic>.from(entry);
      return {
        'task': taskMap['task']?.toString() ?? '',
        'done': taskMap['done'] is bool ? taskMap['done'] as bool : false,
        'expanded': taskMap['expanded'] is bool
            ? taskMap['expanded'] as bool
            : false,
      };
    }).toList();

    if (normalizedTasks.length != 2) {
      return false;
    }

    final taskTexts = normalizedTasks
        .map((entry) => entry['task']?.toString() ?? '')
        .toList();

    return taskTexts.contains('Take medication') &&
        taskTexts.contains('Check calendar');
  }

  static bool _richerByContent(
    Map<String, dynamic> localState,
    Map<String, dynamic> remoteState,
  ) {
    final localRichness = _stateRichness(localState);
    final remoteRichness = _stateRichness(remoteState);

    if (localRichness != remoteRichness) {
      return localRichness > remoteRichness;
    }

    return false;
  }

  static List<Map<String, dynamic>> _normalizeTaskMaps(dynamic tasks) {
    if (tasks is! List) {
      return <Map<String, dynamic>>[];
    }

    return tasks
        .map((entry) {
          if (entry is! Map) {
            return <String, dynamic>{};
          }

          final taskMap = Map<String, dynamic>.from(entry);
          return {
            'task': taskMap['task']?.toString() ?? '',
            'done': taskMap['done'] is bool ? taskMap['done'] as bool : false,
            'expanded': taskMap['expanded'] is bool
                ? taskMap['expanded'] as bool
                : false,
            'priority': taskMap['priority']?.toString() ?? 'medium',
            'dueDate': taskMap['dueDate']?.toString(),
            'category': taskMap['category']?.toString() ?? 'None',
            'aiSubtasks': taskMap['aiSubtasks'] ?? <dynamic>[],
            'subtasks': taskMap['subtasks'] ?? <dynamic>[],
            'starterTinyStep': taskMap['starterTinyStep']?.toString() ?? '',
            'starterSetupChecklist':
                taskMap['starterSetupChecklist']?.toString() ?? '',
            'starterIfStuck': taskMap['starterIfStuck']?.toString() ?? '',
            'snoozedUntilUtc': taskMap['snoozedUntilUtc']?.toString(),
          };
        })
        .where((entry) => (entry['task'] as String? ?? '').trim().isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _normalizeNoteEntries(dynamic entries) {
    if (entries is! List) {
      return <Map<String, dynamic>>[];
    }

    return entries
        .map((entry) {
          if (entry is Map) {
            return Map<String, dynamic>.from(entry);
          }
          return <String, dynamic>{};
        })
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static List<String> _normalizeInboxEntries(dynamic entries) {
    if (entries is! List) {
      return <String>[];
    }

    return entries.map((entry) => entry.toString()).toList();
  }

  static bool _taskExistsIn(
    Map<String, dynamic> candidate,
    List<Map<String, dynamic>> existingTasks,
  ) {
    final candidateKey = (candidate['task'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (candidateKey.isEmpty) {
      return false;
    }

    return existingTasks.any(
      (task) =>
          (task['task'] ?? '').toString().trim().toLowerCase() == candidateKey,
    );
  }

  static bool _noteEntryExistsIn(
    Map<String, dynamic> candidate,
    List<Map<String, dynamic>> existingEntries,
  ) {
    final candidateId = (candidate['id'] ?? '').toString();
    if (candidateId.isNotEmpty) {
      return existingEntries.any(
        (entry) => (entry['id'] ?? '').toString() == candidateId,
      );
    }

    final title = (candidate['title'] ?? '').toString().toLowerCase();
    final content = (candidate['content'] ?? '').toString().toLowerCase();

    return existingEntries.any((entry) {
      final existingTitle = (entry['title'] ?? '').toString().toLowerCase();
      final existingContent = (entry['content'] ?? '').toString().toLowerCase();
      return existingTitle == title && existingContent == content;
    });
  }

  static List<Map<String, dynamic>> _mergeTaskMaps(
    List<Map<String, dynamic>> currentTasks,
    List<Map<String, dynamic>> incomingTasks,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final task in [...currentTasks, ...incomingTasks]) {
      final key = (task['task'] ?? '').toString().trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      merged.add(task);
    }

    return merged;
  }

  static List<Map<String, dynamic>> _mergeNoteEntries(
    List<Map<String, dynamic>> currentEntries,
    List<Map<String, dynamic>> incomingEntries,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final entry in [...currentEntries, ...incomingEntries]) {
      final key = ((entry['id'] ?? '') as String).trim().toLowerCase();
      if (key.isEmpty) {
        final title = (entry['title'] ?? '').toString().trim().toLowerCase();
        final content = (entry['content'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final compositeKey = '$title|$content';
        if (compositeKey.isEmpty || seen.contains(compositeKey)) {
          continue;
        }
        seen.add(compositeKey);
        merged.add(entry);
        continue;
      }

      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      merged.add(entry);
    }

    return merged;
  }

  static List<String> _mergeInboxEntries(
    List<String> currentEntries,
    List<String> incomingEntries,
  ) {
    final merged = <String>[];
    final seen = <String>{};

    for (final entry in [...currentEntries, ...incomingEntries]) {
      final key = entry.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      merged.add(entry);
    }

    return merged;
  }

  static Future<int> getUpcomingOutlookEventCount({
    Duration lookAhead = const Duration(days: 7),
    int maxItems = 10,
  }) async {
    final events = await OneDriveSyncService.fetchUpcomingCalendarEvents(
      lookAhead: lookAhead,
      maxItems: maxItems,
    );
    return events.length;
  }

  static Future<List<OutlookCalendarEvent>> getUpcomingOutlookEvents({
    Duration lookAhead = const Duration(days: 7),
    int maxItems = 10,
  }) {
    return OneDriveSyncService.fetchUpcomingCalendarEvents(
      lookAhead: lookAhead,
      maxItems: maxItems,
    );
  }

  static Future<List<Task>> loadTasks() async {
    await _syncDownThenUp();

    final prefs = await SharedPreferences.getInstance();

    final savedTasks = prefs.getString(_tasksKey);

    if (savedTasks == null) {
      return _defaultTasks();
    }

    final List<dynamic> decoded = jsonDecode(savedTasks);

    return decoded
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _tasksKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
    await _touchStateMetadata(prefs);
    await _createLocalBackupSnapshot(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<List<String>> loadInboxEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_inboxEntriesKey);
    if (saved == null || saved.trim().isEmpty) {
      return <String>[];
    }
    final decoded = jsonDecode(saved) as List<dynamic>;
    return decoded.map((entry) => entry.toString()).toList();
  }

  static Future<void> saveInboxEntries(List<String> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inboxEntriesKey, jsonEncode(entries));
    await _touchStateMetadata(prefs);
    await _createLocalBackupSnapshot(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<Map<String, Map<String, dynamic>>>
  loadDailyCheckinsByDate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getString(_dailyCheckinsByDateKey) ??
        prefs.getString(_legacySymptomRatingsByDateKey);
    if (saved == null || saved.trim().isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    try {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      final parsed = <String, Map<String, dynamic>>{};

      decoded.forEach((dateKey, value) {
        if (value is! Map<String, dynamic>) {
          return;
        }

        final normalized = <String, dynamic>{};
        value.forEach((fieldKey, rawValue) {
          if (rawValue is num || rawValue is String || rawValue is bool) {
            normalized[fieldKey] = rawValue;
            return;
          }
          if (rawValue is List) {
            normalized[fieldKey] = rawValue
                .map((entry) => entry.toString())
                .toList();
          }
        });

        if (normalized.isNotEmpty) {
          parsed[dateKey] = normalized;
        }
      });

      return parsed;
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  static Future<void> saveDailyCheckinsByDate(
    Map<String, Map<String, dynamic>> checkinsByDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(checkinsByDate);
    await prefs.setString(_dailyCheckinsByDateKey, encoded);
    await prefs.setString(_legacySymptomRatingsByDateKey, encoded);
    await _touchStateMetadata(prefs);
    await _createLocalBackupSnapshot(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<Map<String, Map<String, dynamic>>> loadSymptomRatingsByDate() {
    return loadDailyCheckinsByDate();
  }

  static Future<void> saveSymptomRatingsByDate(
    Map<String, Map<String, dynamic>> ratingsByDate,
  ) {
    return saveDailyCheckinsByDate(ratingsByDate);
  }

  static Future<String> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notesKey) ?? '';
  }

  static Future<void> saveNotes(String notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, notes);
    await _touchStateMetadata(prefs);
    await _createLocalBackupSnapshot(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<List<NoteEntry>> loadNoteEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEntries = prefs.getString(_noteEntriesKey);

    if (rawEntries != null && rawEntries.trim().isNotEmpty) {
      final decoded = jsonDecode(rawEntries) as List<dynamic>;
      return decoded
          .map((e) => NoteEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final legacyNotes = prefs.getString(_notesKey) ?? '';
    if (legacyNotes.trim().isEmpty) {
      return <NoteEntry>[];
    }

    final migrated = [
      NoteEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Imported note',
        content: legacyNotes,
        updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    ];
    await saveNoteEntries(migrated);
    return migrated;
  }

  static Future<void> saveNoteEntries(List<NoteEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _noteEntriesKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _notesKey,
      entries.isEmpty ? '' : entries.first.content,
    );
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<List<String>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getString(_categoriesKey);
    if (savedCategories == null) return [];

    final List<dynamic> decoded = jsonDecode(savedCategories);
    return decoded.cast<String>();
  }

  static Future<void> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(categories));
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<String?> loadStarterStepPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_starterPromptKey);
  }

  static Future<void> saveStarterStepPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_starterPromptKey, prompt);
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<String?> loadTaskSubtaskPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_taskSubtaskPromptKey);
  }

  static Future<void> saveTaskSubtaskPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskSubtaskPromptKey, prompt);
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<int?> loadPriorityCardCount() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_priorityCardCountKey);
    if (value == null) {
      return null;
    }
    if (value < 1 || value > 3) {
      return null;
    }
    return value;
  }

  static Future<void> savePriorityCardCount(int count) async {
    final clamped = count.clamp(1, 3).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_priorityCardCountKey, clamped);
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<int?> loadOutlookLookAheadDays() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_outlookLookAheadDaysKey);
    if (value == null) {
      return null;
    }
    if (value < 1 || value > 7) {
      return null;
    }
    return value;
  }

  static Future<void> saveOutlookLookAheadDays(int days) async {
    final clamped = days.clamp(1, 7).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_outlookLookAheadDaysKey, clamped);
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<List<String>?> loadContextTodayOptions() async {
    return _loadStringList(_contextTodayOptionsKey);
  }

  static Future<void> saveContextTodayOptions(List<String> options) async {
    await _saveStringList(_contextTodayOptionsKey, options);
  }

  static Future<List<String>?> loadOtherMedicationOptions() async {
    return _loadStringList(_otherMedicationOptionsKey);
  }

  static Future<void> saveOtherMedicationOptions(List<String> options) async {
    await _saveStringList(_otherMedicationOptionsKey, options);
  }

  static Future<List<String>?> loadDopamineCrashSymptomOptions() async {
    return _loadStringList(_dopamineCrashSymptomOptionsKey);
  }

  static Future<void> saveDopamineCrashSymptomOptions(
    List<String> options,
  ) async {
    await _saveStringList(_dopamineCrashSymptomOptionsKey, options);
  }

  static Future<List<String>?>
  loadDopamineCrashAdditionalSymptomOptions() async {
    return _loadStringList(_dopamineCrashAdditionalSymptomOptionsKey);
  }

  static Future<void> saveDopamineCrashAdditionalSymptomOptions(
    List<String> options,
  ) async {
    await _saveStringList(_dopamineCrashAdditionalSymptomOptionsKey, options);
  }

  static Future<void> _touchStateMetadata(SharedPreferences prefs) async {
    await prefs.setString(
      _updatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await prefs.setString(_sourceDeviceKey, 'adhd_assistant');
    await _createLocalBackupSnapshot(prefs);
  }

  static Future<Map<String, dynamic>?> loadLatestBackupState() async {
    final history = await loadBackupHistory();
    if (history.isEmpty) {
      return null;
    }

    return history.first['state'] as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> loadBackupHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localBackupHistoryKey);
    final localHistory = _decodeBackupHistory(raw);

    final remoteHistory = await FirebaseSyncService.downloadBackupHistory();
    if (remoteHistory.isEmpty && localHistory.isNotEmpty) {
      return localHistory;
    }

    final normalized = _normalizeBackupHistory([
      ...localHistory,
      ...remoteHistory,
    ]);
    if (normalized.isNotEmpty) {
      await prefs.setString(_localBackupHistoryKey, jsonEncode(normalized));
    }
    return normalized;
  }

  static Future<Map<String, dynamic>> getBackupRecoveryPreview() async {
    final backup = await loadLatestBackupState();
    if (backup == null) {
      return _emptyBackupPreview();
    }

    return getBackupRecoveryPreviewForBackupEntry({'state': backup});
  }

  static Future<Map<String, dynamic>> getBackupRecoveryPreviewForBackupEntry(
    Map<String, dynamic> backupEntry,
  ) async {
    final backup = backupEntry['state'] as Map<String, dynamic>?;
    if (backup == null) {
      return _emptyBackupPreview();
    }

    final prefs = await SharedPreferences.getInstance();
    final currentState = await _buildStateMapFromPrefs(prefs);

    final currentTasks = _normalizeTaskMaps(currentState['tasks']);
    final backupTasks = _normalizeTaskMaps(backup['tasks']);
    final missingTasks = backupTasks
        .where((task) => !_taskExistsIn(task, currentTasks))
        .toList();

    final currentNoteEntries = _normalizeNoteEntries(
      currentState['note_entries'],
    );
    final backupNoteEntries = _normalizeNoteEntries(backup['note_entries']);
    final missingNoteEntries = backupNoteEntries
        .where((entry) => !_noteEntryExistsIn(entry, currentNoteEntries))
        .toList();

    final currentInboxEntries = _normalizeInboxEntries(
      currentState['inbox_entries'],
    );
    final backupInboxEntries = _normalizeInboxEntries(backup['inbox_entries']);
    final missingInboxEntries = backupInboxEntries
        .where((entry) => !currentInboxEntries.contains(entry))
        .toList();

    return {
      'hasBackup': true,
      'backupTimestamp': backupEntry['timestamp']?.toString(),
      'missingTasks': missingTasks,
      'missingNoteEntries': missingNoteEntries,
      'missingInboxEntries': missingInboxEntries,
    };
  }

  static Map<String, dynamic> _emptyBackupPreview() {
    return {
      'hasBackup': false,
      'backupTimestamp': null,
      'missingTasks': <Map<String, dynamic>>[],
      'missingNoteEntries': <Map<String, dynamic>>[],
      'missingInboxEntries': <String>[],
    };
  }

  static Future<void> restoreLatestBackupState() async {
    final backup = await loadLatestBackupState();
    if (backup == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await _applyStateMapToPrefs(prefs, backup);
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<void> restoreBackupEntryState(
    Map<String, dynamic> backupEntry,
  ) async {
    final backup = backupEntry['state'] as Map<String, dynamic>?;
    if (backup == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await _applyStateMapToPrefs(prefs, backup);
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<void> mergeMissingBackupEntries({
    required List<Map<String, dynamic>> selectedTasks,
    required List<Map<String, dynamic>> selectedNoteEntries,
    required List<String> selectedInboxEntries,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentState = await _buildStateMapFromPrefs(prefs);

    final currentTasks = _normalizeTaskMaps(currentState['tasks']);
    final mergedTasks = _mergeTaskMaps(currentTasks, selectedTasks);

    final currentNoteEntries = _normalizeNoteEntries(
      currentState['note_entries'],
    );
    final mergedNoteEntries = _mergeNoteEntries(
      currentNoteEntries,
      selectedNoteEntries,
    );

    final currentInboxEntries = _normalizeInboxEntries(
      currentState['inbox_entries'],
    );
    final mergedInboxEntries = _mergeInboxEntries(
      currentInboxEntries,
      selectedInboxEntries,
    );

    await prefs.setString(_tasksKey, jsonEncode(mergedTasks));
    await prefs.setString(_noteEntriesKey, jsonEncode(mergedNoteEntries));
    await prefs.setString(_inboxEntriesKey, jsonEncode(mergedInboxEntries));
    await _touchStateMetadata(prefs);
    await _createLocalBackupSnapshot(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static Future<void> _createLocalBackupSnapshot(
    SharedPreferences prefs,
  ) async {
    final state = await _buildStateMapFromPrefs(prefs);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final newEntry = {'timestamp': timestamp, 'state': state};

    final history = _normalizeBackupHistory([
      newEntry,
      ...await loadBackupHistory(),
    ]);

    await prefs.setString(_localBackupKey, jsonEncode(state));
    await prefs.setString(_localBackupHistoryKey, jsonEncode(history));
    await prefs.setString(_latestBackupAtKey, timestamp);
    await FirebaseSyncService.uploadBackupHistory(history);
  }

  static List<Map<String, dynamic>> _decodeBackupHistory(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static List<Map<String, dynamic>> _normalizeBackupHistory(
    List<Map<String, dynamic>> history,
  ) {
    final normalized = history
        .whereType<Map<String, dynamic>>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) => entry['state'] is Map)
        .toList();

    normalized.sort((a, b) {
      final aTimestamp = (a['timestamp'] ?? '').toString();
      final bTimestamp = (b['timestamp'] ?? '').toString();
      return bTimestamp.compareTo(aTimestamp);
    });

    final unique = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final entry in normalized) {
      final signature = entry['timestamp']?.toString() ?? '';
      if (signature.isEmpty || seen.contains(signature)) {
        continue;
      }
      seen.add(signature);
      unique.add(entry);
    }

    if (unique.length > _maxBackupSnapshots) {
      unique.removeRange(_maxBackupSnapshots, unique.length);
    }

    return unique;
  }

  static List<Task> _defaultTasks() {
    return [];
  }

  static Future<bool> _syncDownThenUp() async {
    if (!FirebaseSyncService.isConfigured) {
      return false;
    }

    final firebaseReady = await FirebaseSyncService.isSignedIn();
    if (!firebaseReady) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final localState = await _buildStateMapFromPrefs(prefs);
      final remoteState = await FirebaseSyncService.downloadState();
      final remoteBackupHistory =
          await FirebaseSyncService.downloadBackupHistory();

      if (remoteBackupHistory.isNotEmpty) {
        final localHistory = _decodeBackupHistory(
          prefs.getString(_localBackupHistoryKey),
        );
        final mergedHistory = _normalizeBackupHistory([
          ...localHistory,
          ...remoteBackupHistory,
        ]);
        if (mergedHistory.isNotEmpty) {
          await prefs.setString(
            _localBackupHistoryKey,
            jsonEncode(mergedHistory),
          );
        }
      }

      if (remoteState == null) {
        return await FirebaseSyncService.uploadState(localState);
      }

      final preferredState = choosePreferredStateSnapshot(
        localState,
        remoteState,
      );
      if (preferredState == null) {
        return true;
      }

      final prefersRemote = identical(preferredState, remoteState);
      if (prefersRemote) {
        await _applyStateMapToPrefs(prefs, remoteState);
        return true;
      }

      return await FirebaseSyncService.uploadState(localState);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _pushCurrentStateToCloudIfAvailable() async {
    if (!FirebaseSyncService.isConfigured) {
      return;
    }

    final firebaseReady = await FirebaseSyncService.isSignedIn();
    if (!firebaseReady) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final state = await _buildStateMapFromPrefs(prefs);
      await FirebaseSyncService.uploadState(state);
    } catch (_) {
      // Keep local storage reliable even when cloud sync fails.
    }
  }

  static Future<Map<String, dynamic>> _buildStateMapFromPrefs(
    SharedPreferences prefs,
  ) async {
    final tasksRaw = prefs.getString(_tasksKey);
    final notes = prefs.getString(_notesKey) ?? '';
    final noteEntriesRaw = prefs.getString(_noteEntriesKey);
    final inboxEntriesRaw = prefs.getString(_inboxEntriesKey);
    final dailyCheckinsByDateRaw =
        prefs.getString(_dailyCheckinsByDateKey) ??
        prefs.getString(_legacySymptomRatingsByDateKey);
    final categoriesRaw = prefs.getString(_categoriesKey);
    final starterPrompt = prefs.getString(_starterPromptKey) ?? '';
    final taskSubtaskPrompt = prefs.getString(_taskSubtaskPromptKey) ?? '';
    final priorityCardCount = prefs.getInt(_priorityCardCountKey) ?? 3;
    final outlookLookAheadDays = prefs.getInt(_outlookLookAheadDaysKey) ?? 1;
    final contextTodayOptionsRaw = prefs.getString(_contextTodayOptionsKey);
    final otherMedicationOptionsRaw = prefs.getString(
      _otherMedicationOptionsKey,
    );
    final dopamineCrashSymptomOptionsRaw = prefs.getString(
      _dopamineCrashSymptomOptionsKey,
    );
    final dopamineCrashAdditionalSymptomOptionsRaw = prefs.getString(
      _dopamineCrashAdditionalSymptomOptionsKey,
    );
    final updatedAt =
        prefs.getString(_updatedAtKey) ??
        DateTime.now().toUtc().toIso8601String();
    final sourceDevice = prefs.getString(_sourceDeviceKey) ?? 'adhd_assistant';

    final List<dynamic> tasksJson = tasksRaw == null
        ? _defaultTasks().map((task) => task.toJson()).toList()
        : (jsonDecode(tasksRaw) as List<dynamic>);
    final List<dynamic> categoriesJson = categoriesRaw == null
        ? <String>[]
        : (jsonDecode(categoriesRaw) as List<dynamic>);
    final List<dynamic> noteEntriesJson = noteEntriesRaw == null
        ? <dynamic>[]
        : (jsonDecode(noteEntriesRaw) as List<dynamic>);
    final List<dynamic> inboxEntriesJson = inboxEntriesRaw == null
        ? <dynamic>[]
        : (jsonDecode(inboxEntriesRaw) as List<dynamic>);
    final Map<String, dynamic> dailyCheckinsByDateJson =
        dailyCheckinsByDateRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(dailyCheckinsByDateRaw) as Map<String, dynamic>,
          );

    return {
      'tasks': tasksJson,
      'notes': notes,
      'note_entries': noteEntriesJson,
      'inbox_entries': inboxEntriesJson,
      'daily_checkins_by_date': dailyCheckinsByDateJson,
      'symptom_ratings_by_date': dailyCheckinsByDateJson,
      'categories': categoriesJson,
      'starter_step_prompt': starterPrompt,
      'task_subtask_prompt': taskSubtaskPrompt,
      'priority_card_count': priorityCardCount,
      'outlook_look_ahead_days': outlookLookAheadDays,
      'context_today_options': _decodeStringList(contextTodayOptionsRaw),
      'other_medication_options': _decodeStringList(otherMedicationOptionsRaw),
      'dopamine_crash_symptom_options': _decodeStringList(
        dopamineCrashSymptomOptionsRaw,
      ),
      'dopamine_crash_additional_symptom_options': _decodeStringList(
        dopamineCrashAdditionalSymptomOptionsRaw,
      ),
      'updated_at_utc': updatedAt,
      'source_device': sourceDevice,
    };
  }

  static Future<void> _applyStateMapToPrefs(
    SharedPreferences prefs,
    Map<String, dynamic> state,
  ) async {
    final tasks = state['tasks'] as List<dynamic>? ?? <dynamic>[];
    final notes = (state['notes'] ?? '').toString();
    final noteEntries = _noteEntriesFromState(state, notes);
    final inboxEntries =
        state['inbox_entries'] as List<dynamic>? ?? <dynamic>[];
    final dailyCheckinsByDate =
        state['daily_checkins_by_date'] as Map<String, dynamic>? ??
        state['symptom_ratings_by_date'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final categories = state['categories'] as List<dynamic>? ?? <dynamic>[];
    final starterPrompt = (state['starter_step_prompt'] ?? '').toString();
    final taskSubtaskPrompt = (state['task_subtask_prompt'] ?? '').toString();
    final priorityCardCountRaw = (state['priority_card_count'] ?? 3) as num;
    final priorityCardCount = priorityCardCountRaw.toInt().clamp(1, 3);
    final outlookLookAheadDaysRaw =
        (state['outlook_look_ahead_days'] ?? 1) as num;
    final outlookLookAheadDays = outlookLookAheadDaysRaw.toInt().clamp(1, 7);
    final updatedAt =
        (state['updated_at_utc'] ?? DateTime.now().toUtc().toIso8601String())
            .toString();
    final sourceDevice = (state['source_device'] ?? 'adhd_assistant')
        .toString();

    await prefs.setString(_tasksKey, jsonEncode(tasks));
    await prefs.setString(_notesKey, notes);
    await prefs.setString(_noteEntriesKey, jsonEncode(noteEntries));
    await prefs.setString(_inboxEntriesKey, jsonEncode(inboxEntries));
    await prefs.setString(
      _dailyCheckinsByDateKey,
      jsonEncode(dailyCheckinsByDate),
    );
    await prefs.setString(
      _symptomRatingsByDateKey,
      jsonEncode(dailyCheckinsByDate),
    );
    await prefs.setString(_categoriesKey, jsonEncode(categories));
    await prefs.setString(_starterPromptKey, starterPrompt);
    await prefs.setString(_taskSubtaskPromptKey, taskSubtaskPrompt);
    await prefs.setInt(_priorityCardCountKey, priorityCardCount);
    await prefs.setInt(_outlookLookAheadDaysKey, outlookLookAheadDays);
    await prefs.setString(
      _contextTodayOptionsKey,
      jsonEncode(_normalizeStringList(state['context_today_options'])),
    );
    await prefs.setString(
      _otherMedicationOptionsKey,
      jsonEncode(_normalizeStringList(state['other_medication_options'])),
    );
    await prefs.setString(
      _dopamineCrashSymptomOptionsKey,
      jsonEncode(_normalizeStringList(state['dopamine_crash_symptom_options'])),
    );
    await prefs.setString(
      _dopamineCrashAdditionalSymptomOptionsKey,
      jsonEncode(
        _normalizeStringList(
          state['dopamine_crash_additional_symptom_options'],
        ),
      ),
    );
    await prefs.setString(_updatedAtKey, updatedAt);
    await prefs.setString(_sourceDeviceKey, sourceDevice);
  }

  static List<String> _normalizeStringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList();
    }
    return <String>[];
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((entry) => entry.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<List<String>?> _loadStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((entry) => entry.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveStringList(String key, List<String> options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(options));
    await _touchStateMetadata(prefs);
    unawaited(_pushCurrentStateToCloudIfAvailable());
  }

  static List<dynamic> _noteEntriesFromState(
    Map<String, dynamic> state,
    String notes,
  ) {
    final entries = state['note_entries'];
    if (entries is List<dynamic>) {
      return entries;
    }
    if (notes.trim().isEmpty) {
      return <dynamic>[];
    }
    return [
      {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': 'Imported note',
        'content': notes,
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      },
    ];
  }

  static bool _isRemoteNewer(
    Map<String, dynamic> candidate,
    Map<String, dynamic> baseline,
  ) {
    final candidateRaw = (candidate['updated_at_utc'] ?? '').toString();
    final baselineRaw = (baseline['updated_at_utc'] ?? '').toString();

    final candidateTime = DateTime.tryParse(candidateRaw);
    final baselineTime = DateTime.tryParse(baselineRaw);

    if (candidateTime == null && baselineTime == null) {
      return false;
    }
    if (candidateTime == null) {
      return false;
    }
    if (baselineTime == null) {
      return true;
    }

    return candidateTime.isAfter(baselineTime);
  }

  static DateTime? _stateTimestamp(Map<String, dynamic> state) {
    final raw = (state['updated_at_utc'] ?? '').toString();
    return DateTime.tryParse(raw);
  }

  static int _stateRichness(Map<String, dynamic> state) {
    int richness = 0;

    final tasks = state['tasks'];
    if (tasks is List && tasks.isNotEmpty) {
      richness += tasks.length;
    }

    final notes = (state['notes'] ?? '').toString();
    if (notes.trim().isNotEmpty) {
      richness += 2;
    }

    final noteEntries = state['note_entries'];
    if (noteEntries is List && noteEntries.isNotEmpty) {
      richness += noteEntries.length;
    }

    final inboxEntries = state['inbox_entries'];
    if (inboxEntries is List && inboxEntries.isNotEmpty) {
      richness += inboxEntries.length;
    }

    final dailyCheckins = state['daily_checkins_by_date'];
    if (dailyCheckins is Map && dailyCheckins.isNotEmpty) {
      richness += 3;
    }

    final categories = state['categories'];
    if (categories is List && categories.isNotEmpty) {
      richness += categories.length;
    }

    return richness;
  }
}
