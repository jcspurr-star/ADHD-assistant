import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'models/note_entry.dart';
import 'models/task.dart';
import 'services/storage_service.dart';
import 'services/gemini_service.dart';
import 'services/recommendation_service.dart';
import 'services/one_drive_sync_service.dart';
import 'services/firebase_sync_service.dart';
import 'dialogs/step_count_dialog.dart';
import 'dialogs/edit_task_dialog.dart';
import 'dialogs/edit_subtask_dialog.dart';
import 'settings_page.dart';
import 'widgets/subtask_tile.dart';
import 'widgets/task_tile.dart';
import 'widgets/backup_recovery_dialog.dart';
import 'widgets/countdown_view.dart';
import 'widgets/home_header.dart';
import 'widgets/insights_view.dart';
import 'widgets/main_content_view.dart';
import 'widgets/main_section_tabs.dart';
import 'widgets/notes_view.dart';
import 'widgets/task_list_view.dart';
import 'widgets/tasks_overview_section.dart';

const double kPageHorizontalPadding = 16;
const double kWidePriorityCardWidth = 202;
const double kWidePriorityCardsSpacingTotal = 12;
const double kPriorityCardWidthReduction = 2;
const double kWideContentWidth =
    (kWidePriorityCardWidth * 3) + kWidePriorityCardsSpacingTotal + 16;
const double kDesktopMinWindowWidth =
    kWideContentWidth + (kPageHorizontalPadding * 2) + 20;
const double kDesktopDefaultWindowHeight = 900;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseSyncService.initializeIfAvailable();

  final isDesktop =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (isDesktop) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      minimumSize: Size(kDesktopMinWindowWidth, 680),
      size: Size(kDesktopMinWindowWidth, kDesktopDefaultWindowHeight),
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ADHDApp());
}

class NoScrollbarScrollBehavior extends MaterialScrollBehavior {
  const NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class ADHDApp extends StatelessWidget {
  const ADHDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'James ADHD Assistant',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NoScrollbarScrollBehavior(),
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const NoScrollbarScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const ADHDHomePage(),
    );
  }
}

enum FirebaseSyncBadgeState { checking, connected, failing, disabled }

enum TaskListSortMode { manual, dueDate, priority }

class ADHDHomePage extends StatefulWidget {
  const ADHDHomePage({super.key});

  @override
  State<ADHDHomePage> createState() => _ADHDHomePageState();
}

class _ADHDHomePageState extends State<ADHDHomePage> {
  static const Map<String, String> symptomTrackerLabels = {
    'focus': 'Focus drift',
    'restlessness': 'Restlessness',
    'impulsivity': 'Impulsivity',
    'overwhelm': 'Overwhelm',
    'emotionalRegulation': 'Emotional regulation',
  };
  List<String> dopamineCrashSymptomOptions = [
    'Tired',
    'Dizzy',
    'Sweaty',
    'Nauseous',
    'Irritable',
    'Headache',
    'Brain fog',
    'Low mood',
    'Anxious',
    'Shaky',
    'Cravings',
    'Poor focus',
  ];
  List<String> dopamineCrashAdditionalSymptomOptions = [
    'Jaw tension',
    'Light sensitivity',
    'Sound sensitivity',
    'Fast heartbeat',
    'Dry mouth',
    'Appetite drop',
    'Racing thoughts',
    'Trouble sleeping',
    'Muscle tension',
    'Need to isolate',
    'Emotional swings',
    'Sensory overload',
  ];
  List<String> dailyContextOptions = [
    'Home',
    'WFH',
    'WFO',
    'Out and about',
    'Holiday',
    'Sick',
    'Bad sleep',
    'Good sleep',
    'Social day',
    'Exercise day',
    'Travel day',
    'Low stress',
    'Mid stress',
    'High stress',
    'Meetings',
  ];
  List<String> otherMedicationOptions = [
    'Sertraline',
    'Atorvastatin',
    'Antihistamine',
    'Cod Liver Oil',
    'Pro-biotic',
    'Asthma',
    'Ibuprofen',
    'Paracetamol',
  ];
  final TextEditingController taskController = TextEditingController();
  final TextEditingController inboxCaptureController = TextEditingController();
  final TextEditingController noteTitleController = TextEditingController();
  final TextEditingController noteContentController = TextEditingController();
  final List<TextEditingController> subtaskControllers = [];
  final Map<Task, int> taskDetailTabByTask = {};
  final ScrollController taskListScrollController = ScrollController();
  final ScrollController taskTabsScrollController = ScrollController();
  final Map<int, GlobalKey> taskCardKeys = {};

  List<Task> tasks = [];
  List<String> inboxEntries = [];
  List<NoteEntry> noteEntries = [];
  Map<String, Map<String, dynamic>> dailyCheckinsByDate = {};
  String? selectedNoteId;
  List<String> categories = ['None'];
  String starterStepPrompt = GeminiService.defaultStarterStepPromptTemplate;
  String taskSubtaskPrompt = GeminiService.defaultSubtaskPromptTemplate;
  String selectedTaskCategory = 'All tasks';
  static const int defaultStarterStepCount = 3;
  static const List<int> focusTimerPresets = [5, 10, 25, 50];

  bool isGenerating = false;
  bool compactView = true;
  TaskListSortMode selectedTaskSortMode = TaskListSortMode.manual;
  int selectedMainSectionIndex = 0;
  int? pendingTaskScrollIndex;
  int priorityCardCount = 3;
  int outlookLookAheadDays = 1;
  int selectedFocusTimerMinutes = 25;
  int selectedFocusTimerSeconds = 0;
  Duration remainingFocusTime = const Duration(minutes: 25);
  Timer? focusTimer;
  Timer? timerCompletionCueReset;
  Timer? timerCompletionBeepLoop;
  Timer? notesSaveDebounce;
  Future<List<OutlookCalendarEvent>>? upcomingOutlookEventsFuture;
  bool _syncingNoteControllers = false;
  bool timerCompletionCueActive = false;
  FirebaseSyncBadgeState firebaseSyncBadgeState =
      FirebaseSyncBadgeState.checking;
  String firebaseSyncStatusText = 'Cloud...';

  @override
  void initState() {
    super.initState();
    upcomingOutlookEventsFuture = _loadUpcomingOutlookEvents();
    unawaited(_refreshFirebaseSyncStatus());
    unawaited(_maybeCompleteOutlookAuthFromCurrentUrl());
    unawaited(loadTasks().catchError((_) {}));
  }

  Future<void> _refreshFirebaseSyncStatus({
    bool triggerSyncAttempt = false,
    bool showSnackBar = false,
  }) async {
    if (!FirebaseSyncService.isConfigured) {
      if (!mounted) return;
      setState(() {
        firebaseSyncBadgeState = FirebaseSyncBadgeState.disabled;
        firebaseSyncStatusText = 'Cloud off';
      });
      return;
    }

    if (mounted) {
      setState(() {
        firebaseSyncBadgeState = FirebaseSyncBadgeState.checking;
        firebaseSyncStatusText = 'Cloud...';
      });
    }

    if (triggerSyncAttempt) {
      await StorageService.syncWithCloudNow();
    }

    final signedIn = await FirebaseSyncService.isSignedIn();
    final connected =
        signedIn && await FirebaseSyncService.canReachCloudState();

    if (!mounted) return;

    setState(() {
      firebaseSyncBadgeState = connected
          ? FirebaseSyncBadgeState.connected
          : FirebaseSyncBadgeState.failing;
      firebaseSyncStatusText = connected ? 'Cloud OK' : 'Cloud error';
    });

    if (showSnackBar) {
      final failureDetails = FirebaseSyncService.lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Firebase sync is connected.'
                : failureDetails == null
                ? 'Firebase sync failed. Check Auth and Firestore setup.'
                : 'Firebase sync failed: $failureDetails',
          ),
        ),
      );
    }
  }

  Future<void> handleCloudSyncStatusTap() async {
    await _refreshFirebaseSyncStatus(
      triggerSyncAttempt: true,
      showSnackBar: true,
    );
    await loadTasks();
  }

  Future<void> openBackupRecoveryDialog() async {
    final history = await StorageService.loadBackupHistory();
    if (!mounted) return;

    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backup snapshot is available yet.')),
      );
      return;
    }

    final backupPreviews = <Map<String, dynamic>>[];
    for (final entry in history) {
      backupPreviews.add(
        await StorageService.getBackupRecoveryPreviewForBackupEntry(entry),
      );
    }

    if (!mounted) return;

    await BackupRecoveryDialog.show(
      context: context,
      history: history,
      backupPreviews: backupPreviews,
      onRestore: (backupEntry) async {
        await StorageService.restoreBackupEntryState(backupEntry);
        if (!mounted) return;
        await loadTasks();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored the selected backup.')),
        );
      },
      onMerge:
          (selectedTasks, selectedNoteEntries, selectedInboxEntries) async {
            await StorageService.mergeMissingBackupEntries(
              selectedTasks: selectedTasks,
              selectedNoteEntries: selectedNoteEntries,
              selectedInboxEntries: selectedInboxEntries,
            );
            if (!mounted) return;
            await loadTasks();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Merged the selected backup items.'),
              ),
            );
          },
    );
  }

  Future<List<OutlookCalendarEvent>> _loadUpcomingOutlookEvents() {
    return StorageService.getUpcomingOutlookEvents(
      lookAhead: Duration(days: outlookLookAheadDays),
      maxItems: (outlookLookAheadDays * 10).clamp(10, 50).toInt(),
    ).catchError((error) {
      if (error is Exception &&
          error.toString().contains('No Microsoft sign-in session found')) {
        return <OutlookCalendarEvent>[];
      }
      return <OutlookCalendarEvent>[];
    });
  }

  void _refreshUpcomingOutlookEvents() {
    setState(() {
      upcomingOutlookEventsFuture = _loadUpcomingOutlookEvents();
    });
  }

  int getDefaultPriorityCardCountForPlatform() {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return isMobile ? 1 : 3;
  }

  Future<void> loadTasks() async {
    try {
      final loadedTasks = await StorageService.loadTasks();
      final loadedInboxEntries = await StorageService.loadInboxEntries();
      final loadedNoteEntries = await StorageService.loadNoteEntries();
      final loadedDailyCheckinsByDate =
          await StorageService.loadDailyCheckinsByDate();
      final loadedCategories = await StorageService.loadCategories();
      final loadedStarterStepPrompt =
          await StorageService.loadStarterStepPrompt();
      final loadedTaskSubtaskPrompt =
          await StorageService.loadTaskSubtaskPrompt();
      final loadedContextTodayOptions =
          await StorageService.loadContextTodayOptions();
      final loadedOtherMedicationOptions =
          await StorageService.loadOtherMedicationOptions();
      final loadedDopamineCrashSymptomOptions =
          await StorageService.loadDopamineCrashSymptomOptions();
      final loadedDopamineCrashAdditionalSymptomOptions =
          await StorageService.loadDopamineCrashAdditionalSymptomOptions();
      final loadedPriorityCardCount =
          await StorageService.loadPriorityCardCount();
      final loadedOutlookLookAheadDays =
          await StorageService.loadOutlookLookAheadDays();
      List<String> resolveOptionList(
        List<String>? loaded,
        List<String> fallback,
      ) {
        final cleaned = (loaded ?? const <String>[])
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
        return List<String>.from(fallback);
      }

      final resolvedContextTodayOptions = resolveOptionList(
        loadedContextTodayOptions,
        dailyContextOptions,
      );
      final resolvedOtherMedicationOptions = resolveOptionList(
        loadedOtherMedicationOptions,
        otherMedicationOptions,
      );
      final resolvedDopamineCrashSymptomOptions = resolveOptionList(
        loadedDopamineCrashSymptomOptions,
        dopamineCrashSymptomOptions,
      );
      final resolvedDopamineCrashAdditionalSymptomOptions = resolveOptionList(
        loadedDopamineCrashAdditionalSymptomOptions,
        dopamineCrashAdditionalSymptomOptions,
      );
      final resolvedPriorityCardCount =
          loadedPriorityCardCount ?? getDefaultPriorityCardCountForPlatform();
      final resolvedOutlookLookAheadDays = loadedOutlookLookAheadDays ?? 1;
      if (!mounted) return;
      setState(() {
        categories = loadedCategories.isEmpty ? ['None'] : loadedCategories;
        dailyContextOptions = resolvedContextTodayOptions;
        otherMedicationOptions = resolvedOtherMedicationOptions;
        dopamineCrashSymptomOptions = resolvedDopamineCrashSymptomOptions;
        dopamineCrashAdditionalSymptomOptions =
            resolvedDopamineCrashAdditionalSymptomOptions;
        starterStepPrompt = loadedStarterStepPrompt?.trim().isNotEmpty == true
            ? loadedStarterStepPrompt!
            : GeminiService.defaultStarterStepPromptTemplate;
        taskSubtaskPrompt = loadedTaskSubtaskPrompt?.trim().isNotEmpty == true
            ? loadedTaskSubtaskPrompt!
            : GeminiService.defaultSubtaskPromptTemplate;
        priorityCardCount = resolvedPriorityCardCount;
        outlookLookAheadDays = resolvedOutlookLookAheadDays;
        tasks = loadedTasks;
        inboxEntries = loadedInboxEntries;
        noteEntries = loadedNoteEntries;
        dailyCheckinsByDate = loadedDailyCheckinsByDate;
        selectedNoteId = null;
        normalizeTaskCategories();
        ensureSelectedTaskCategoryIsValid();
        syncSubtaskControllers();
      });
      syncNoteControllers();

      _refreshUpcomingOutlookEvents();
      unawaited(_refreshFirebaseSyncStatus());
    } catch (error, stackTrace) {
      debugPrint('Failed to load tasks: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> saveTasks() async {
    await StorageService.saveTasks(tasks);
  }

  Future<void> saveCategories() async {
    await StorageService.saveCategories(categories);
  }

  Future<void> saveStarterStepPrompt() async {
    await StorageService.saveStarterStepPrompt(starterStepPrompt);
  }

  Future<void> saveTaskSubtaskPrompt() async {
    await StorageService.saveTaskSubtaskPrompt(taskSubtaskPrompt);
  }

  Future<void> saveTrackerOptions() async {
    await StorageService.saveContextTodayOptions(dailyContextOptions);
    await StorageService.saveOtherMedicationOptions(otherMedicationOptions);
    await StorageService.saveDopamineCrashSymptomOptions(
      dopamineCrashSymptomOptions,
    );
    await StorageService.saveDopamineCrashAdditionalSymptomOptions(
      dopamineCrashAdditionalSymptomOptions,
    );
  }

  void saveNotesDebounced() {
    notesSaveDebounce?.cancel();
    notesSaveDebounce = Timer(const Duration(milliseconds: 450), () {
      StorageService.saveNoteEntries(noteEntries);
    });
  }

  Future<void> saveInboxEntries() async {
    await StorageService.saveInboxEntries(inboxEntries);
  }

  Future<void> saveDailyCheckinsByDate() async {
    await StorageService.saveDailyCheckinsByDate(dailyCheckinsByDate);
  }

  NoteEntry? get selectedNote {
    if (selectedNoteId == null) {
      return null;
    }
    for (final entry in noteEntries) {
      if (entry.id == selectedNoteId) {
        return entry;
      }
    }
    return null;
  }

  String displayNoteTitle(NoteEntry entry) {
    final direct = entry.title.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final firstLine = entry.content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return firstLine.isEmpty ? 'Untitled note' : firstLine;
  }

  String notePreview(NoteEntry entry) {
    final compact = entry.content.trim().replaceAll('\n', ' ');
    if (compact.isEmpty) {
      return 'No content yet';
    }
    return compact.length <= 80 ? compact : '${compact.substring(0, 80)}...';
  }

  Future<void> persistNoteEntries() async {
    await StorageService.saveNoteEntries(noteEntries);
  }

  void syncNoteControllers() {
    final note = selectedNote;
    _syncingNoteControllers = true;
    noteTitleController.text = note?.title ?? '';
    noteContentController.text = note?.content ?? '';
    _syncingNoteControllers = false;
  }

  Future<void> openNoteEntryDialog({NoteEntry? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(
      text: existing?.content ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'New note' : 'Edit note'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentController,
                  minLines: 4,
                  maxLines: 8,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Write your note...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, {
                  'title': titleController.text,
                  'content': contentController.text,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    contentController.dispose();

    if (result == null) {
      return;
    }

    final title = (result['title'] ?? '').trim();
    final content = result['content'] ?? '';
    if (title.isEmpty && content.trim().isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    setState(() {
      if (existing == null) {
        final newEntry = NoteEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          content: content,
          updatedAtUtc: now,
        );
        noteEntries.insert(0, newEntry);
        selectedNoteId = newEntry.id;
      } else {
        existing.title = title;
        existing.content = content;
        existing.updatedAtUtc = now;
        selectedNoteId = existing.id;
      }
    });

    await persistNoteEntries();
  }

  Future<void> addNoteEntry() async {
    await openNoteEntryDialog();
  }

  Future<void> deleteNoteEntryById(String noteId) async {
    final target = noteEntries.where((entry) => entry.id == noteId).firstOrNull;
    if (target == null) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete note'),
              content: const Text('Delete this note permanently?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      noteEntries.removeWhere((entry) => entry.id == noteId);
      if (selectedNoteId == noteId) {
        selectedNoteId = null;
      }
    });
    syncNoteControllers();
    await persistNoteEntries();
  }

  Future<void> deleteSelectedNote() async {
    final current = selectedNote;
    if (current == null) {
      return;
    }
    await deleteNoteEntryById(current.id);
  }

  void selectNoteEntry(String noteId) {
    setState(() {
      selectedNoteId = noteId;
    });
    syncNoteControllers();
  }

  void onSelectedNoteChanged() {
    if (_syncingNoteControllers) {
      return;
    }

    final note = selectedNote;
    if (note == null) {
      return;
    }

    setState(() {
      note.title = noteTitleController.text;
      note.content = noteContentController.text;
      note.updatedAtUtc = DateTime.now().toUtc().toIso8601String();
    });

    saveNotesDebounced();
  }

  void normalizeTaskCategories() {
    final allowed = categories.isEmpty ? ['None'] : categories;
    for (final task in tasks) {
      if (!allowed.contains(task.category)) {
        task.category = allowed.first;
      }
    }
  }

  List<String> getTaskTabs() {
    final categoryTabs = categories
        .where((category) => category != 'None')
        .toList();
    return ['All tasks', ...categoryTabs];
  }

  void ensureSelectedTaskCategoryIsValid() {
    if (!getTaskTabs().contains(selectedTaskCategory)) {
      selectedTaskCategory = 'All tasks';
    }
  }

  List<int> getVisibleTaskIndices() {
    final visibleIndices = selectedTaskCategory == 'All tasks'
        ? List<int>.generate(tasks.length, (index) => index)
        : tasks
              .asMap()
              .entries
              .where((entry) => entry.value.category == selectedTaskCategory)
              .map((entry) => entry.key)
              .toList();

    switch (selectedTaskSortMode) {
      case TaskListSortMode.manual:
        return visibleIndices;
      case TaskListSortMode.dueDate:
        visibleIndices.sort(compareTaskByDueDate);
        return visibleIndices;
      case TaskListSortMode.priority:
        visibleIndices.sort(compareTaskByPriority);
        return visibleIndices;
    }
  }

  int compareTaskByDueDate(int a, int b) {
    final aDue = DateTime.tryParse(tasks[a].dueDate ?? '');
    final bDue = DateTime.tryParse(tasks[b].dueDate ?? '');

    if (aDue == null && bDue == null) {
      return a.compareTo(b);
    }
    if (aDue == null) {
      return 1;
    }
    if (bDue == null) {
      return -1;
    }

    final dueCompare = aDue.compareTo(bDue);
    if (dueCompare != 0) {
      return dueCompare;
    }

    return compareTaskByPriority(a, b);
  }

  int compareTaskByPriority(int a, int b) {
    final priorityA = RecommendationService.getPriorityScore(tasks[a].priority);
    final priorityB = RecommendationService.getPriorityScore(tasks[b].priority);
    final priorityCompare = priorityB.compareTo(priorityA);
    if (priorityCompare != 0) {
      return priorityCompare;
    }

    final aDue = DateTime.tryParse(tasks[a].dueDate ?? '');
    final bDue = DateTime.tryParse(tasks[b].dueDate ?? '');
    if (aDue != null && bDue != null) {
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) {
        return dueCompare;
      }
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }

    return a.compareTo(b);
  }

  String getTaskSortLabel() {
    switch (selectedTaskSortMode) {
      case TaskListSortMode.manual:
        return 'Standard order';
      case TaskListSortMode.dueDate:
        return 'Due date';
      case TaskListSortMode.priority:
        return 'Priority';
    }
  }

  void reorderVisibleTasks(
    int oldIndex,
    int newIndex,
    List<int> visibleIndices,
  ) {
    final visibleTasks = visibleIndices.map((index) => tasks[index]).toList();
    final visibleControllers = visibleIndices
        .map((index) => subtaskControllers[index])
        .toList();

    final task = visibleTasks.removeAt(oldIndex);
    final controller = visibleControllers.removeAt(oldIndex);

    visibleTasks.insert(newIndex, task);
    visibleControllers.insert(newIndex, controller);

    for (var i = 0; i < visibleIndices.length; i++) {
      final globalIndex = visibleIndices[i];
      tasks[globalIndex] = visibleTasks[i];
      subtaskControllers[globalIndex] = visibleControllers[i];
    }
  }

  GlobalKey taskCardKeyFor(int taskIndex) {
    return taskCardKeys.putIfAbsent(taskIndex, () => GlobalKey());
  }

  Future<void> openTaskFromPriorityCard(Task task) async {
    final taskIndex = tasks.indexOf(task);
    if (taskIndex < 0) {
      return;
    }

    setState(() {
      selectedMainSectionIndex = 2;
      selectedTaskCategory = 'All tasks';
      compactView = false;
      tasks[taskIndex].expanded = true;
      pendingTaskScrollIndex = taskIndex;
    });

    await saveTasks();

    await WidgetsBinding.instance.endOfFrame;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = pendingTaskScrollIndex;
      if (index == null) {
        return;
      }

      final context = taskCardKeys[index]?.currentContext;
      if (context == null) {
        return;
      }

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );

      if (mounted && pendingTaskScrollIndex == index) {
        setState(() {
          pendingTaskScrollIndex = null;
        });
      }
    });
  }

  Future<void> openSettings() async {
    final updatedSettings = await Navigator.push<SettingsPageResult>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          categories: categories,
          starterStepPrompt: starterStepPrompt,
          taskSubtaskPrompt: taskSubtaskPrompt,
          contextTodayOptions: dailyContextOptions,
          otherMedicationOptions: otherMedicationOptions,
          dopamineCrashSymptomOptions: dopamineCrashSymptomOptions,
          dopamineCrashAdditionalSymptomOptions:
              dopamineCrashAdditionalSymptomOptions,
          priorityCardCount: priorityCardCount,
          outlookLookAheadDays: outlookLookAheadDays,
          defaultStarterStepPrompt:
              GeminiService.defaultStarterStepPromptTemplate,
          defaultTaskSubtaskPrompt: GeminiService.defaultSubtaskPromptTemplate,
        ),
      ),
    );

    if (updatedSettings == null) {
      return;
    }

    setState(() {
      categories = updatedSettings.categories.isEmpty
          ? ['None']
          : updatedSettings.categories;
      dailyContextOptions = updatedSettings.contextTodayOptions;
      otherMedicationOptions = updatedSettings.otherMedicationOptions;
      dopamineCrashSymptomOptions = updatedSettings.dopamineCrashSymptomOptions;
      dopamineCrashAdditionalSymptomOptions =
          updatedSettings.dopamineCrashAdditionalSymptomOptions;
      starterStepPrompt = updatedSettings.starterStepPrompt;
      taskSubtaskPrompt = updatedSettings.taskSubtaskPrompt;
      priorityCardCount = updatedSettings.priorityCardCount;
      outlookLookAheadDays = updatedSettings.outlookLookAheadDays;
      normalizeTaskCategories();
      ensureSelectedTaskCategoryIsValid();
    });

    await saveCategories();
    await saveStarterStepPrompt();
    await saveTaskSubtaskPrompt();
    await saveTrackerOptions();
    await StorageService.savePriorityCardCount(priorityCardCount);
    await StorageService.saveOutlookLookAheadDays(outlookLookAheadDays);
    await saveTasks();
    _refreshUpcomingOutlookEvents();
  }

  Future<void> handleOutlookLink() async {
    if (!StorageService.isOutlookConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set oneDriveClientId in secrets.dart for Outlook linking first.',
          ),
        ),
      );
      return;
    }

    final linked = await StorageService.isOutlookLinked();

    if (linked) {
      final hasOutlookAccess = await _tryCheckOutlookConnection(silent: true);
      if (!hasOutlookAccess && mounted) {
        final relink = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Enable Outlook Access'),
              content: const Text(
                'Your current Microsoft link does not include Outlook calendar permission yet. Re-link now to grant Calendars.Read?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Not now'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Re-link'),
                ),
              ],
            );
          },
        );

        if (relink == true) {
          await StorageService.unlinkOutlook();
          if (!mounted) return;
          await handleOutlookLink();
          return;
        }
      }
    }

    if (!linked) {
      try {
        final session = await StorageService.beginOutlookLink();
        if (!mounted) return;

        final authUri = Uri.parse(session.verificationUri);
        final launched = await launchUrl(
          authUri,
          mode: LaunchMode.externalApplication,
        );

        if (mounted) {
          await showCopyableErrorDialog(
            'Outlook Auth URL',
            'Opening this Microsoft sign-in URL:\n\n${authUri.toString()}',
          );
        }

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open the Microsoft sign-in page. Please try again.',
              ),
            ),
          );
          return;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microsoft sign-in opened in your browser. Return to the app after completing sign-in.',
            ),
          ),
        );
        return;
      } catch (error) {
        if (!mounted) return;
        final errorText =
            'Unable to start Outlook link: $error\n\n'
            'Tip: In Azure App Registration, make sure the redirect URI for this app is added under Authentication.';
        await showCopyableErrorDialog('Outlook Link Error', errorText);
        return;
      }
    }

    final outlookConnected = await _tryCheckOutlookConnection(silent: true);
    if (!mounted) return;

    _refreshUpcomingOutlookEvents();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outlookConnected
              ? 'Outlook calendar connected.'
              : 'Outlook link active, but calendar permission is missing.',
        ),
      ),
    );
  }

  Future<void> _maybeCompleteOutlookAuthFromCurrentUrl() async {
    if (!kIsWeb) {
      return;
    }

    final uri = Uri.base;
    if (!uri.queryParameters.containsKey('code') &&
        !uri.queryParameters.containsKey('error')) {
      return;
    }

    try {
      final authenticated = await StorageService.completeOutlookLink();
      if (!mounted) return;

      if (authenticated) {
        _refreshUpcomingOutlookEvents();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outlook calendar connected.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outlook link did not complete.')),
      );
    } catch (error) {
      if (!mounted) return;
      final errorText =
          'Unable to finish Outlook link: $error\n\n'
          'Tip: In Azure App Registration, make sure the redirect URI for this app is added under Authentication.';
      await showCopyableErrorDialog('Outlook Link Error', errorText);
    }
  }

  Future<bool> _tryCheckOutlookConnection({required bool silent}) async {
    try {
      final eventCount = await StorageService.getUpcomingOutlookEventCount(
        lookAhead: Duration(days: outlookLookAheadDays),
      );
      if (!mounted || silent) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Outlook connected. $eventCount upcoming events found.',
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _formatOutlookEventTimeRange(OutlookCalendarEvent event) {
    if (event.isAllDay) {
      return 'All day';
    }
    if (event.start == null) {
      return 'Time unavailable';
    }

    final localStart = event.start!.toLocal();
    final startHour = localStart.hour;
    final startMinute = localStart.minute.toString().padLeft(2, '0');
    final startSuffix = startHour >= 12 ? 'PM' : 'AM';
    final startHour12 = startHour % 12 == 0 ? 12 : startHour % 12;

    if (event.end == null) {
      return '$startHour12:$startMinute $startSuffix';
    }

    final localEnd = event.end!.toLocal();
    final endHour = localEnd.hour;
    final endMinute = localEnd.minute.toString().padLeft(2, '0');
    final endSuffix = endHour >= 12 ? 'PM' : 'AM';
    final endHour12 = endHour % 12 == 0 ? 12 : endHour % 12;

    return '$startHour12:$startMinute $startSuffix - $endHour12:$endMinute $endSuffix';
  }

  String _formatOutlookDayDivider(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString().substring(2);

    return '$weekday, $day-$month-$year';
  }

  Widget _buildOutlookDayDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.blue.shade200,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formatOutlookDayDivider(date),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.blue.shade200,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showCopyableErrorDialog(String title, String errorText) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(errorText)),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: errorText));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error copied to clipboard.')),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void syncSubtaskControllers() {
    while (subtaskControllers.length < tasks.length) {
      subtaskControllers.add(TextEditingController());
    }

    while (subtaskControllers.length > tasks.length) {
      subtaskControllers.removeLast().dispose();
    }
  }

  TextEditingController getSubtaskController(int index) {
    while (subtaskControllers.length <= index) {
      subtaskControllers.add(TextEditingController());
    }
    return subtaskControllers[index];
  }

  String formatFocusTime(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String getTodayDateKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Map<String, dynamic> defaultDailyCheckin() {
    return {
      'trackerVersion': 2,
      'focus': -2,
      'restlessness': -2,
      'impulsivity': -2,
      'overwhelm': -2,
      'emotionalRegulation': -2,
      'workTaskScore': -2,
      'homeTaskScore': -2,
      'breakfastScore': -2,
      'lunchScore': -2,
      'dinnerScore': -2,
      'snacksScore': -2,
      'snack2Score': -2,
      'snack3Score': -2,
      'breakfastTime': '',
      'lunchTime': '',
      'dinnerTime': '',
      'snacksTime': '',
      'snack2Time': '',
      'snack3Time': '',
      'concertaXlTime': '',
      'concertaIrTime': '',
      'otherMedicationsTaken': <String>[],
      'dopamineCrashStartTime': '',
      'dopamineCrashEndTime': '',
      'dopamineCrashSymptoms': <String>[],
      'dopamineCrashSymptomsAdditional': <String>[],
      'contextTags': <String>[],
    };
  }

  int parseRating(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(-2, 10);
    }
    return -2;
  }

  List<String> parseStringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList();
    }
    return <String>[];
  }

  String formatScoreLabel(int value) {
    if (value == -2) {
      return '';
    }
    if (value == -1) {
      return 'N/A';
    }
    return '$value/10';
  }

  double calculateAverage(List<int> scores) {
    final tracked = scores.where((score) => score >= 0).toList();
    if (tracked.isEmpty) {
      return 0;
    }
    return tracked.reduce((a, b) => a + b) / tracked.length;
  }

  int parseScoreField(
    Map<String, dynamic> raw,
    String key, {
    dynamic legacyValue,
  }) {
    final hasCurrentValue = raw.containsKey(key);
    final sourceValue = hasCurrentValue ? raw[key] : legacyValue;
    if (sourceValue == null) {
      return -2;
    }

    final parsed = parseRating(sourceValue);
    // Legacy entries often persisted 0 by default. Treat those as unset.
    if (parsed == 0) {
      return -2;
    }

    return parsed;
  }

  Map<String, dynamic> getTodayDailyCheckin() {
    final raw = dailyCheckinsByDate[getTodayDateKey()] ?? <String, dynamic>{};
    return {
      'focus': parseScoreField(raw, 'focus'),
      'restlessness': parseScoreField(raw, 'restlessness'),
      'impulsivity': parseScoreField(raw, 'impulsivity'),
      'overwhelm': parseScoreField(raw, 'overwhelm'),
      'emotionalRegulation': parseScoreField(
        raw,
        'emotionalRegulation',
        legacyValue: raw['emotional regulation'],
      ),
      'workTaskScore': parseScoreField(
        raw,
        'workTaskScore',
        legacyValue: raw['workProductivity'],
      ),
      'homeTaskScore': parseScoreField(
        raw,
        'homeTaskScore',
        legacyValue: raw['homeProductivity'],
      ),
      // Legacy fallback: use previous meals score if specific meal score is absent.
      'breakfastScore': parseScoreField(
        raw,
        'breakfastScore',
        legacyValue: raw['mealsQuality'],
      ),
      'lunchScore': parseScoreField(
        raw,
        'lunchScore',
        legacyValue: raw['mealsQuality'],
      ),
      'dinnerScore': parseScoreField(
        raw,
        'dinnerScore',
        legacyValue: raw['mealsQuality'],
      ),
      'snacksScore': parseScoreField(
        raw,
        'snacksScore',
        legacyValue: raw['snacksQuality'],
      ),
      'snack2Score': parseScoreField(raw, 'snack2Score'),
      'snack3Score': parseScoreField(raw, 'snack3Score'),
      'breakfastTime': (raw['breakfastTime'] ?? '').toString(),
      'lunchTime': (raw['lunchTime'] ?? '').toString(),
      'dinnerTime': (raw['dinnerTime'] ?? '').toString(),
      'snacksTime': (raw['snacksTime'] ?? '').toString(),
      'snack2Time': (raw['snack2Time'] ?? '').toString(),
      'snack3Time': (raw['snack3Time'] ?? '').toString(),
      'concertaXlTime': (raw['concertaXlTime'] ?? raw['medicationTime'] ?? '')
          .toString(),
      'concertaIrTime': (raw['concertaIrTime'] ?? '').toString(),
      'otherMedicationsTaken': parseStringList(raw['otherMedicationsTaken']),
      'dopamineCrashStartTime':
          (raw['dopamineCrashStartTime'] ?? raw['dopamineCrashTime'] ?? '')
              .toString(),
      'dopamineCrashEndTime': (raw['dopamineCrashEndTime'] ?? '').toString(),
      'dopamineCrashSymptoms': parseStringList(raw['dopamineCrashSymptoms']),
      'dopamineCrashSymptomsAdditional': parseStringList(
        raw['dopamineCrashSymptomsAdditional'],
      ),
      'contextTags': parseStringList(raw['contextTags']),
    };
  }

  Future<void> updateTodayDailyCheckin(
    void Function(Map<String, dynamic> current) update,
  ) async {
    final todayKey = getTodayDateKey();

    setState(() {
      final current = Map<String, dynamic>.from(
        dailyCheckinsByDate[todayKey] ?? defaultDailyCheckin(),
      );
      current['trackerVersion'] = 2;
      update(current);
      dailyCheckinsByDate[todayKey] = current;
    });

    await saveDailyCheckinsByDate();
  }

  Future<void> setTodayDailyRating(String field, int value) async {
    await updateTodayDailyCheckin((current) {
      final nextValue = value.clamp(-1, 10).toInt();
      final currentValue = parseRating(current[field]);
      current[field] = currentValue == nextValue ? 0 : nextValue;
    });
  }

  Future<void> setTodayMedicationQuickTime(String field, String value) async {
    await updateTodayDailyCheckin((current) {
      current[field] = value;
    });
  }

  String formatPickedTime(TimeOfDay value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  TimeOfDay? parseStoredTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTodayMedicationTime(String field, String helpText) async {
    final checkin = getTodayDailyCheckin();
    final currentValue = (checkin[field] ?? '').toString();
    final initial = parseStoredTime(currentValue) ?? TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
    );

    if (picked == null) {
      return;
    }

    await updateTodayDailyCheckin((current) {
      current[field] = formatPickedTime(picked);
    });
  }

  Future<void> clearTodayMedicationTime(String field) async {
    await updateTodayDailyCheckin((current) {
      current[field] = '';
    });
  }

  Future<void> setTodayCrashTimeField(String field, String helpText) async {
    final checkin = getTodayDailyCheckin();
    final currentValue = (checkin[field] ?? '').toString();
    final initial = parseStoredTime(currentValue) ?? TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
    );

    if (picked == null) {
      return;
    }

    await updateTodayDailyCheckin((current) {
      current[field] = formatPickedTime(picked);
    });
  }

  Future<void> clearTodayCrashTimeField(String field) async {
    await updateTodayDailyCheckin((current) {
      current[field] = '';
    });
  }

  Future<void> toggleTodayCrashSymptomField(
    String field,
    String symptom,
  ) async {
    await updateTodayDailyCheckin((current) {
      final selected = parseStringList(current[field]);
      if (selected.contains(symptom)) {
        selected.remove(symptom);
      } else {
        selected.add(symptom);
      }
      current[field] = selected;
    });
  }

  Future<void> toggleTodayContextTag(String tag) async {
    await updateTodayDailyCheckin((current) {
      final selected = parseStringList(current['contextTags']);
      if (selected.contains(tag)) {
        selected.remove(tag);
      } else {
        selected.add(tag);
      }
      current['contextTags'] = selected;
    });
  }

  Future<void> toggleTodayOtherMedication(String medication) async {
    await updateTodayDailyCheckin((current) {
      final selected = parseStringList(current['otherMedicationsTaken']);
      if (selected.contains(medication)) {
        selected.remove(medication);
      } else {
        selected.add(medication);
      }
      current['otherMedicationsTaken'] = selected;
    });
  }

  Future<void> resetTodayDailyCheckin() async {
    final todayKey = getTodayDateKey();

    setState(() {
      dailyCheckinsByDate.remove(todayKey);
    });

    await saveDailyCheckinsByDate();
  }

  String getDailyCheckinSummaryLabel(double averageScore) {
    if (averageScore >= 3.25) {
      return 'Higher symptom intensity';
    }
    if (averageScore >= 2.25) {
      return 'Medium-high symptom intensity';
    }
    if (averageScore >= 1.25) {
      return 'Moderate symptom intensity';
    }
    if (averageScore > 0) {
      return 'Low symptom intensity';
    }
    return 'No check-in yet';
  }

  Duration getSelectedFocusTimerDuration() {
    return Duration(
      minutes: selectedFocusTimerMinutes,
      seconds: selectedFocusTimerSeconds,
    );
  }

  void setFocusTimerPreset(int minutes) {
    focusTimer?.cancel();
    setState(() {
      selectedFocusTimerMinutes = minutes;
      selectedFocusTimerSeconds = 0;
      remainingFocusTime = getSelectedFocusTimerDuration();
    });
  }

  Future<void> setCustomFocusTimer() async {
    final minutesController = TextEditingController(
      text: selectedFocusTimerMinutes.toString(),
    );
    final secondsController = TextEditingController(
      text: selectedFocusTimerSeconds.toString(),
    );

    int? parseMinutes() {
      return int.tryParse(minutesController.text.trim());
    }

    int? parseSeconds() {
      return int.tryParse(secondsController.text.trim());
    }

    final customDuration = await showDialog<Duration>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set timer (MM:SS)'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minutesController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: secondsController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) {
                    final minutes = parseMinutes();
                    final seconds = parseSeconds();
                    if (minutes == null || seconds == null) {
                      return;
                    }
                    if (minutes < 0 || seconds < 0 || seconds > 59) {
                      return;
                    }
                    if (minutes == 0 && seconds == 0) {
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      Duration(minutes: minutes, seconds: seconds),
                    );
                  },
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final minutes = parseMinutes();
                final seconds = parseSeconds();
                if (minutes == null || seconds == null) {
                  return;
                }
                if (minutes < 0 || seconds < 0 || seconds > 59) {
                  return;
                }
                if (minutes == 0 && seconds == 0) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  Duration(minutes: minutes, seconds: seconds),
                );
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );

    minutesController.dispose();
    secondsController.dispose();

    if (customDuration == null || customDuration <= Duration.zero) {
      return;
    }

    focusTimer?.cancel();
    setState(() {
      selectedFocusTimerMinutes = customDuration.inMinutes;
      selectedFocusTimerSeconds = customDuration.inSeconds % 60;
      remainingFocusTime = customDuration;
    });
  }

  void startFocusTimer() {
    if (focusTimer?.isActive == true) {
      return;
    }

    timerCompletionCueReset?.cancel();
    timerCompletionBeepLoop?.cancel();

    if (remainingFocusTime <= Duration.zero) {
      setState(() {
        remainingFocusTime = getSelectedFocusTimerDuration();
        timerCompletionCueActive = false;
      });
    } else {
      setState(() {
        timerCompletionCueActive = false;
      });
    }

    focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (remainingFocusTime > const Duration(seconds: 1)) {
          remainingFocusTime -= const Duration(seconds: 1);
        } else {
          remainingFocusTime = Duration.zero;
          timerCompletionCueActive = true;
          timer.cancel();
        }
      });

      if (remainingFocusTime == Duration.zero) {
        playTimerCompletionBeepCue();
        timerCompletionCueReset?.cancel();
        timerCompletionCueReset = Timer(const Duration(seconds: 2), () {
          if (!mounted) {
            return;
          }
          setState(() {
            timerCompletionCueActive = false;
          });
        });
      }
    });
  }

  void playTimerCompletionBeepCue() {
    timerCompletionBeepLoop?.cancel();
    final startedAt = DateTime.now();

    // Repeating short beeps for 2 seconds to mimic a stopwatch finish cue.
    SystemSound.play(SystemSoundType.alert);
    timerCompletionBeepLoop = Timer.periodic(
      const Duration(milliseconds: 250),
      (beepTimer) {
        if (!mounted) {
          beepTimer.cancel();
          return;
        }

        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed >= const Duration(seconds: 2)) {
          beepTimer.cancel();
          timerCompletionBeepLoop = null;
          return;
        }

        SystemSound.play(SystemSoundType.alert);
      },
    );
  }

  void stopFocusTimer() {
    focusTimer?.cancel();
    setState(() {});
  }

  void resetFocusTimer() {
    focusTimer?.cancel();
    timerCompletionCueReset?.cancel();
    timerCompletionBeepLoop?.cancel();
    setState(() {
      remainingFocusTime = getSelectedFocusTimerDuration();
      timerCompletionCueActive = false;
    });
  }

  @override
  void dispose() {
    focusTimer?.cancel();
    timerCompletionCueReset?.cancel();
    timerCompletionBeepLoop?.cancel();
    notesSaveDebounce?.cancel();
    unawaited(StorageService.saveNoteEntries(noteEntries));
    taskController.dispose();
    inboxCaptureController.dispose();
    noteTitleController.dispose();
    noteContentController.dispose();
    taskListScrollController.dispose();
    taskTabsScrollController.dispose();
    for (final controller in subtaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> addTask() async {
    if (taskController.text.trim().isNotEmpty) {
      ensureSelectedTaskCategoryIsValid();
      final taskCategory = selectedTaskCategory == 'All tasks'
          ? (categories.isNotEmpty ? categories.first : 'None')
          : selectedTaskCategory;

      setState(() {
        tasks.add(
          Task(
            task: taskController.text.trim(),
            done: false,
            expanded: false,
            priority: 'medium',
            category: taskCategory,
          ),
        );
        subtaskControllers.add(TextEditingController());
      });

      taskController.clear();

      await saveTasks();
    }
  }

  Future<void> addInboxEntry() async {
    final text = inboxCaptureController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      inboxEntries.insert(0, text);
      inboxCaptureController.clear();
    });

    await saveInboxEntries();
  }

  Future<void> removeInboxEntry(int index) async {
    if (index < 0 || index >= inboxEntries.length) {
      return;
    }

    setState(() {
      inboxEntries.removeAt(index);
    });
    await saveInboxEntries();
  }

  Future<void> editInboxEntry(int index) async {
    if (index < 0 || index >= inboxEntries.length) {
      return;
    }

    final controller = TextEditingController(text: inboxEntries[index]);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit captured item'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.pop(dialogContext, controller.text.trim());
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (updated == null || updated.isEmpty) {
      return;
    }

    setState(() {
      inboxEntries[index] = updated;
    });

    await saveInboxEntries();
  }

  Future<void> convertInboxEntryToTask(int index) async {
    if (index < 0 || index >= inboxEntries.length) {
      return;
    }

    final entry = inboxEntries[index].trim();
    if (entry.isEmpty) {
      return;
    }

    final taskCategory = categories.isNotEmpty ? categories.first : 'None';
    setState(() {
      tasks.add(
        Task(
          task: entry,
          done: false,
          expanded: false,
          priority: 'medium',
          category: taskCategory,
        ),
      );
      subtaskControllers.add(TextEditingController());
      inboxEntries.removeAt(index);
    });

    await saveTasks();
    await saveInboxEntries();
  }

  bool isTaskSnoozed(Task task) {
    final raw = task.snoozedUntilUtc;
    if (raw == null || raw.trim().isEmpty) {
      return false;
    }

    final snoozedUntil = DateTime.tryParse(raw);
    if (snoozedUntil == null) {
      return false;
    }

    return snoozedUntil.isAfter(DateTime.now().toUtc());
  }

  int? getNextActionTaskIndex() {
    final candidateIndices = tasks
        .asMap()
        .entries
        .where((entry) {
          final task = entry.value;
          return task.done != true && !isTaskSnoozed(task);
        })
        .map((entry) => entry.key)
        .toList();

    if (candidateIndices.isEmpty) {
      return null;
    }

    candidateIndices.sort((a, b) {
      final taskA = tasks[a];
      final taskB = tasks[b];

      final priorityA = RecommendationService.getPriorityScore(taskA.priority);
      final priorityB = RecommendationService.getPriorityScore(taskB.priority);
      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA);
      }

      final dueA = RecommendationService.getDueDays(taskA);
      final dueB = RecommendationService.getDueDays(taskB);
      if (dueA != dueB) {
        return dueA.compareTo(dueB);
      }

      final progressA = RecommendationService.getTaskProgress(taskA);
      final progressB = RecommendationService.getTaskProgress(taskB);
      return progressA.compareTo(progressB);
    });

    return candidateIndices.first;
  }

  String getNextActionLabel(int taskIndex) {
    final task = tasks[taskIndex];
    final incompleteSubtaskIndex = task.subtasks.indexWhere(
      (subtask) => subtask.done != true,
    );

    if (incompleteSubtaskIndex != -1) {
      return task.subtasks[incompleteSubtaskIndex].text;
    }

    if (task.starterTinyStep.trim().isNotEmpty) {
      return task.starterTinyStep.trim();
    }

    return task.task;
  }

  Future<void> snoozeTask(int taskIndex, Duration duration) async {
    if (taskIndex < 0 || taskIndex >= tasks.length) {
      return;
    }

    setState(() {
      tasks[taskIndex].snoozedUntilUtc = DateTime.now()
          .toUtc()
          .add(duration)
          .toIso8601String();
    });

    await saveTasks();
  }

  Future<void> clearTaskSnooze(int taskIndex) async {
    if (taskIndex < 0 || taskIndex >= tasks.length) {
      return;
    }

    setState(() {
      tasks[taskIndex].snoozedUntilUtc = null;
    });

    await saveTasks();
  }

  Future<void> editStarterScript(int index) async {
    if (index < 0 || index >= tasks.length) {
      return;
    }

    final tinyStepController = TextEditingController(
      text: tasks[index].starterTinyStep,
    );
    final setupController = TextEditingController(
      text: tasks[index].starterSetupChecklist,
    );
    final stuckController = TextEditingController(
      text: tasks[index].starterIfStuck,
    );

    final saved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Starter script'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: tinyStepController,
                        decoration: const InputDecoration(
                          labelText: 'First tiny step',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: setupController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Setup checklist',
                          hintText: 'One item per line',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: stuckController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'If stuck, do this',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (saved) {
      setState(() {
        tasks[index].starterTinyStep = tinyStepController.text.trim();
        tasks[index].starterSetupChecklist = setupController.text.trim();
        tasks[index].starterIfStuck = stuckController.text.trim();
      });
      await saveTasks();
    }

    tinyStepController.dispose();
    setupController.dispose();
    stuckController.dispose();
  }

  Future<void> generateStarterScript(int index) async {
    if (index < 0 || index >= tasks.length) {
      return;
    }

    if (tasks[index].aiSubtasks.isEmpty && !isGenerating) {
      await createSubtasks(index, defaultStarterStepCount);
      if (!mounted) {
        return;
      }
    }

    final task = tasks[index];
    String cleanLine(String text) {
      return text
          .trim()
          .replaceAll(RegExp(r'^[-*\d\.\)\s]+'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
    }

    String cap(String value, int maxChars) {
      final trimmed = value.trim();
      if (trimmed.length <= maxChars) {
        return trimmed;
      }

      final window = trimmed.substring(0, maxChars).trimRight();
      final sentenceEnd = window.lastIndexOf(RegExp(r'[.!?]'));
      if (sentenceEnd >= (maxChars * 0.45)) {
        return window.substring(0, sentenceEnd + 1).trimRight();
      }

      final wordEnd = window.lastIndexOf(' ');
      final fallback = (wordEnd > 0 ? window.substring(0, wordEnd) : window)
          .trimRight();
      if (fallback.endsWith('.') ||
          fallback.endsWith('!') ||
          fallback.endsWith('?')) {
        return fallback;
      }
      return '$fallback.';
    }

    final suggestions = task.aiSubtasks
        .map((subtask) => cleanLine(subtask.text))
        .where((text) => text.isNotEmpty)
        .toList();

    final fallbackStep = cleanLine(getStarterStepSourceText(index));
    final tinyStepRaw = suggestions.isNotEmpty
        ? suggestions.first
        : (fallbackStep.isNotEmpty ? fallbackStep : cleanLine(task.task));
    final tinyStep = cap(tinyStepRaw, 70);

    final setupItems = suggestions
        .skip(1)
        .take(2)
        .map(cleanLine)
        .where((item) => item.isNotEmpty)
        .toList();
    if (setupItems.isEmpty) {
      setupItems.add('Open what you need');
      setupItems.add('Do one tiny action');
    }

    final setupChecklist = cap('Setup: ${setupItems.take(2).join('; ')}.', 100);
    final ifStuck = cap(
      'If stuck: 2-minute timer, do "$tinyStep", then stop.',
      100,
    );

    setState(() {
      tasks[index].starterTinyStep = tinyStep;
      tasks[index].starterSetupChecklist = setupChecklist;
      tasks[index].starterIfStuck = ifStuck;
    });

    await saveTasks();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Starter script generated.')));
  }

  Future<void> addSubtaskFromInput(int taskIndex) async {
    final controller = getSubtaskController(taskIndex);
    final text = controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      tasks[taskIndex].subtasks.add(Subtask(text: text, done: false));
      tasks[taskIndex].expanded = true;
      controller.clear();
    });

    await saveTasks();
  }

  String getStarterStepSourceText(int index) {
    if (tasks[index].subtasks.isNotEmpty) {
      final nextIncompleteIndex = tasks[index].subtasks.indexWhere(
        (subtask) => subtask.done != true,
      );

      if (nextIncompleteIndex != -1) {
        return tasks[index].subtasks[nextIncompleteIndex].text;
      }
    }

    return tasks[index].task;
  }

  List<Task> getTopTasks(int count) {
    final unfinishedTasks = tasks.where((task) => task.done != true).toList();

    unfinishedTasks.sort((a, b) {
      final priorityA = RecommendationService.getPriorityScore(a.priority);
      final priorityB = RecommendationService.getPriorityScore(b.priority);
      if (priorityA != priorityB) return priorityB.compareTo(priorityA);

      final dueA = RecommendationService.getDueDays(a);
      final dueB = RecommendationService.getDueDays(b);
      if (dueA != dueB) return dueA.compareTo(dueB);

      final progressA = RecommendationService.getTaskProgress(a);
      final progressB = RecommendationService.getTaskProgress(b);
      return progressA.compareTo(progressB);
    });

    return unfinishedTasks.take(count).toList();
  }

  Future<void> createSubtasks(int index, int stepCount) async {
    final sourceText = getStarterStepSourceText(index);

    setState(() {
      isGenerating = true;
    });

    try {
      final breakdown = await GeminiService.generateSubtasks(
        sourceText,
        stepCount,
        promptTemplate: starterStepPrompt,
      );
      setState(() {
        tasks[index].aiSubtasks = breakdown.subtasks;
        tasks[index].expanded = true;
      });

      await saveTasks();
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Future<void> handleGenerateSubtasks(int index) async {
    final stepCount = await showStepCountDialog(context);

    if (!mounted || stepCount == null || stepCount <= 0) {
      return;
    }

    await createSubtasks(index, stepCount);
  }

  Future<void> createTaskSubtasks(int index, int stepCount) async {
    setState(() {
      isGenerating = true;
    });

    try {
      final breakdown = await GeminiService.generateTaskSubtasks(
        tasks[index].task,
        tasks[index].subtasks,
        stepCount,
        promptTemplate: taskSubtaskPrompt,
      );

      final existingNormalized = tasks[index].subtasks
          .map((subtask) => subtask.text.trim().toLowerCase())
          .toSet();

      final uniqueSubtasks = breakdown.subtasks.where((subtask) {
        final normalized = subtask.text.trim().toLowerCase();
        if (normalized.isEmpty || existingNormalized.contains(normalized)) {
          return false;
        }

        existingNormalized.add(normalized);
        subtask.aiSuggested = true;
        return true;
      }).toList();

      setState(() {
        tasks[index].subtasks.addAll(uniqueSubtasks);
        tasks[index].expanded = true;
      });

      await saveTasks();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uniqueSubtasks.isEmpty
                ? 'No new subtasks suggested.'
                : 'Added ${uniqueSubtasks.length} subtask${uniqueSubtasks.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Future<void> handleGenerateTaskSubtasks(int index) async {
    final stepCount = await showStepCountDialog(context);

    if (!mounted || stepCount == null || stepCount <= 0) {
      return;
    }

    await createTaskSubtasks(index, stepCount);
  }

  Future<void> editTask(int index) async {
    final updatedText = await showEditTaskDialog(context, tasks[index].task);

    if (updatedText == null || updatedText.isEmpty) {
      return;
    }

    setState(() {
      tasks[index].task = updatedText;
    });

    await saveTasks();
  }

  Future<void> editSubtask(int taskIndex, int subtaskIndex) async {
    final updatedText = await showEditSubtaskDialog(
      context,
      tasks[taskIndex].subtasks[subtaskIndex].text,
    );

    if (updatedText == null || updatedText.isEmpty) {
      return;
    }

    setState(() {
      tasks[taskIndex].subtasks[subtaskIndex].aiSuggested = false;
      tasks[taskIndex].subtasks[subtaskIndex].text = updatedText;
    });

    await saveTasks();
  }

  Future<void> moveSubtaskUp(int taskIndex, int subtaskIndex) async {
    if (subtaskIndex == 0) return;

    setState(() {
      final item = tasks[taskIndex].subtasks.removeAt(subtaskIndex);

      tasks[taskIndex].subtasks.insert(subtaskIndex - 1, item);
    });

    await saveTasks();
  }

  Future<void> moveSubtaskDown(int taskIndex, int subtaskIndex) async {
    if (subtaskIndex == tasks[taskIndex].subtasks.length - 1) {
      return;
    }

    setState(() {
      final item = tasks[taskIndex].subtasks.removeAt(subtaskIndex);

      tasks[taskIndex].subtasks.insert(subtaskIndex + 1, item);
    });

    await saveTasks();
  }

  Future<void> toggleTask(int index, bool? value) async {
    setState(() {
      tasks[index].done = value ?? false;
    });

    await saveTasks();
  }

  Future<void> toggleSubtask(
    int taskIndex,
    int subtaskIndex,
    bool? value,
  ) async {
    final newDoneValue = value ?? false;
    final currentNextIncompleteIndex = tasks[taskIndex].subtasks.indexWhere(
      (subtask) => subtask.done != true,
    );

    setState(() {
      tasks[taskIndex].subtasks[subtaskIndex].done = newDoneValue;

      if (tasks[taskIndex].aiSubtasks.isNotEmpty &&
          ((newDoneValue == true &&
                  currentNextIncompleteIndex == subtaskIndex) ||
              newDoneValue == false)) {
        tasks[taskIndex].aiSubtasks = [];
      }

      bool allDone = tasks[taskIndex].subtasks.every(
        (subtask) => subtask.done == true,
      );

      tasks[taskIndex].done = allDone;
    });

    await saveTasks();
  }

  Future<void> toggleExpanded(int index) async {
    setState(() {
      if (compactView) {
        compactView = false;
        for (final task in tasks) {
          task.expanded = false;
        }
        tasks[index].expanded = true;
      } else {
        tasks[index].expanded = !tasks[index].expanded;
      }
    });

    await saveTasks();
  }

  Future<void> expandAllTaskTiles() async {
    setState(() {
      compactView = false;
      for (final task in tasks) {
        task.expanded = true;
      }
    });

    await saveTasks();
  }

  Future<void> collapseAllTaskTiles() async {
    setState(() {
      compactView = true;
      for (final task in tasks) {
        task.expanded = false;
      }
    });

    await saveTasks();
  }

  Future<void> selectTaskDetailTab(int index, int tabIndex) async {
    if (index < 0 || index >= tasks.length) {
      return;
    }

    final task = tasks[index];

    setState(() {
      taskDetailTabByTask[task] = tabIndex;
    });

    if (tabIndex == 1 && task.aiSubtasks.isEmpty && !isGenerating) {
      await createSubtasks(index, defaultStarterStepCount);
    }
  }

  Future<void> deleteTask(int index) async {
    setState(() {
      final removedTask = tasks.removeAt(index);
      taskDetailTabByTask.remove(removedTask);
      subtaskControllers.removeAt(index).dispose();
    });

    await saveTasks();
  }

  Future<void> deleteSubtask(int taskIndex, int subtaskIndex) async {
    setState(() {
      tasks[taskIndex].subtasks.removeAt(subtaskIndex);

      if (tasks[taskIndex].subtasks.isEmpty) {
        tasks[taskIndex].done = false;
      }
    });

    await saveTasks();
  }

  void showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text("Delete '${tasks[index].task}'?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteTask(index);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void showDeleteSubtaskConfirmation(int taskIndex, int subtaskIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Subtask"),
        content: Text(
          "Delete '${tasks[taskIndex].subtasks[subtaskIndex].text}'?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await deleteSubtask(taskIndex, subtaskIndex);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Task progress calculation moved to RecommendationService.getTaskProgress

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "high":
        return Colors.red;

      case "medium":
        return Colors.orange;

      case "low":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  String getPriorityLabel(String priority) {
    switch (priority) {
      case "high":
        return "High";

      case "medium":
        return "Medium";

      case "low":
        return "Low";

      default:
        return "Medium";
    }
  }

  Future<void> changePriority(int index) async {
    String selected = tasks[index].priority;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Task Priority"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.red),
                  title: const Text("High"),
                  trailing: selected == "high" ? const Icon(Icons.check) : null,
                  onTap: () {
                    setStateDialog(() {
                      selected = "high";
                    });
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.orange),
                  title: const Text("Medium"),
                  trailing: selected == "medium"
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setStateDialog(() {
                      selected = "medium";
                    });
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.green),
                  title: const Text("Low"),
                  trailing: selected == "low" ? const Icon(Icons.check) : null,
                  onTap: () {
                    setStateDialog(() {
                      selected = "low";
                    });
                  },
                ),
              ],
            );
          },
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () async {
              tasks[index].priority = selected;

              Navigator.pop(context);

              await saveTasks();

              if (mounted) setState(() {});
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Recommendation and sorting logic moved to RecommendationService.

  Future<void> setDueDate(int index) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      tasks[index].dueDate = pickedDate.toIso8601String().split("T").first;
    });

    await saveTasks();
  }

  String formatDueDate(String? dueDate) {
    if (dueDate == null) {
      return "";
    }

    final date = DateTime.parse(dueDate);

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final targetDate = DateTime(date.year, date.month, date.day);

    final difference = targetDate.difference(today).inDays;

    if (difference < 0) {
      return "Overdue";
    }

    if (difference == 0) {
      return "Today";
    }

    if (difference == 1) {
      return "Tomorrow";
    }

    if (difference <= 7) {
      return "In $difference days";
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString().substring(2);

    return '$day-$month-$year';
  }

  Future<void> recommendNextTask() async {
    final recommendation = RecommendationService.getRecommendation(tasks);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recommendation"),
        content: Text(recommendation),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteStarterSteps(int index) async {
    setState(() {
      tasks[index].aiSubtasks = [];
      if (tasks[index].subtasks.isEmpty) {
        tasks[index].expanded = false;
      }
    });

    await saveTasks();
  }

  Future<bool> showDeleteStarterStepsConfirmation(int index) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete starter steps'),
            content: const Text(
              'Delete the generated starter steps for this task?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> confirmDeleteStarterSteps(int index) async {
    final confirmed = await showDeleteStarterStepsConfirmation(index);
    if (!mounted || !confirmed) return;

    await deleteStarterSteps(index);
  }

  Future<void> completeNextAction() async {
    final taskIndex = getNextActionTaskIndex();
    if (taskIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No next action to complete.')),
      );
      return;
    }

    String completedStep = '';
    setState(() {
      tasks[taskIndex].snoozedUntilUtc = null;
      final incompleteSubtaskIndex = tasks[taskIndex].subtasks.indexWhere(
        (subtask) => subtask.done != true,
      );

      if (incompleteSubtaskIndex != -1) {
        tasks[taskIndex].subtasks[incompleteSubtaskIndex].done = true;
        tasks[taskIndex].done = tasks[taskIndex].subtasks.every(
          (subtask) => subtask.done == true,
        );
        completedStep = 'Marked next subtask complete.';
      } else {
        tasks[taskIndex].done = true;
        for (final subtask in tasks[taskIndex].subtasks) {
          subtask.done = true;
        }
        completedStep = 'Marked task complete.';
      }
    });

    await saveTasks();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(completedStep)));
  }

  Widget buildTasksView({
    required bool showOverview,
    required bool showTaskList,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final hasAnyExpandedTask = tasks.any((task) => task.expanded);
        final priorityCardWidth = isNarrow ? null : kWidePriorityCardWidth;
        final priorityCardsTotalWidth = isNarrow
            ? constraints.maxWidth
            : (((priorityCardWidth ?? 0) * 3) + kWidePriorityCardsSpacingTotal)
                  .clamp(0, constraints.maxWidth)
                  .toDouble();
        final priorityCardSpacing = 6.0;
        final priorityCardAvailableWidth =
            (priorityCardsTotalWidth -
                    16 -
                    ((priorityCardCount - 1) * priorityCardSpacing))
                .clamp(0.0, double.infinity)
                .toDouble();
        final priorityCardDisplayWidth =
            ((priorityCardAvailableWidth - kPriorityCardWidthReduction) /
                    priorityCardCount)
                .clamp(96.0, kWidePriorityCardWidth)
                .toDouble();
        final taskTabs = getTaskTabs();
        final visibleTaskIndices = getVisibleTaskIndices();

        Widget buildPriorityMetaBox(
          String value, {
          required bool isUrgencyBox,
          required Color accentColor,
        }) {
          return Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUrgencyBox
                  ? accentColor.withAlpha(28)
                  : Colors.white.withAlpha(170),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isUrgencyBox
                    ? accentColor.withAlpha(180)
                    : Colors.grey.shade300,
                width: isUrgencyBox ? 1.5 : 1,
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value.isEmpty ? ' ' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUrgencyBox ? accentColor : Colors.black87,
                ),
              ),
            ),
          );
        }

        Widget buildPriorityCard(int position, Task? task) {
          final card = Card(
            color: position == 0
                ? Colors.blue.shade50
                : position == 1
                ? Colors.blue.shade100
                : Colors.blue.shade200,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: task == null
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No task',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text('Add more tasks to fill this slot.'),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              position == 0
                                  ? '#1'
                                  : position == 1
                                  ? '#2'
                                  : '#3',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  task.task,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (task.category != 'None')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(180),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  task.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: buildPriorityMetaBox(
                                getPriorityLabel(task.priority),
                                isUrgencyBox: true,
                                accentColor: switch (task.priority) {
                                  'high' => Colors.red.shade700,
                                  'medium' => Colors.orange.shade700,
                                  'low' => Colors.green.shade700,
                                  _ => Colors.grey.shade700,
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: buildPriorityMetaBox(
                                task.dueDate == null
                                    ? ''
                                    : formatDueDate(task.dueDate),
                                isUrgencyBox: false,
                                accentColor: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          );

          if (task == null) {
            return SizedBox(width: priorityCardDisplayWidth, child: card);
          }

          return SizedBox(
            width: priorityCardDisplayWidth,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await openTaskFromPriorityCard(task);
                },
                child: card,
              ),
            ),
          );
        }

        Widget buildDailyCheckinSection() {
          final checkin = getTodayDailyCheckin();
          final focus = checkin['focus'] as int;
          final restlessness = checkin['restlessness'] as int;
          final impulsivity = checkin['impulsivity'] as int;
          final overwhelm = checkin['overwhelm'] as int;
          final emotionalRegulation = checkin['emotionalRegulation'] as int;
          final workTaskScore = checkin['workTaskScore'] as int;
          final homeTaskScore = checkin['homeTaskScore'] as int;
          final breakfastScore = checkin['breakfastScore'] as int;
          final lunchScore = checkin['lunchScore'] as int;
          final dinnerScore = checkin['dinnerScore'] as int;
          final snacksScore = checkin['snacksScore'] as int;
          final snack2Score = checkin['snack2Score'] as int;
          final snack3Score = checkin['snack3Score'] as int;
          final breakfastTime = (checkin['breakfastTime'] ?? '').toString();
          final lunchTime = (checkin['lunchTime'] ?? '').toString();
          final dinnerTime = (checkin['dinnerTime'] ?? '').toString();
          final snacksTime = (checkin['snacksTime'] ?? '').toString();
          final snack2Time = (checkin['snack2Time'] ?? '').toString();
          final snack3Time = (checkin['snack3Time'] ?? '').toString();
          final concertaXlTime = (checkin['concertaXlTime'] ?? '').toString();
          final concertaIrTime = (checkin['concertaIrTime'] ?? '').toString();
          final otherMedicationsTaken = parseStringList(
            checkin['otherMedicationsTaken'],
          );
          final dopamineCrashStartTime =
              (checkin['dopamineCrashStartTime'] ?? '').toString();
          final dopamineCrashEndTime = (checkin['dopamineCrashEndTime'] ?? '')
              .toString();
          final dopamineCrashSymptoms = parseStringList(
            checkin['dopamineCrashSymptoms'],
          );
          final dopamineCrashAdditionalSymptoms = parseStringList(
            checkin['dopamineCrashSymptomsAdditional'],
          );
          final contextTags = parseStringList(checkin['contextTags']);
          final fixedContextColumns = <List<String>>[
            ['Good sleep', 'Bad sleep', 'Exercise day'],
            ['Home', 'WFH', 'WFO'],
            ['Low stress', 'Mid stress', 'High stress'],
          ];
          final fixedContextTags = fixedContextColumns
              .expand((column) => column)
              .toSet();
          final remainingContextTags = dailyContextOptions
              .where((tag) => !fixedContextTags.contains(tag))
              .toList();
          final contextColumns = <List<String>>[
            ...fixedContextColumns,
            for (var i = 0; i < remainingContextTags.length; i += 3)
              remainingContextTags.sublist(
                i,
                i + 3 > remainingContextTags.length
                    ? remainingContextTags.length
                    : i + 3,
              ),
          ];

          Widget buildRatingRow({
            required String label,
            required String field,
            required int value,
            Widget? trailingControl,
          }) {
            final hasSelection = value == -1 || value > 0;
            final accentColor = switch (field) {
              'focus' => const Color(0xFF2F6FE4),
              'restlessness' => const Color(0xFF6B5BDB),
              'impulsivity' => const Color(0xFFE16A2A),
              'overwhelm' => const Color(0xFFC14E7B),
              'emotionalRegulation' => const Color(0xFF2E9B8C),
              'workTaskScore' => const Color(0xFF2A7F56),
              'homeTaskScore' => const Color(0xFF9A6B2A),
              'breakfastScore' => const Color(0xFF3E8F5B),
              'lunchScore' => const Color(0xFF4E9A66),
              'dinnerScore' => const Color(0xFF397A8A),
              'snacksScore' => const Color(0xFF8D6BC9),
              'snack2Score' => const Color(0xFF7C5CC3),
              'snack3Score' => const Color(0xFF6E4FB6),
              _ => const Color(0xFF4C5FD4),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: BoxDecoration(
                  color: hasSelection
                      ? Colors.white
                      : accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasSelection
                        ? accentColor.withAlpha(90)
                        : accentColor.withAlpha(55),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, rowConstraints) {
                    final labelWidth = (rowConstraints.maxWidth * 0.26)
                        .clamp(105.0, 155.0)
                        .toDouble();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: labelWidth,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...List.generate(10, (index) {
                                  final rating = index + 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: SizedBox(
                                      width: 34,
                                      child: ChoiceChip(
                                        label: SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            rating.toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        selected: value == rating,
                                        labelPadding: EdgeInsets.zero,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 0,
                                        ),
                                        selectedColor: accentColor.withAlpha(
                                          44,
                                        ),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: accentColor.withAlpha(80),
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onSelected: (_) async {
                                          await setTodayDailyRating(
                                            field,
                                            rating,
                                          );
                                        },
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  );
                                }),
                                SizedBox(
                                  width: 46,
                                  child: ChoiceChip(
                                    label: const SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        'N/A',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    selected: value == -1,
                                    labelPadding: EdgeInsets.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 0,
                                    ),
                                    selectedColor: accentColor.withAlpha(44),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: accentColor.withAlpha(80),
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onSelected: (_) async {
                                      await setTodayDailyRating(field, -1);
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (trailingControl != null) const SizedBox(width: 8),
                        ?trailingControl,
                      ],
                    );
                  },
                ),
              ),
            );
          }

          Widget buildMealRow({
            required String label,
            required String scoreField,
            required int scoreValue,
            required String timeField,
            required String timeValue,
            required String timeHelpText,
          }) {
            return buildRatingRow(
              label: label,
              field: scoreField,
              value: scoreValue,
              trailingControl: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      timeValue.isEmpty ? '--:--' : timeValue,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await setTodayMedicationTime(timeField, timeHelpText);
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('Set'),
                  ),
                  if (timeValue.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await clearTodayMedicationTime(timeField);
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            );
          }

          Widget buildMedicationTimeRow({
            required String label,
            required String field,
            required String value,
            required String pickerHelpText,
            required String quickTime,
            required String quickLabel,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label: ${value.isEmpty ? '' : value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await setTodayMedicationQuickTime(field, quickTime);
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(quickLabel),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await setTodayMedicationTime(field, pickerHelpText);
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Set'),
                      ),
                      if (value.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await clearTodayMedicationTime(field);
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget buildCrashSymptomSection({
            required String title,
            required List<String> options,
            required List<String> selected,
            required String field,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 6.0;
                    const targetColumns = 4;
                    if (options.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final columns = options.length < targetColumns
                        ? options.length
                        : targetColumns;
                    final chipWidth =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                        columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: options.map((symptom) {
                        return SizedBox(
                          width: chipWidth,
                          child: FilterChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                symptom,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            selected: selected.contains(symptom),
                            onSelected: (_) async {
                              await toggleTodayCrashSymptomField(
                                field,
                                symptom,
                              );
                            },
                            labelPadding: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          }

          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ADHD symptom tracker',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.indigo.shade700,
                        unselectedLabelColor: Colors.grey.shade700,
                        indicatorColor: Colors.indigo.shade700,
                        tabs: const [
                          Tab(text: 'General'),
                          Tab(text: 'Meals'),
                          Tab(text: 'Medication'),
                          Tab(text: 'Crash'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 430,
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Context today',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LayoutBuilder(
                                    builder: (context, contextConstraints) {
                                      const columnGap = 8.0;
                                      const separatorWidth = 1.0;
                                      const chipHeight = 40.0;
                                      const chipVerticalGap = 5.0;

                                      final columnCount = contextColumns.length;
                                      if (columnCount == 0) {
                                        return const SizedBox.shrink();
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: List.generate(columnCount, (
                                          columnIndex,
                                        ) {
                                          final tags =
                                              contextColumns[columnIndex];
                                          final isLast =
                                              columnIndex == columnCount - 1;

                                          return Expanded(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: tags.map((tag) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom:
                                                                  chipVerticalGap,
                                                            ),
                                                        child: SizedBox(
                                                          width:
                                                              double.infinity,
                                                          height: chipHeight,
                                                          child: FilterChip(
                                                            label: SizedBox(
                                                              width: double
                                                                  .infinity,
                                                              child: Text(
                                                                tag,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                maxLines: 2,
                                                                softWrap: true,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                    ),
                                                              ),
                                                            ),
                                                            selected:
                                                                contextTags
                                                                    .contains(
                                                                      tag,
                                                                    ),
                                                            onSelected: (_) async {
                                                              await toggleTodayContextTag(
                                                                tag,
                                                              );
                                                            },
                                                            labelPadding:
                                                                EdgeInsets.zero,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 4,
                                                                ),
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                if (!isLast) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    width: separatorWidth,
                                                    height: 99,
                                                    color: Colors
                                                        .indigo
                                                        .shade100
                                                        .withAlpha(150),
                                                  ),
                                                  const SizedBox(
                                                    width: columnGap - 4,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  buildRatingRow(
                                    label: 'Work tasks',
                                    field: 'workTaskScore',
                                    value: workTaskScore,
                                  ),
                                  buildRatingRow(
                                    label: 'Home tasks',
                                    field: 'homeTaskScore',
                                    value: homeTaskScore,
                                  ),
                                  buildRatingRow(
                                    label: symptomTrackerLabels['focus']!,
                                    field: 'focus',
                                    value: focus,
                                  ),
                                  buildRatingRow(
                                    label:
                                        symptomTrackerLabels['restlessness']!,
                                    field: 'restlessness',
                                    value: restlessness,
                                  ),
                                  buildRatingRow(
                                    label: symptomTrackerLabels['impulsivity']!,
                                    field: 'impulsivity',
                                    value: impulsivity,
                                  ),
                                  buildRatingRow(
                                    label: symptomTrackerLabels['overwhelm']!,
                                    field: 'overwhelm',
                                    value: overwhelm,
                                  ),
                                  buildRatingRow(
                                    label:
                                        symptomTrackerLabels['emotionalRegulation']!,
                                    field: 'emotionalRegulation',
                                    value: emotionalRegulation,
                                  ),
                                  Text(
                                    '1 = low, 10 = very strong',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildMealRow(
                                    label: 'Breakfast quality',
                                    scoreField: 'breakfastScore',
                                    scoreValue: breakfastScore,
                                    timeField: 'breakfastTime',
                                    timeValue: breakfastTime,
                                    timeHelpText:
                                        'When did you have breakfast?',
                                  ),
                                  buildMealRow(
                                    label: 'Lunch quality',
                                    scoreField: 'lunchScore',
                                    scoreValue: lunchScore,
                                    timeField: 'lunchTime',
                                    timeValue: lunchTime,
                                    timeHelpText: 'When did you have lunch?',
                                  ),
                                  buildMealRow(
                                    label: 'Dinner quality',
                                    scoreField: 'dinnerScore',
                                    scoreValue: dinnerScore,
                                    timeField: 'dinnerTime',
                                    timeValue: dinnerTime,
                                    timeHelpText: 'When did you have dinner?',
                                  ),
                                  buildMealRow(
                                    label: 'Snack 1 quality',
                                    scoreField: 'snacksScore',
                                    scoreValue: snacksScore,
                                    timeField: 'snacksTime',
                                    timeValue: snacksTime,
                                    timeHelpText: 'When did you have snack 1?',
                                  ),
                                  buildMealRow(
                                    label: 'Snack 2 quality',
                                    scoreField: 'snack2Score',
                                    scoreValue: snack2Score,
                                    timeField: 'snack2Time',
                                    timeValue: snack2Time,
                                    timeHelpText: 'When did you have snack 2?',
                                  ),
                                  buildMealRow(
                                    label: 'Snack 3 quality',
                                    scoreField: 'snack3Score',
                                    scoreValue: snack3Score,
                                    timeField: 'snack3Time',
                                    timeValue: snack3Time,
                                    timeHelpText: 'When did you have snack 3?',
                                  ),
                                  Text(
                                    '1 = very poor, 10 = very good',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildMedicationTimeRow(
                                    label: 'Concerta XL',
                                    field: 'concertaXlTime',
                                    value: concertaXlTime,
                                    pickerHelpText:
                                        'When did you take Concerta XL?',
                                    quickTime: '08:00',
                                    quickLabel: '8:00 AM',
                                  ),
                                  buildMedicationTimeRow(
                                    label: 'Concerta IR',
                                    field: 'concertaIrTime',
                                    value: concertaIrTime,
                                    pickerHelpText:
                                        'When did you take Concerta IR?',
                                    quickTime: '16:30',
                                    quickLabel: '4:30 PM',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Other medications',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      const spacing = 6.0;
                                      const targetColumns = 4;
                                      if (otherMedicationOptions.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      final columns =
                                          otherMedicationOptions.length <
                                              targetColumns
                                          ? otherMedicationOptions.length
                                          : targetColumns;
                                      final chipWidth =
                                          (constraints.maxWidth -
                                              ((columns - 1) * spacing)) /
                                          columns;

                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        children: otherMedicationOptions.map((
                                          med,
                                        ) {
                                          return SizedBox(
                                            width: chipWidth,
                                            child: FilterChip(
                                              label: SizedBox(
                                                width: double.infinity,
                                                child: Text(
                                                  med,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              selected: otherMedicationsTaken
                                                  .contains(med),
                                              onSelected: (_) async {
                                                await toggleTodayOtherMedication(
                                                  med,
                                                );
                                              },
                                              labelPadding: EdgeInsets.zero,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 90,
                                        child: Text(
                                          'Crash start:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 52,
                                        child: Text(
                                          dopamineCrashStartTime.isEmpty
                                              ? '--:--'
                                              : dopamineCrashStartTime,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      OutlinedButton(
                                        onPressed: () async {
                                          await setTodayCrashTimeField(
                                            'dopamineCrashStartTime',
                                            'When did the dopamine crash start?',
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Set'),
                                      ),
                                      if (dopamineCrashStartTime.isNotEmpty)
                                        TextButton(
                                          onPressed: () async {
                                            await clearTodayCrashTimeField(
                                              'dopamineCrashStartTime',
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text('Clear'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 90,
                                        child: Text(
                                          'Crash end:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 52,
                                        child: Text(
                                          dopamineCrashEndTime.isEmpty
                                              ? '--:--'
                                              : dopamineCrashEndTime,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      OutlinedButton(
                                        onPressed: () async {
                                          await setTodayCrashTimeField(
                                            'dopamineCrashEndTime',
                                            'When did the dopamine crash end?',
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Set'),
                                      ),
                                      if (dopamineCrashEndTime.isNotEmpty)
                                        TextButton(
                                          onPressed: () async {
                                            await clearTodayCrashTimeField(
                                              'dopamineCrashEndTime',
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text('Clear'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  buildCrashSymptomSection(
                                    title: 'Core symptoms',
                                    options: dopamineCrashSymptomOptions,
                                    selected: dopamineCrashSymptoms,
                                    field: 'dopamineCrashSymptoms',
                                  ),
                                  const SizedBox(height: 10),
                                  buildCrashSymptomSection(
                                    title: 'Additional symptoms',
                                    options:
                                        dopamineCrashAdditionalSymptomOptions,
                                    selected: dopamineCrashAdditionalSymptoms,
                                    field: 'dopamineCrashSymptomsAdditional',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildCaptureInboxSection() {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inboxCaptureController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) async {
                          await addInboxEntry();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Quick capture a thought...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: addInboxEntry,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        Widget buildOutlookSection() {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Outlook (next $outlookLookAheadDays ${outlookLookAheadDays == 1 ? 'day' : 'days'})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FutureBuilder<List<OutlookCalendarEvent>>(
                  future:
                      upcomingOutlookEventsFuture ??
                      _loadUpcomingOutlookEvents(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Loading Outlook events...'),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Outlook not connected yet. Use the cloud sync button above to link permissions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      );
                    }

                    final events =
                        snapshot.data ?? const <OutlookCalendarEvent>[];
                    if (events.isEmpty) {
                      return Text(
                        'No upcoming calendar events.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      );
                    }

                    final eventListMaxHeight = isNarrow ? 220.0 : 280.0;
                    final eventWidgets = <Widget>[];
                    DateTime? previousEventDay;

                    for (final event in events) {
                      final eventStart = event.start?.toLocal();
                      if (eventStart != null) {
                        final currentDay = DateTime(
                          eventStart.year,
                          eventStart.month,
                          eventStart.day,
                        );

                        if (previousEventDay == null ||
                            currentDay != previousEventDay) {
                          if (eventWidgets.isNotEmpty) {
                            eventWidgets.add(const SizedBox(height: 2));
                          }
                          eventWidgets.add(_buildOutlookDayDivider(currentDay));
                          previousEventDay = currentDay;
                        }
                      }

                      eventWidgets.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.subject,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatOutlookEventTimeRange(event),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: eventListMaxHeight,
                      child: SingleChildScrollView(
                        child: Column(children: eventWidgets),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        Widget buildTaskTab(String label) {
          final isSelected = label == selectedTaskCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  selectedTaskCategory = label;
                });
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: isSelected
                    ? Colors.blue.shade600
                    : Colors.white,
                foregroundColor: isSelected
                    ? Colors.white
                    : Colors.grey.shade800,
                side: BorderSide(
                  color: isSelected
                      ? Colors.blue.shade600
                      : Colors.grey.shade300,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        Widget buildTaskPanel({
          required String title,
          required Color color,
          required Widget headerAction,
          required Widget body,
          bool showHeader = true,
        }) {
          return Card(
            color: color,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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

        Widget buildTaskPanels(int index) {
          final task = tasks[index];
          final selectedTab = taskDetailTabByTask[task] ?? 0;

          Widget buildDetailTabButton({
            required String label,
            required int tabIndex,
          }) {
            final isSelected = selectedTab == tabIndex;

            return OutlinedButton(
              onPressed: () async {
                await selectTaskDetailTab(index, tabIndex);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor: isSelected
                    ? Colors.blue.shade600
                    : Colors.white,
                foregroundColor: isSelected
                    ? Colors.white
                    : Colors.grey.shade800,
                side: BorderSide(
                  color: isSelected
                      ? Colors.blue.shade600
                      : Colors.grey.shade300,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            );
          }

          final subtasksBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.subtasks.isNotEmpty)
                Column(
                  children: List.generate(task.subtasks.length, (subIndex) {
                    return SubtaskTile(
                      index: subIndex + 1,
                      subtask: task.subtasks[subIndex],
                      onChanged: (value) {
                        toggleSubtask(index, subIndex, value);
                      },
                      onMoveUp: () {
                        moveSubtaskUp(index, subIndex);
                      },
                      onMoveDown: () {
                        moveSubtaskDown(index, subIndex);
                      },
                      onEdit: () {
                        editSubtask(index, subIndex);
                      },
                      onDelete: () {
                        showDeleteSubtaskConfirmation(index, subIndex);
                      },
                    );
                  }),
                ),
              const SizedBox(height: 10),
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.5,
                      child: TextField(
                        controller: getSubtaskController(index),
                        style: const TextStyle(fontSize: 10),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) async {
                          await addSubtaskFromInput(index);
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
                          await addSubtaskFromInput(index);
                        },
                        child: const Text(
                          'Add',
                          style: TextStyle(fontSize: 10),
                        ),
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
                            controller: getSubtaskController(index),
                            style: const TextStyle(fontSize: 10),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) async {
                              await addSubtaskFromInput(index);
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
                            await addSubtaskFromInput(index);
                          },
                          child: const Text(
                            'Add',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          handleGenerateTaskSubtasks(index);
                        },
                  icon: Icon(
                    Icons.psychology_alt_outlined,
                    color: isGenerating ? Colors.grey : Colors.blue,
                    size: 18,
                  ),
                  label: const Text(
                    'Auto generate',
                    style: TextStyle(fontSize: 10),
                  ),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
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
              starterLine(
                label: 'First tiny step',
                value: task.starterTinyStep,
              ),
              starterLine(
                label: 'Setup checklist',
                value: task.starterSetupChecklist,
              ),
              starterLine(
                label: 'If stuck, do this',
                value: task.starterIfStuck,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: isGenerating
                        ? null
                        : () async {
                            await generateStarterScript(index);
                          },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate starter script'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      editStarterScript(index);
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Edit starter script'),
                  ),
                ],
              ),
            ],
          );

          return buildTaskPanel(
            title: selectedTab == 0
                ? 'Subtasks'
                : selectedTab == 1
                ? 'ADHD this'
                : 'Starter script',
            color: selectedTab == 1
                ? Colors.blue.shade50
                : Colors.grey.shade100,
            headerAction: const SizedBox.shrink(),
            showHeader: false,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    buildDetailTabButton(label: 'Subtasks', tabIndex: 0),
                    const SizedBox(width: 6),
                    buildDetailTabButton(label: 'ADHD this', tabIndex: 1),
                    const SizedBox(width: 6),
                    buildDetailTabButton(label: 'Starter script', tabIndex: 2),
                    const Spacer(),
                    if (selectedTab == 1 && task.aiSubtasks.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Delete ADHD this',
                        onPressed: () {
                          confirmDeleteStarterSteps(index);
                        },
                      ),
                    if (selectedTab == 1)
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: isGenerating ? Colors.grey : Colors.blue,
                        ),
                        tooltip: 'Regenerate ADHD this',
                        onPressed: isGenerating
                            ? null
                            : () {
                                createSubtasks(index, defaultStarterStepCount);
                              },
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
          );
        }

        Widget buildTaskList() {
          if (visibleTaskIndices.isEmpty) {
            return Center(
              child: Text(
                selectedTaskCategory == 'All tasks'
                    ? 'No tasks yet.'
                    : 'No tasks in this category.',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }

          Widget buildTaskListItem(BuildContext context, int visibleIndex) {
            final taskIndex = visibleTaskIndices[visibleIndex];
            final task = tasks[taskIndex];
            final baseAccentColor = getPriorityColor(task.priority);
            final accentColor = baseAccentColor.withAlpha(
              task.done ? 110 : 180,
            );
            final cardColor = task.done ? Colors.grey.shade100 : Colors.white;
            final borderColor = task.done
                ? Colors.grey.shade300
                : accentColor.withAlpha(150);

            return Card(
              key: ValueKey('${taskIndex}_${task.task}'),
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
              color: cardColor,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 5, color: accentColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TaskTile(
                            task: task,
                            dueDateText: formatDueDate(task.dueDate),
                            progress: RecommendationService.getTaskProgress(
                              task,
                            ),
                            compactView: compactView || !task.expanded,
                            categories: categories,
                            category: task.category,
                            priority: task.priority,
                            isGenerating: isGenerating,
                            onToggle: (value) {
                              toggleTask(taskIndex, value);
                            },
                            reorderableIndex: taskIndex,
                            onPriorityChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                tasks[taskIndex].priority = value;
                              });
                              saveTasks();
                            },
                            onDueDate: () {
                              setDueDate(taskIndex);
                            },
                            onCategoryChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                tasks[taskIndex].category = value;
                              });
                              saveTasks();
                            },
                            onToggleExpanded: () {
                              toggleExpanded(taskIndex);
                            },
                            onEdit: () {
                              editTask(taskIndex);
                            },
                            onDelete: () {
                              showDeleteConfirmation(taskIndex);
                            },
                          ),
                          if (!compactView && task.expanded)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: buildTaskPanels(taskIndex),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (selectedTaskSortMode != TaskListSortMode.manual) {
            return ListView.builder(
              controller: taskListScrollController,
              padding: EdgeInsets.zero,
              itemCount: visibleTaskIndices.length,
              itemBuilder: buildTaskListItem,
            );
          }

          return ReorderableListView.builder(
            scrollController: taskListScrollController,
            padding: EdgeInsets.zero,
            buildDefaultDragHandles: false,
            itemCount: visibleTaskIndices.length,
            onReorderItem: (oldIndex, newIndex) async {
              setState(() {
                reorderVisibleTasks(oldIndex, newIndex, visibleTaskIndices);
              });

              await saveTasks();
            },
            itemBuilder: buildTaskListItem,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            if (showOverview)
              TasksOverviewSection(
                isNarrow: isNarrow,
                priorityCardsTotalWidth: priorityCardsTotalWidth,
                priorityCardCount: priorityCardCount,
                priorityCardSpacing: priorityCardSpacing,
                getTopTasks: getTopTasks,
                buildPriorityCard: buildPriorityCard,
                buildCaptureInboxSection: buildCaptureInboxSection(),
                buildOutlookSection: buildOutlookSection(),
                buildDailyCheckinSection: buildDailyCheckinSection(),
              ),
            if (showTaskList)
              TaskListView(
                showOverview: showOverview,
                showTaskList: showTaskList,
                isGenerating: isGenerating,
                priorityCardsTotalWidth: priorityCardsTotalWidth,
                taskTabsScrollController: taskTabsScrollController,
                taskTabs: taskTabs.map(buildTaskTab).toList(),
                buildTaskListContent: buildTaskList,
                hasAnyExpandedTask: hasAnyExpandedTask,
                taskSortLabel: getTaskSortLabel(),
                onSelectTaskSortMode: (mode) {
                  setState(() {
                    selectedTaskSortMode = switch (mode) {
                      'dueDate' => TaskListSortMode.dueDate,
                      'priority' => TaskListSortMode.priority,
                      _ => TaskListSortMode.manual,
                    };
                  });
                },
                onToggleExpandAll: () async {
                  if (hasAnyExpandedTask) {
                    await collapseAllTaskTiles();
                  } else {
                    await expandAllTaskTiles();
                  }
                },
              ),
          ],
        );
      },
    );
  }

  Widget buildCountdownView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final timerRunning = focusTimer?.isActive == true;
        final contentWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : kWideContentWidth.clamp(0, constraints.maxWidth).toDouble();
        final selectedDurationSeconds = getSelectedFocusTimerDuration()
            .inSeconds
            .toDouble();
        final remainingSeconds = remainingFocusTime.inSeconds.toDouble();
        final progress = selectedDurationSeconds <= 0
            ? 0.0
            : (remainingSeconds / selectedDurationSeconds).clamp(0.0, 1.0);
        final completedPercent = ((1.0 - progress) * 100).clamp(0, 100).round();
        final accentColor = timerRunning
            ? const Color(0xFF0D8A6A)
            : const Color(0xFF3C64D6);
        final phaseLabel = timerRunning
            ? (progress > 0.5 ? 'Settling into focus' : 'Final stretch')
            : 'Ready when you are';
        final digitalFontSize = contentWidth < 420 ? 58.0 : 84.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 480.0;

        return CountdownView(
          contentWidth: contentWidth,
          availableHeight: availableHeight,
          timerRunning: timerRunning,
          completedPercent: completedPercent,
          accentColor: accentColor,
          phaseLabel: phaseLabel,
          digitalFontSize: digitalFontSize,
          timerCompletionCueActive: timerCompletionCueActive,
          remainingFocusTime: remainingFocusTime,
          selectedFocusTimerSeconds: selectedFocusTimerSeconds,
          selectedFocusTimerMinutes: selectedFocusTimerMinutes,
          focusTimerPresets: focusTimerPresets,
          formatFocusTime: formatFocusTime,
          setFocusTimerPreset: setFocusTimerPreset,
          setCustomFocusTimer: setCustomFocusTimer,
          startFocusTimer: startFocusTimer,
          stopFocusTimer: stopFocusTimer,
          resetFocusTimer: resetFocusTimer,
        );
      },
    );
  }

  Widget buildInsightsView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : kWideContentWidth.clamp(0, constraints.maxWidth).toDouble();

        final records = dailyCheckinsByDate.entries
            .map((entry) {
              final parsedDate = DateTime.tryParse(entry.key);
              if (parsedDate == null) {
                return null;
              }

              final raw = Map<String, dynamic>.from(entry.value);
              final focus = parseScoreField(raw, 'focus');
              final restlessness = parseScoreField(raw, 'restlessness');
              final impulsivity = parseScoreField(raw, 'impulsivity');
              final overwhelm = parseScoreField(raw, 'overwhelm');
              final emotionalRegulation = parseScoreField(
                raw,
                'emotionalRegulation',
                legacyValue: raw['emotional regulation'],
              );
              final workTaskScore = parseScoreField(
                raw,
                'workTaskScore',
                legacyValue: raw['workProductivity'],
              );
              final homeTaskScore = parseScoreField(
                raw,
                'homeTaskScore',
                legacyValue: raw['homeProductivity'],
              );

              final crashCore = parseStringList(raw['dopamineCrashSymptoms']);
              final crashExtra = parseStringList(
                raw['dopamineCrashSymptomsAdditional'],
              );
              final crashStart =
                  (raw['dopamineCrashStartTime'] ??
                          raw['dopamineCrashTime'] ??
                          '')
                      .toString();
              final crashEnd = (raw['dopamineCrashEndTime'] ?? '').toString();

              return {
                'date': parsedDate,
                'focus': focus,
                'restlessness': restlessness,
                'impulsivity': impulsivity,
                'overwhelm': overwhelm,
                'emotionalRegulation': emotionalRegulation,
                'workTaskScore': workTaskScore,
                'homeTaskScore': homeTaskScore,
                'contextTags': parseStringList(raw['contextTags']),
                'crashSymptomCount': crashCore.length + crashExtra.length,
                'hasCrash':
                    crashStart.trim().isNotEmpty ||
                    crashEnd.trim().isNotEmpty ||
                    crashCore.isNotEmpty ||
                    crashExtra.isNotEmpty,
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        records.sort((a, b) {
          final aDate = a['date'] as DateTime;
          final bDate = b['date'] as DateTime;
          return aDate.compareTo(bDate);
        });

        return InsightsView(records: records, contentWidth: contentWidth);
      },
    );
  }

  Widget buildNotesView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : kWideContentWidth.clamp(0, constraints.maxWidth).toDouble();

        return NotesView(
          contentWidth: contentWidth,
          noteEntries: noteEntries,
          selectedNoteId: selectedNoteId,
          inboxEntries: inboxEntries,
          displayNoteTitle: displayNoteTitle,
          notePreview: notePreview,
          onAddNote: addNoteEntry,
          onDeleteSelectedNote: selectedNote == null
              ? () {}
              : () {
                  deleteSelectedNote();
                },
          onSelectNote: (noteId) async {
            selectNoteEntry(noteId);
          },
          onEditNote: (entry) async {
            await openNoteEntryDialog(existing: entry);
          },
          onDeleteNote: (noteId) async {
            await deleteNoteEntryById(noteId);
          },
          onEditInboxEntry: (index) async {
            await editInboxEntry(index);
          },
          onConvertInboxEntryToTask: (index) async {
            await convertInboxEntryToTask(index);
          },
          onRemoveInboxEntry: (index) async {
            await removeInboxEntry(index);
          },
        );
      },
    );
  }

  Widget buildFirebaseSyncStatusBadge() {
    final (
      Color backgroundColor,
      Color foregroundColor,
      IconData icon,
    ) = switch (firebaseSyncBadgeState) {
      FirebaseSyncBadgeState.connected => (
        const Color(0xFFE6F6EF),
        const Color(0xFF0F7A4F),
        Icons.cloud_done,
      ),
      FirebaseSyncBadgeState.failing => (
        const Color(0xFFFFECE8),
        const Color(0xFFB0472A),
        Icons.cloud_off,
      ),
      FirebaseSyncBadgeState.disabled => (
        const Color(0xFFEDEDED),
        const Color(0xFF666666),
        Icons.cloud_queue,
      ),
      FirebaseSyncBadgeState.checking => (
        const Color(0xFFE8EEFF),
        const Color(0xFF3C64D6),
        Icons.cloud_sync,
      ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: handleCloudSyncStatusTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foregroundColor.withAlpha(90)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              firebaseSyncStatusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(kPageHorizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeHeader(
                tabs: MainSectionTabs(
                  selectedIndex: selectedMainSectionIndex,
                  onSelectIndex: (index) {
                    setState(() {
                      selectedMainSectionIndex = index;
                    });
                  },
                ),
                syncBadge: buildFirebaseSyncStatusBadge(),
                onBackupTap: openBackupRecoveryDialog,
                onOutlookTap: handleOutlookLink,
                onSettingsTap: openSettings,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: MainContentView(
                  selectedMainSectionIndex: selectedMainSectionIndex,
                  buildTasksView: buildTasksView,
                  buildCountdownView: buildCountdownView,
                  buildInsightsView: buildInsightsView,
                  buildNotesView: buildNotesView,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: selectedMainSectionIndex == 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  kPageHorizontalPadding,
                  0,
                  kPageHorizontalPadding,
                  kPageHorizontalPadding,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;
                    final contentWidth = constraints.maxWidth < 720
                        ? constraints.maxWidth
                        : kWideContentWidth
                              .clamp(0, constraints.maxWidth)
                              .toDouble();

                    return Row(
                      children: [
                        SizedBox(
                          width: contentWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  offset: const Offset(0, -2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: isNarrow
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            TextField(
                                              controller: taskController,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) async {
                                                await addTask();
                                              },
                                              decoration: InputDecoration(
                                                labelText: 'Add a new task',
                                                border:
                                                    const OutlineInputBorder(),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 12,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            ElevatedButton(
                                              onPressed: addTask,
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: taskController,
                                                textInputAction:
                                                    TextInputAction.done,
                                                onSubmitted: (_) async {
                                                  await addTask();
                                                },
                                                decoration: InputDecoration(
                                                  labelText: 'Add a new task',
                                                  border:
                                                      const OutlineInputBorder(),
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 12,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton(
                                              onPressed: addTask,
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }
}
