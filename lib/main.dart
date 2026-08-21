import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'models/note_entry.dart';
import 'models/task.dart';
import 'models/activity_recommendation.dart';
import 'services/storage_service.dart';
import 'services/gemini_service.dart';
import 'services/recommendation_service.dart';
import 'services/one_drive_sync_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/ics_import_service.dart';
import 'services/ics_file_loader.dart';
import 'services/outlook_link_coordinator.dart';
import 'services/outlook_formatting_service.dart';
import 'services/work_calendar_auto_import_loader.dart';
import 'dialogs/step_count_dialog.dart';
import 'dialogs/edit_task_dialog.dart';
import 'dialogs/edit_subtask_dialog.dart';
import 'dialogs/add_subtask_dialog.dart';
import 'dialogs/task_field_dialogs.dart';
import 'settings_page.dart';
import 'widgets/backup_recovery_dialog.dart';
import 'widgets/countdown_view.dart';
import 'widgets/home_header.dart';
import 'widgets/insights_section.dart';
import 'widgets/main_content_view.dart';
import 'widgets/main_section_tabs.dart';
import 'widgets/notes_section.dart';
import 'widgets/day_planner_section.dart';
import 'widgets/activity_history_page.dart';
import 'services/day_planner_service.dart';
import 'services/activity_tracking_service.dart';
import 'services/planner_execution_service.dart';
import 'widgets/outlook_section.dart';
import 'widgets/priority_task_card.dart';
import 'widgets/quick_capture_section.dart';
import 'widgets/symptom_tracker_section.dart';
import 'widgets/task_composer_section.dart';
import 'widgets/task_list_section.dart';
import 'widgets/task_panels_section.dart';
import 'widgets/task_tab_button.dart';
import 'widgets/tasks_view_section.dart';

const double kPageHorizontalPadding = 16;
const double kWidePriorityCardWidth = 202;
const double kWidePriorityCardsSpacingTotal = 12;
const double kPriorityCardWidthReduction = 2;
const double kWideContentWidth =
    (kWidePriorityCardWidth * 3) + kWidePriorityCardsSpacingTotal + 16;
const double kDesktopMinWindowWidth =
    kWideContentWidth + (kPageHorizontalPadding * 2) + 20;
const double kDesktopDefaultWindowWidth = 1280;
const double kDesktopDefaultWindowHeight = 900;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseSyncService.initializeIfAvailable();

  final isWindowsDesktop =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  final isDesktop =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (isDesktop) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      minimumSize: Size(kDesktopMinWindowWidth, 680),
      size: Size(kDesktopDefaultWindowWidth, kDesktopDefaultWindowHeight),
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      if (isWindowsDesktop) {
        await windowManager.maximize();
      }
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
    'Out and about',
    'Holiday',
    'Sick',
    'Bad sleep',
    'Good sleep',
    'Social day',
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
  List<ActivityLogEntry> activityLogs = [];
  WeeklyActivityTotals weeklyActivityTotals = const WeeklyActivityTotals();
  Map<String, Map<String, dynamic>> dailyCheckinsByDate = {};
  String? selectedNoteId;
  List<String> categories = ['None'];
  String starterStepPrompt = GeminiService.defaultStarterStepPromptTemplate;
  String taskSubtaskPrompt = GeminiService.defaultSubtaskPromptTemplate;
  String selectedTaskCategory = 'All tasks';
  static const int defaultStarterStepCount = 3;
  static const List<int> focusTimerPresets = [5, 10, 25, 50];

  bool isGenerating = false;
  bool groupTasksByPriority = false;
  int? selectedTaskPaneIndex;
  TaskListSortMode selectedTaskSortMode = TaskListSortMode.manual;
  int selectedMainSectionIndex = 0;
  int? pendingTaskScrollIndex;
  int priorityCardCount = 3;
  int outlookLookAheadDays = 1;
  int plannerDayOffset = 0;
  int plannerWorkdayStartMinutes = 9 * 60;
  int plannerWorkdayEndMinutes = 17 * 60;
  bool prioritizeWorkOnWeekdays = true;
  bool gymAvailable = false;
  bool wfhAvailable = false;
  bool eveningAvailable = false;
  bool showWorkInPlanner = true;
  bool showHomeInPlanner = true;
  bool showPlannerInPlanner = true;
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
  bool hasShownOutlookConfigWarning = false;
  FirebaseSyncBadgeState firebaseSyncBadgeState =
      FirebaseSyncBadgeState.checking;
  String firebaseSyncStatusText = 'Cloud...';
  ImportedOutlookEventsSummary importedOutlookSummary =
      const ImportedOutlookEventsSummary(
        lastImportedAt: null,
        rangeStart: null,
        rangeEnd: null,
        eventCount: 0,
      );

  @override
  void initState() {
    super.initState();
    upcomingOutlookEventsFuture = _loadUpcomingOutlookEvents();
    unawaited(_refreshFirebaseSyncStatus());
    unawaited(_maybeCompleteOutlookAuthFromCurrentUrl());
    unawaited(_runStartupLoad());
  }

  Future<void> _runStartupLoad() async {
    await loadTasks().catchError((_) {});
    await _loadImportedOutlookSummary();
  }

  Future<void> _loadImportedOutlookSummary() async {
    final summary = await StorageService.loadImportedOutlookEventsSummary();
    if (!mounted) {
      return;
    }

    setState(() {
      importedOutlookSummary = summary;
    });
  }

  Future<List<OutlookCalendarEvent>> _loadUpcomingOutlookEvents() {
    return StorageService.getUpcomingOutlookEvents(
      lookAhead: Duration(days: outlookLookAheadDays),
      maxItems: (outlookLookAheadDays * 10).clamp(10, 50).toInt(),
    );
  }

  void _showOutlookConfigWarningIfNeeded() {
    if (hasShownOutlookConfigWarning || StorageService.isOutlookConfigured) {
      return;
    }

    hasShownOutlookConfigWarning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await showCopyableErrorDialog(
        'Outlook Setup Needed',
        StorageService.outlookConfigurationHelpText,
      );
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
      final loadedActivityLogs = await ActivityTrackingService.loadLogs();
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
      final loadedPrioritizeWorkOnWeekdays =
          await StorageService.loadPrioritizeWorkOnWeekdays();
      final loadedGymAvailable = await StorageService.loadGymAvailable();
      final loadedWfhAvailable = await StorageService.loadWfhAvailable();
      final loadedEveningAvailable =
          await StorageService.loadEveningAvailable();
      final loadedPlannerWorkdayStartMinutes =
          await StorageService.loadPlannerWorkdayStartMinutes();
      final loadedPlannerWorkdayEndMinutes =
          await StorageService.loadPlannerWorkdayEndMinutes();

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
      )..remove('Exercise day');
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
      final resolvedPrioritizeWorkOnWeekdays =
          loadedPrioritizeWorkOnWeekdays ?? true;
      final resolvedGymAvailable = loadedGymAvailable ?? false;
      final resolvedWfhAvailable = loadedWfhAvailable ?? false;
      final resolvedEveningAvailable = loadedEveningAvailable ?? false;
      final resolvedPlannerWorkdayStartMinutes =
          loadedPlannerWorkdayStartMinutes ?? 9 * 60;
      final resolvedPlannerWorkdayEndMinutes =
          loadedPlannerWorkdayEndMinutes ?? 17 * 60;

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
        plannerDayOffset = plannerDayOffset.clamp(
          0,
          (resolvedOutlookLookAheadDays - 1).clamp(0, 31),
        );
        prioritizeWorkOnWeekdays = resolvedPrioritizeWorkOnWeekdays;
        gymAvailable = resolvedGymAvailable;
        wfhAvailable = resolvedWfhAvailable;
        eveningAvailable = resolvedEveningAvailable;
        plannerWorkdayStartMinutes = resolvedPlannerWorkdayStartMinutes;
        plannerWorkdayEndMinutes = resolvedPlannerWorkdayEndMinutes;
        tasks = loadedTasks;
        activityLogs = loadedActivityLogs;
        weeklyActivityTotals = ActivityTrackingService.calculateWeeklyTotals(
          loadedActivityLogs,
        );
        inboxEntries = loadedInboxEntries;
        noteEntries = loadedNoteEntries;
        dailyCheckinsByDate = loadedDailyCheckinsByDate;
        selectedNoteId = null;
        normalizeTaskCategories();
        ensureSelectedTaskCategoryIsValid();
        syncSubtaskControllers();
      });
      syncNoteControllers();

      _showOutlookConfigWarningIfNeeded();
      _refreshUpcomingOutlookEvents();
      unawaited(_refreshFirebaseSyncStatus());
    } catch (error, stackTrace) {
      debugPrint('Failed to load tasks: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Cloud sync connection is healthy.'
                : 'Cloud sync is not connected right now.',
          ),
        ),
      );
    }
  }

  int? _getCurrentSubtaskIndex(Task task) {
    final index = task.subtasks.indexWhere((subtask) => subtask.done != true);
    return index == -1 ? null : index;
  }

  Future<void> handleCloudSyncStatusTap() async {
    await _refreshFirebaseSyncStatus(
      triggerSyncAttempt: true,
      showSnackBar: true,
    );
  }

  Future<void> openBackupRecoveryDialog() async {
    final history = await StorageService.loadBackupHistory();
    final backupPreviews = await Future.wait(
      history.map(StorageService.getBackupRecoveryPreviewForBackupEntry),
    );

    if (!mounted) {
      return;
    }

    await BackupRecoveryDialog.show(
      context: context,
      history: history,
      backupPreviews: backupPreviews,
      onRestore: (backupEntry) async {
        await StorageService.restoreBackupEntryState(backupEntry);
        await loadTasks();
        await _loadImportedOutlookSummary();
        _refreshUpcomingOutlookEvents();
      },
      onMerge:
          (selectedTasks, selectedNoteEntries, selectedInboxEntries) async {
            await StorageService.mergeMissingBackupEntries(
              selectedTasks: selectedTasks,
              selectedNoteEntries: selectedNoteEntries,
              selectedInboxEntries: selectedInboxEntries,
            );
            await loadTasks();
            await _loadImportedOutlookSummary();
            _refreshUpcomingOutlookEvents();
          },
    );
  }

  Future<void> importIcsCalendarFile() async {
    try {
      String? content;
      String status = 'No calendar file was selected.';

      if (kIsWeb) {
        content = await IcsFileLoader.pickAndReadContent();
      } else {
        final loadResult =
            await WorkCalendarAutoImportLoader.loadWithDiagnostics();
        content = loadResult.content;
        status = loadResult.status;

        if (content == null || content.trim().isEmpty) {
          content = await IcsFileLoader.pickAndReadContent();
          status = content == null || content.trim().isEmpty
              ? loadResult.status
              : 'Loaded ICS content from selected file.';
        }
      }

      if (content == null || content.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(status)));
        return;
      }

      await _importIcsCalendarContent(content, forceCalendarSource: 'work');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open the selected file: $error')),
      );
    }
  }

  Future<void> clearImportedOutlookEvents() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Clear imported calendar data'),
              content: const Text(
                'This will remove all imported Outlook/ICS events from this app. Continue?',
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
                  child: const Text(
                    'Clear',
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

    await StorageService.saveImportedOutlookEvents(const []);
    await _loadImportedOutlookSummary();
    if (!mounted) {
      return;
    }
    setState(() {
      upcomingOutlookEventsFuture = _loadUpcomingOutlookEvents();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imported Outlook data cleared.')),
    );
  }

  Future<void> _importIcsCalendarContent(
    String? content, {
    String? forceCalendarSource,
  }) async {
    if (content == null || content.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected file was empty.')),
      );
      return;
    }

    final parsedEvents = IcsImportService.parseEvents(content);
    final importedEvents = forceCalendarSource == null
        ? parsedEvents
        : parsedEvents
              .map(
                (event) => OutlookCalendarEvent(
                  id: event.id,
                  subject: event.subject,
                  start: event.start,
                  end: event.end,
                  isAllDay: event.isAllDay,
                  calendarSource: forceCalendarSource,
                ),
              )
              .toList();

    if (importedEvents.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No calendar events were found in that file.'),
        ),
      );
      return;
    }

    debugPrint('Imported ${importedEvents.length} events from ICS content');
    final existingImportedEvents =
        await StorageService.loadImportedOutlookEvents();
    final baselineImportedEvents = forceCalendarSource == null
        ? existingImportedEvents
        : existingImportedEvents
              .where(
                (event) =>
                    event.calendarSource != forceCalendarSource &&
                    event.calendarSource != 'home',
              )
              .toList();
    final importResult = _applyImportedEventsBySource(
      baselineImportedEvents,
      importedEvents,
    );

    await StorageService.saveImportedOutlookEvents(importResult.eventsToSave);
    await _loadImportedOutlookSummary();
    if (!mounted) return;
    setState(() {
      upcomingOutlookEventsFuture = _loadUpcomingOutlookEvents();
    });

    final movedSuffix = importResult.movedCount > 0
        ? ' ${importResult.movedCount} moved.'
        : '';
    final removedSuffix = importResult.removedCount > 0
        ? ' ${importResult.removedCount} removed.'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${importedEvents.length} event(s).$movedSuffix$removedSuffix',
        ),
      ),
    );
  }

  ({List<OutlookCalendarEvent> eventsToSave, int movedCount, int removedCount})
  _applyImportedEventsBySource(
    List<OutlookCalendarEvent> existing,
    List<OutlookCalendarEvent> incoming,
  ) {
    final incomingBySource = <String, List<OutlookCalendarEvent>>{};
    for (final event in incoming) {
      incomingBySource.putIfAbsent(event.calendarSource, () => []).add(event);
    }

    var movedCount = 0;
    var removedCount = 0;

    for (final sourceEntry in incomingBySource.entries) {
      final source = sourceEntry.key;
      final priorForSource = existing
          .where((event) => event.calendarSource == source)
          .toList();
      final nextForSource = sourceEntry.value;

      final priorByKey = <String, OutlookCalendarEvent>{
        for (final event in priorForSource)
          _calendarEventIdentityKey(event): event,
      };
      final nextByKey = <String, OutlookCalendarEvent>{
        for (final event in nextForSource)
          _calendarEventIdentityKey(event): event,
      };

      for (final entry in nextByKey.entries) {
        final before = priorByKey[entry.key];
        if (before == null) {
          continue;
        }

        final after = entry.value;
        final startChanged = !_sameMoment(before.start, after.start);
        final endChanged = !_sameMoment(before.end, after.end);
        if (startChanged || endChanged) {
          movedCount += 1;
        }
      }

      for (final priorKey in priorByKey.keys) {
        if (!nextByKey.containsKey(priorKey)) {
          removedCount += 1;
        }
      }
    }

    final replacedSources = incomingBySource.keys.toSet();
    final retainedExisting = existing
        .where((event) => !replacedSources.contains(event.calendarSource))
        .toList();

    return (
      eventsToSave: [...retainedExisting, ...incoming],
      movedCount: movedCount,
      removedCount: removedCount,
    );
  }

  String _calendarEventIdentityKey(OutlookCalendarEvent event) {
    final id = event.id.trim().toLowerCase();
    if (id.isNotEmpty && !id.startsWith('event-')) {
      return 'id:$id';
    }

    final subject = event.subject.trim().toLowerCase();
    return 'subject:$subject|allDay:${event.isAllDay}';
  }

  bool _sameMoment(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }

  void _refreshUpcomingOutlookEvents() {
    setState(() {
      upcomingOutlookEventsFuture = _loadUpcomingOutlookEvents();
    });
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

  Set<ActivityPillar> completedActivityPillarsToday() {
    final today = DateTime.now();
    return activityLogs
        .where((entry) {
          final completedAt = entry.completedAt.toLocal();
          return completedAt.year == today.year &&
              completedAt.month == today.month &&
              completedAt.day == today.day;
        })
        .map((entry) => entry.pillar)
        .toSet();
  }

  int getDaysSinceLastMobility() {
    final mobilityLogs =
        activityLogs
            .where((entry) => entry.pillar == ActivityPillar.mobility)
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (mobilityLogs.isEmpty) return 999;
    final last = mobilityLogs.first.completedAt.toLocal();
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(last.year, last.month, last.day)).inDays;
  }

  Future<void> completeActivityRecommendation(
    ActivityRecommendation recommendation,
  ) async {
    final entry = ActivityLogEntry(
      id: 'activity-${DateTime.now().microsecondsSinceEpoch}',
      pillar: recommendation.pillar,
      completedAt: DateTime.now(),
      source: ActivitySource.recommendation,
      minutes:
          recommendation.pillar == ActivityPillar.walking ||
              recommendation.pillar == ActivityPillar.standing
          ? recommendation.estimatedDuration.inMinutes
          : null,
    );
    final nextLogs = [...activityLogs, entry];
    setState(() {
      activityLogs = nextLogs;
      weeklyActivityTotals = ActivityTrackingService.calculateWeeklyTotals(
        nextLogs,
      );
    });
    await StorageService.saveActivityLogs(nextLogs);
  }

  Future<void> saveActivityLogsFromHistory(
    List<ActivityLogEntry> nextLogs,
  ) async {
    setState(() {
      activityLogs = List<ActivityLogEntry>.from(nextLogs);
      weeklyActivityTotals = ActivityTrackingService.calculateWeeklyTotals(
        activityLogs,
      );
    });
    await StorageService.saveActivityLogs(activityLogs);
  }

  Future<void> openActivityHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivityHistoryPage(
          initialLogs: activityLogs,
          onLogsChanged: saveActivityLogsFromHistory,
        ),
      ),
    );
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
    var draftTitle = existing?.title ?? '';
    var draftContent = existing?.content ?? '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existing == null
                ? 'New note'
                : existing.kind == 'recipe'
                ? 'Edit recipe'
                : 'Edit note',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: existing?.title ?? '',
                  autofocus: true,
                  maxLines: 1,
                  onChanged: (value) {
                    draftTitle = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: existing?.content ?? '',
                  minLines: 4,
                  maxLines: 8,
                  onChanged: (value) {
                    draftContent = value;
                  },
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
                  'title': draftTitle,
                  'content': draftContent,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

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

  Future<void> addNoteEntryWithTitle(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    setState(() {
      final newEntry = NoteEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        content: '',
        updatedAtUtc: now,
        kind: 'note',
      );
      noteEntries.insert(0, newEntry);
      selectedNoteId = newEntry.id;
    });

    syncNoteControllers();
    await persistNoteEntries();
  }

  Future<void> addRecipeEntryWithTitle(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    setState(() {
      final newEntry = NoteEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        content: '',
        updatedAtUtc: now,
        kind: 'recipe',
      );
      noteEntries.insert(0, newEntry);
      selectedNoteId = newEntry.id;
    });

    syncNoteControllers();
    await persistNoteEntries();
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

  Future<void> convertNoteEntryToTask(String noteId) async {
    final note = noteEntries.where((entry) => entry.id == noteId).firstOrNull;
    if (note == null || note.kind == 'recipe') {
      return;
    }

    final taskTitle = displayNoteTitle(note).trim();
    if (taskTitle.isEmpty) {
      return;
    }

    final taskCategory = categories.isNotEmpty ? categories.first : 'None';

    setState(() {
      tasks.add(
        Task(
          task: taskTitle,
          done: false,
          expanded: false,
          priority: 'medium',
          category: taskCategory,
        ),
      );
      subtaskControllers.add(TextEditingController());
      noteEntries.removeWhere((entry) => entry.id == noteId);
      if (selectedNoteId == noteId) {
        selectedNoteId = null;
      }
    });

    syncNoteControllers();
    await saveTasks();
    await persistNoteEntries();
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
      tasks[taskIndex].expanded = true;
      selectedTaskPaneIndex = taskIndex;
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
      plannerDayOffset = plannerDayOffset.clamp(
        0,
        (updatedSettings.outlookLookAheadDays - 1).clamp(0, 31),
      );
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
    await OutlookLinkCoordinator.handleOutlookLink(
      context: context,
      outlookLookAheadDays: outlookLookAheadDays,
      refreshUpcomingOutlookEvents: () async {
        _refreshUpcomingOutlookEvents();
      },
      showCopyableErrorDialog: showCopyableErrorDialog,
    );
  }

  Future<void> _maybeCompleteOutlookAuthFromCurrentUrl() async {
    await OutlookLinkCoordinator.maybeCompleteOutlookAuthFromCurrentUrl(
      context: context,
      refreshUpcomingOutlookEvents: () async {
        _refreshUpcomingOutlookEvents();
      },
      showCopyableErrorDialog: showCopyableErrorDialog,
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
    return getDateKey(DateTime.now());
  }

  String getDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Set<String> preferredConcurrentEntryIdsForDate(DateTime date) {
    final raw =
        dailyCheckinsByDate[getDateKey(date)]?['preferredConcurrentEntryIds'];
    return parseStringList(raw).toSet();
  }

  Set<String> removedPlannerEntryIdsForDate(DateTime date) {
    final raw =
        dailyCheckinsByDate[getDateKey(date)]?['removedPlannerEntryIds'];
    return parseStringList(raw).toSet();
  }

  Future<void> setRemovedPlannerEntryIds(DateTime date, Set<String> ids) async {
    final dateKey = getDateKey(date);
    final current = Map<String, dynamic>.from(
      dailyCheckinsByDate[dateKey] ?? defaultDailyCheckin(),
    );
    current['removedPlannerEntryIds'] = ids.toList()..sort();
    current['trackerVersion'] = 2;
    setState(() {
      dailyCheckinsByDate[dateKey] = current;
    });
    await saveDailyCheckinsByDate();
  }

  Future<void> setPreferredConcurrentEntryIds(
    DateTime date,
    Set<String> ids,
  ) async {
    final dateKey = getDateKey(date);
    final current = Map<String, dynamic>.from(
      dailyCheckinsByDate[dateKey] ?? defaultDailyCheckin(),
    );
    current['preferredConcurrentEntryIds'] = ids.toList()..sort();
    current['trackerVersion'] = 2;
    setState(() {
      dailyCheckinsByDate[dateKey] = current;
    });
    await saveDailyCheckinsByDate();
  }

  Map<String, PlannerEntryOverride> plannerEntryOverridesForDate(
    DateTime date,
  ) {
    final raw = dailyCheckinsByDate[getDateKey(date)]?['plannerEntryOverrides'];
    final overrides = <String, PlannerEntryOverride>{};
    for (final encoded in parseStringList(raw)) {
      try {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        final id = decoded['id'] as String?;
        if (id == null) continue;
        overrides[id] = PlannerEntryOverride(
          startMinutes: decoded['startMinutes'] as int?,
          endMinutes: decoded['endMinutes'] as int?,
          locked: decoded['locked'] as bool? ?? false,
        );
      } catch (_) {
        continue;
      }
    }
    return overrides;
  }

  Map<String, ExecutionState> plannerExecutionStatesForDate(DateTime date) {
    final raw =
        dailyCheckinsByDate[getDateKey(date)]?['plannerExecutionStates'];
    return PlannerExecutionService.statesFromEncoded(parseStringList(raw));
  }

  Future<void> setPlannerExecutionState(
    DateTime date,
    String entryId,
    ExecutionState state,
  ) async {
    final dateKey = getDateKey(date);
    final current = Map<String, dynamic>.from(
      dailyCheckinsByDate[dateKey] ?? defaultDailyCheckin(),
    );
    final states = plannerExecutionStatesForDate(date);
    states[entryId] = state;
    current['plannerExecutionStates'] = PlannerExecutionService.toEncoded(
      states,
    );
    current['trackerVersion'] = 2;
    setState(() {
      dailyCheckinsByDate[dateKey] = current;
    });
    await saveDailyCheckinsByDate();
  }

  Future<void> executePlannerEntry(
    DateTime date,
    DayPlannerEntry entry,
    ExecutionState state,
  ) async {
    if (entry.type == 'calendar') return;

    if (state == ExecutionState.completed && entry.type == 'task') {
      final taskIndex = entry.task == null
          ? -1
          : tasks.indexWhere((task) => identical(task, entry.task));
      if (taskIndex >= 0) {
        await toggleTask(taskIndex, true);
      }
    }

    if (state == ExecutionState.completed && entry.type == 'movement') {
      final normalized = '${entry.title} ${entry.subtitle ?? ''}'.toLowerCase();
      final pillar = normalized.contains('stand')
          ? ActivityPillar.standing
          : ActivityPillar.walking;
      final log = ActivityLogEntry(
        id: 'activity-${DateTime.now().microsecondsSinceEpoch}',
        pillar: pillar,
        completedAt: DateTime.now(),
        minutes: entry.end.difference(entry.start).inMinutes,
        source: ActivitySource.plannerTimeline,
      );
      final nextLogs = [...activityLogs, log];
      setState(() {
        activityLogs = nextLogs;
        weeklyActivityTotals = ActivityTrackingService.calculateWeeklyTotals(
          nextLogs,
        );
      });
      await StorageService.saveActivityLogs(nextLogs);
    }

    await setPlannerExecutionState(date, entry.id, state);
  }

  Future<void> _savePlannerEntryOverrides(
    DateTime date,
    Map<String, PlannerEntryOverride> overrides,
  ) async {
    final dateKey = getDateKey(date);
    final current = Map<String, dynamic>.from(
      dailyCheckinsByDate[dateKey] ?? defaultDailyCheckin(),
    );
    current['plannerEntryOverrides'] = overrides.entries
        .map(
          (entry) => jsonEncode({
            'id': entry.key,
            'startMinutes': entry.value.startMinutes,
            'endMinutes': entry.value.endMinutes,
            'locked': entry.value.locked,
          }),
        )
        .toList();
    current['trackerVersion'] = 2;
    setState(() {
      dailyCheckinsByDate[dateKey] = current;
    });
    await saveDailyCheckinsByDate();
  }

  Future<void> setPlannerEntryTime(
    DateTime date,
    String entryId,
    int startMinutes,
    int endMinutes,
  ) async {
    final overrides = plannerEntryOverridesForDate(date);
    final existing = overrides[entryId];
    overrides[entryId] = PlannerEntryOverride(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      locked: existing?.locked ?? false,
    );
    await _savePlannerEntryOverrides(date, overrides);
  }

  Future<void> setPlannerEntryLocked(
    DateTime date,
    String entryId,
    bool locked,
  ) async {
    final overrides = plannerEntryOverridesForDate(date);
    final existing = overrides[entryId];
    if (existing == null && !locked) {
      return;
    }
    overrides[entryId] = PlannerEntryOverride(
      startMinutes: existing?.startMinutes,
      endMinutes: existing?.endMinutes,
      locked: locked,
    );
    await _savePlannerEntryOverrides(date, overrides);
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
      'preferredConcurrentEntryIds': <String>[],
      'removedPlannerEntryIds': <String>[],
      'plannerEntryOverrides': <String>[],
      'plannerExecutionStates': <String>[],
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
    // Legacy fallbacks often persisted 0 by default. Treat only fallback 0 as unset.
    if (!hasCurrentValue && parsed == 0) {
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
      current[field] = currentValue == nextValue ? -2 : nextValue;
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
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
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

    if (customDuration == null) {
      return;
    }

    focusTimer?.cancel();
    timerCompletionCueReset?.cancel();
    timerCompletionBeepLoop?.cancel();

    setState(() {
      selectedFocusTimerMinutes = customDuration.inMinutes;
      selectedFocusTimerSeconds = customDuration.inSeconds.remainder(60);
      remainingFocusTime = customDuration;
      timerCompletionCueActive = false;
    });
  }

  void startFocusTimer() {
    if (focusTimer?.isActive == true) {
      return;
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

  Future<void> addTaskWithSubtask() async {
    if (taskController.text.trim().isEmpty) return;
    await addTask();
    if (!mounted || tasks.isEmpty) return;
    final subtaskText = await showAddSubtaskDialog(context);
    if (subtaskText == null || subtaskText.trim().isEmpty) return;
    setState(() {
      tasks.last.subtasks.add(Subtask(text: subtaskText.trim()));
      tasks.last.expanded = true;
    });
    await saveTasks();
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

  Future<void> convertInboxEntryToNote(int index) async {
    if (index < 0 || index >= inboxEntries.length) {
      return;
    }

    final entry = inboxEntries[index].trim();
    if (entry.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    setState(() {
      final newEntry = NoteEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: entry,
        content: '',
        updatedAtUtc: now,
        kind: 'note',
      );
      noteEntries.insert(0, newEntry);
      selectedNoteId = newEntry.id;
      inboxEntries.removeAt(index);
    });

    syncNoteControllers();
    await persistNoteEntries();
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

      final planningA = RecommendationService.getPlanningDays(taskA);
      final planningB = RecommendationService.getPlanningDays(taskB);
      if (planningA != planningB) {
        return planningA.compareTo(planningB);
      }

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
    final incompleteSubtaskIndex = _getCurrentSubtaskIndex(task);

    if (incompleteSubtaskIndex != null) {
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
    final unfinishedTasks = tasks
        .where(
          (task) =>
              task.done != true &&
              !isTaskSnoozed(task) &&
              RecommendationService.isTaskEligibleForToday(task),
        )
        .toList();
    final applyWorkdayBias =
        prioritizeWorkOnWeekdays && _isWeekday(DateTime.now());

    unfinishedTasks.sort((a, b) {
      if (applyWorkdayBias) {
        final isWorkA = _isWorkTask(a);
        final isWorkB = _isWorkTask(b);
        if (isWorkA != isWorkB) {
          return isWorkA ? -1 : 1;
        }
      }

      final priorityA = RecommendationService.getPriorityScore(a.priority);
      final priorityB = RecommendationService.getPriorityScore(b.priority);
      if (priorityA != priorityB) return priorityB.compareTo(priorityA);

      final dueA = RecommendationService.getPlanningDays(a);
      final dueB = RecommendationService.getPlanningDays(b);
      if (dueA != dueB) return dueA.compareTo(dueB);

      final progressA = RecommendationService.getTaskProgress(a);
      final progressB = RecommendationService.getTaskProgress(b);
      return progressA.compareTo(progressB);
    });

    return unfinishedTasks.take(count).toList();
  }

  bool _isWeekday(DateTime date) {
    return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  }

  bool _isWorkTask(Task task) {
    return task.category.trim().toLowerCase() == 'work';
  }

  Future<void> toggleWorkdayPriorityMode() async {
    final nextValue = !prioritizeWorkOnWeekdays;
    setState(() {
      prioritizeWorkOnWeekdays = nextValue;
    });
    await StorageService.savePrioritizeWorkOnWeekdays(nextValue);
  }

  Future<void> setGymAvailable(bool enabled) async {
    setState(() {
      gymAvailable = enabled;
    });
    await StorageService.saveGymAvailable(enabled);
  }

  Future<void> setWfhAvailable(bool enabled) async {
    setState(() {
      wfhAvailable = enabled;
    });
    await StorageService.saveWfhAvailable(enabled);
  }

  Future<void> setEveningAvailable(bool enabled) async {
    setState(() {
      eveningAvailable = enabled;
    });
    await StorageService.saveEveningAvailable(enabled);
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

  Future<void> reorderSubtasks(
    int taskIndex,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) {
      return;
    }

    setState(() {
      final item = tasks[taskIndex].subtasks.removeAt(oldIndex);
      final targetIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
      tasks[taskIndex].subtasks.insert(targetIndex, item);
    });

    await saveTasks();
  }

  Future<void> toggleTask(int index, bool? value) async {
    final newDoneValue = value ?? false;

    setState(() {
      tasks[index].done = newDoneValue;
      for (final subtask in tasks[index].subtasks) {
        subtask.done = newDoneValue;
      }
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
      tasks[index].expanded = !tasks[index].expanded;
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

  // Recommendation and sorting logic moved to RecommendationService.

  Future<void> _setTaskDateField({
    required int index,
    required String title,
    required String message,
    required String? currentValue,
    required void Function(String? value) applyValue,
  }) async {
    final result = await TaskFieldDialogs.showTaskDateDialog(
      context: context,
      title: title,
      message: message,
      currentValue: currentValue,
    );

    if (!mounted || result == null) return;

    setState(() {
      switch (result.action) {
        case TaskDateDialogAction.remove:
          applyValue(null);
        case TaskDateDialogAction.set:
          applyValue(result.isoDate);
      }
    });

    await saveTasks();
  }

  Future<void> setDueDate(int index) async {
    await _setTaskDateField(
      index: index,
      title: 'Due date',
      message: 'Change or remove the due date for this task.',
      currentValue: tasks[index].dueDate,
      applyValue: (value) {
        tasks[index].dueDate = value;
      },
    );
  }

  Future<void> setDoDate(int index) async {
    await _setTaskDateField(
      index: index,
      title: 'Plan date',
      message: 'Choose when you want this task to start showing up for action.',
      currentValue: tasks[index].doDate,
      applyValue: (value) {
        tasks[index].doDate = value;
      },
    );
  }

  Future<void> setTaskEffort(int index, int? selected) async {
    setState(() {
      tasks[index].effortMinutes = selected == null || selected < 0
          ? null
          : selected;
    });
    await saveTasks();
  }

  Future<void> setNextSessionEffort(int index, int? selected) async {
    setState(() {
      tasks[index].nextSessionEffortMinutes = selected == null || selected < 0
          ? null
          : selected;
    });
    await saveTasks();
  }

  Future<void> setSubtaskDate(int taskIndex, int subtaskIndex) async {
    await _setTaskDateField(
      index: taskIndex,
      title: 'Subtask plan date',
      message:
          'Choose when this subtask should start showing up as the next step.',
      currentValue: tasks[taskIndex].subtasks[subtaskIndex].doDate,
      applyValue: (value) {
        tasks[taskIndex].subtasks[subtaskIndex].doDate = value;
      },
    );
  }

  String formatDueDate(String? dueDate) {
    if (dueDate == null || dueDate.trim().isEmpty) {
      return "";
    }

    final date = DateTime.tryParse(dueDate);
    if (date == null) {
      return "";
    }

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

  String formatEffortLabel(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 'No effort';
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

  String formatPriorityCardDate(Task task) {
    final doLabel = formatDueDate(task.doDate);
    if (doLabel.isNotEmpty) {
      return 'Plan $doLabel';
    }

    return formatDueDate(task.dueDate);
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
        final useWideWebOverviewColumns =
            showOverview && !showTaskList && constraints.maxWidth >= 1200;
        final wideWebOverviewColumnWidth = ((constraints.maxWidth - 20.0) / 3.0)
            .clamp(0.0, constraints.maxWidth);
        final priorityCardWidth = isNarrow ? null : kWidePriorityCardWidth;
        final priorityCardsTotalWidth = useWideWebOverviewColumns
            ? (wideWebOverviewColumnWidth - 16.0)
                  .clamp(280.0, constraints.maxWidth)
                  .toDouble()
            : isNarrow
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
                .floorToDouble()
                .clamp(
                  useWideWebOverviewColumns ? 94.0 : 96.0,
                  useWideWebOverviewColumns ? 220.0 : kWidePriorityCardWidth,
                )
                .toDouble();
        final taskTabs = getTaskTabs();
        final visibleTaskIndices = getVisibleTaskIndices();

        Widget buildPriorityCard(int position, Task? task) {
          final priorityAccentColor = switch (task?.priority) {
            'high' => Colors.red.shade700,
            'medium' => Colors.orange.shade700,
            'low' => Colors.green.shade700,
            _ => Colors.grey.shade700,
          };

          return PriorityTaskCard(
            width: priorityCardDisplayWidth,
            position: position,
            title: task?.task,
            categoryLabel: task == null
                ? null
                : (task.category == 'None' ? 'No category' : task.category),
            priorityLabel: task == null
                ? null
                : getPriorityLabel(task.priority),
            dateLabel: task == null ? null : formatPriorityCardDate(task),
            priorityAccentColor: priorityAccentColor,
            useWideWebOverviewColumns: useWideWebOverviewColumns,
            onTap: task == null
                ? null
                : () {
                    openTaskFromPriorityCard(task);
                  },
          );
        }

        Widget buildDailyCheckinSection() {
          return SymptomTrackerSection(
            checkin: getTodayDailyCheckin(),
            symptomTrackerLabels: symptomTrackerLabels,
            dailyContextOptions: dailyContextOptions,
            otherMedicationOptions: otherMedicationOptions,
            dopamineCrashSymptomOptions: dopamineCrashSymptomOptions,
            dopamineCrashAdditionalSymptomOptions:
                dopamineCrashAdditionalSymptomOptions,
            useWideWebOverviewColumns: useWideWebOverviewColumns,
            onSetTodayDailyRating: setTodayDailyRating,
            onSetTodayMedicationTime: setTodayMedicationTime,
            onClearTodayMedicationTime: clearTodayMedicationTime,
            onSetTodayMedicationQuickTime: setTodayMedicationQuickTime,
            onToggleTodayOtherMedication: toggleTodayOtherMedication,
            onSetTodayCrashTimeField: setTodayCrashTimeField,
            onClearTodayCrashTimeField: clearTodayCrashTimeField,
            onToggleTodayCrashSymptomField: toggleTodayCrashSymptomField,
            onToggleTodayContextTag: toggleTodayContextTag,
            wfhAvailable: wfhAvailable,
            onWfhAvailableChanged: (next) {
              unawaited(setWfhAvailable(next));
            },
            gymAvailable: gymAvailable,
            onGymAvailableChanged: (next) {
              unawaited(setGymAvailable(next));
            },
          );
        }

        Widget buildCaptureInboxSection() {
          return QuickCaptureSection(
            inboxEntries: inboxEntries,
            inboxCaptureController: inboxCaptureController,
            onAddInboxEntry: addInboxEntry,
            onConvertInboxEntryToNote: convertInboxEntryToNote,
            onRemoveInboxEntry: removeInboxEntry,
          );
        }

        Widget buildDayPlannerSection({bool dashboardMode = false}) {
          return DayPlannerSection(
            dashboardMode: dashboardMode,
            onOpenPlanner: () {
              setState(() {
                selectedMainSectionIndex = 0;
              });
            },
            upcomingOutlookEventsFuture: upcomingOutlookEventsFuture,
            loadUpcomingOutlookEvents: _loadUpcomingOutlookEvents,
            outlookLookAheadDays: outlookLookAheadDays,
            plannerDayOffset: plannerDayOffset,
            showWorkInPlanner: showWorkInPlanner,
            showHomeInPlanner: showHomeInPlanner,
            showPlannerInPlanner: showPlannerInPlanner,
            gymAvailable: gymAvailable,
            wfhAvailable: wfhAvailable,
            eveningAvailable: eveningAvailable,
            weeklyActivityTotals: weeklyActivityTotals,
            daysSinceLastMobility: getDaysSinceLastMobility(),
            gymCompletedToday: completedActivityPillarsToday().contains(
              ActivityPillar.gym,
            ),
            completedActivityPillarsToday: completedActivityPillarsToday(),
            executionStates: plannerExecutionStatesForDate(
              DateTime.now().add(Duration(days: plannerDayOffset)),
            ),
            preferredConcurrentEntryIds: preferredConcurrentEntryIdsForDate(
              DateTime.now().add(Duration(days: plannerDayOffset)),
            ),
            removedPlannerEntryIds: removedPlannerEntryIdsForDate(
              DateTime.now().add(Duration(days: plannerDayOffset)),
            ),
            plannerEntryOverrides: plannerEntryOverridesForDate(
              DateTime.now().add(Duration(days: plannerDayOffset)),
            ),
            workdayStartMinutes: plannerWorkdayStartMinutes,
            workdayEndMinutes: plannerWorkdayEndMinutes,
            tasks: tasks,
            isNarrow: isNarrow,
            useWideWebOverviewColumns: useWideWebOverviewColumns,
            isWorkTask: _isWorkTask,
            formatPlannerDate: OutlookFormattingService.formatPlannerDate,
            onPlannerDayOffsetChanged: (nextOffset) {
              setState(() {
                plannerDayOffset = nextOffset;
              });
            },
            onShowWorkInPlannerChanged: (next) {
              setState(() {
                showWorkInPlanner = next;
              });
            },
            onShowHomeInPlannerChanged: (next) {
              setState(() {
                showHomeInPlanner = next;
              });
            },
            onShowPlannerInPlannerChanged: (next) {
              setState(() {
                showPlannerInPlanner = next;
              });
            },
            onGymAvailableChanged: (next) {
              unawaited(setGymAvailable(next));
            },
            onWfhAvailableChanged: (next) {
              unawaited(setWfhAvailable(next));
            },
            onEveningAvailableChanged: (next) {
              unawaited(setEveningAvailable(next));
            },
            onCompleteRecommendation: (recommendation) {
              unawaited(completeActivityRecommendation(recommendation));
            },
            onViewActivityHistory: openActivityHistory,
            onPreferredConcurrentEntryIdsChanged: (ids) {
              final date = DateTime.now().add(Duration(days: plannerDayOffset));
              unawaited(setPreferredConcurrentEntryIds(date, ids));
            },
            onRemovePlannerEntry: (entryId) {
              final date = DateTime.now().add(Duration(days: plannerDayOffset));
              final next = removedPlannerEntryIdsForDate(date)..add(entryId);
              unawaited(setRemovedPlannerEntryIds(date, next));
            },
            onEditPlannerEntryTime: (entryId, startMinutes, endMinutes) {
              final date = DateTime.now().add(Duration(days: plannerDayOffset));
              unawaited(
                setPlannerEntryTime(date, entryId, startMinutes, endMinutes),
              );
            },
            onTogglePlannerEntryLock: (entryId, locked) {
              final date = DateTime.now().add(Duration(days: plannerDayOffset));
              unawaited(setPlannerEntryLocked(date, entryId, locked));
            },
            onExecutePlannerEntry: (entry, state) {
              final date = DateTime.now().add(Duration(days: plannerDayOffset));
              unawaited(executePlannerEntry(date, entry, state));
            },
            onOpenTask: (task) {
              unawaited(openTaskFromPriorityCard(task));
            },
            onWorkdayHoursChanged: (hours) {
              setState(() {
                plannerWorkdayStartMinutes = hours.$1;
                plannerWorkdayEndMinutes = hours.$2;
              });
              unawaited(
                StorageService.savePlannerWorkdayHours(
                  startMinutes: hours.$1,
                  endMinutes: hours.$2,
                ),
              );
            },
          );
        }

        Widget buildOutlookSection() {
          return OutlookSection(
            upcomingOutlookEventsFuture: upcomingOutlookEventsFuture,
            loadUpcomingOutlookEvents: _loadUpcomingOutlookEvents,
            isNarrow: isNarrow,
            outlookLookAheadDays: outlookLookAheadDays,
            useWideWebOverviewColumns: useWideWebOverviewColumns,
            importedOutlookSummary: importedOutlookSummary,
            onImportIcsCalendarFile: importIcsCalendarFile,
            onClearImportedOutlookEvents: clearImportedOutlookEvents,
            formatOutlookDayDivider:
                OutlookFormattingService.formatOutlookDayDivider,
            formatOutlookEventTimeRange:
                OutlookFormattingService.formatOutlookEventTimeRange,
            formatOutlookEventDateRange:
                OutlookFormattingService.formatOutlookEventDateRange,
            isMultiDayOutlookEvent:
                OutlookFormattingService.isMultiDayOutlookEvent,
            formatImportTimestamp:
                OutlookFormattingService.formatImportTimestamp,
            formatImportDate: OutlookFormattingService.formatImportDate,
          );
        }

        Widget buildTaskTab(String label) {
          return TaskTabButton(
            label: label,
            isSelected: label == selectedTaskCategory,
            onTap: () {
              setState(() {
                selectedTaskCategory = label;
              });
            },
          );
        }

        Widget buildTaskComposerSection() {
          return TaskComposerSection(
            taskController: taskController,
            onAddTask: addTask,
            onAddTaskWithSubtask: addTaskWithSubtask,
          );
        }

        Widget buildTaskPanels(int index) {
          final task = tasks[index];
          return TaskPanelsSection(
            task: task,
            selectedTab: taskDetailTabByTask[task] ?? 0,
            isNarrow: isNarrow,
            isGenerating: isGenerating,
            defaultStarterStepCount: defaultStarterStepCount,
            subtaskController: getSubtaskController(index),
            formatDueDate: formatDueDate,
            onSelectTab: (tabIndex) async {
              await selectTaskDetailTab(index, tabIndex);
            },
            onReorderSubtasks: (oldIndex, newIndex) async {
              await reorderSubtasks(index, oldIndex, newIndex);
            },
            onToggleSubtask: (subtaskIndex, value) async {
              await toggleSubtask(index, subtaskIndex, value);
            },
            onSetSubtaskDate: (subtaskIndex) async {
              await setSubtaskDate(index, subtaskIndex);
            },
            onEditSubtask: (subtaskIndex) async {
              await editSubtask(index, subtaskIndex);
            },
            onDeleteSubtask: (subtaskIndex) {
              showDeleteSubtaskConfirmation(index, subtaskIndex);
            },
            onAddSubtask: () async {
              await addSubtaskFromInput(index);
            },
            onGenerateTaskSubtasks: () {
              handleGenerateTaskSubtasks(index);
            },
            onConfirmDeleteStarterSteps: () {
              confirmDeleteStarterSteps(index);
            },
            onRegenerateStarterSteps: () {
              createSubtasks(index, defaultStarterStepCount);
            },
            onGenerateStarterScript: () async {
              await generateStarterScript(index);
            },
            onEditStarterScript: () async {
              await editStarterScript(index);
            },
          );
        }

        return TasksViewSection(
          showOverview: showOverview,
          showTaskList: showTaskList,
          isNarrow: isNarrow,
          priorityCardsTotalWidth: priorityCardsTotalWidth,
          priorityCardCount: priorityCardCount,
          priorityCardSpacing: priorityCardSpacing,
          isGenerating: isGenerating,
          prioritizeWorkOnWeekdays: prioritizeWorkOnWeekdays,
          isWeekday: _isWeekday(DateTime.now()),
          taskTabsScrollController: taskTabsScrollController,
          taskTabs: taskTabs.map(buildTaskTab).toList(),
          taskSortLabel: getTaskSortLabel(),
          groupTasksByPriority: groupTasksByPriority,
          onGroupByPriorityChanged: (value) {
            setState(() {
              groupTasksByPriority = value;
            });
          },
          onSelectTaskSortMode: (mode) {
            setState(() {
              selectedTaskSortMode = switch (mode) {
                'dueDate' => TaskListSortMode.dueDate,
                'priority' => TaskListSortMode.priority,
                _ => TaskListSortMode.manual,
              };
            });
          },
          getTopTasks: getTopTasks,
          buildPriorityCard: buildPriorityCard,
          onToggleWorkdayPriorityMode: toggleWorkdayPriorityMode,
          buildCaptureInboxSection: buildCaptureInboxSection(),
          buildOutlookSection: buildOutlookSection(),
          buildDailyCheckinSection: buildDailyCheckinSection(),
          buildDayPlannerSection: buildDayPlannerSection(),
          buildTimerSection: buildOverviewCountdownView(),
          buildTaskComposerSection: buildTaskComposerSection(),
          buildTaskListContent: () {
            return TaskListSection(
              tasks: tasks,
              visibleTaskIndices: visibleTaskIndices,
              selectedTaskCategory: selectedTaskCategory,
              groupTasksByPriority: groupTasksByPriority,
              selectedTaskSortModeIsManual:
                  selectedTaskSortMode == TaskListSortMode.manual,
              selectedTaskPaneIndex: selectedTaskPaneIndex,
              taskListScrollController: taskListScrollController,
              getPriorityColor: getPriorityColor,
              getPriorityLabel: getPriorityLabel,
              categories: categories,
              formatDueDate: formatDueDate,
              buildTaskPanels: buildTaskPanels,
              onToggleTask: (taskIndex, value) {
                toggleTask(taskIndex, value);
              },
              onToggleExpanded: (taskIndex) {
                toggleExpanded(taskIndex);
              },
              onSelectTaskPaneIndex: (taskIndex) {
                setState(() {
                  selectedTaskPaneIndex = taskIndex;
                });
              },
              onPriorityChanged: (taskIndex, value) {
                setState(() {
                  tasks[taskIndex].priority = value;
                });
                saveTasks();
              },
              onSetDueDate: (taskIndex) async {
                await setDueDate(taskIndex);
              },
              onSetPlanDate: (taskIndex) async {
                await setDoDate(taskIndex);
              },
              onSetTaskEffort: (taskIndex, minutes) async {
                await setTaskEffort(taskIndex, minutes);
              },
              onSetNextSessionEffort: (taskIndex, minutes) async {
                await setNextSessionEffort(taskIndex, minutes);
              },
              onCategoryChanged: (taskIndex, value) {
                setState(() {
                  tasks[taskIndex].category = value;
                });
                saveTasks();
              },
              onEditTask: (taskIndex) {
                editTask(taskIndex);
              },
              onDeleteTask: (taskIndex) {
                showDeleteConfirmation(taskIndex);
              },
              onReorderVisibleTasks:
                  (oldIndex, newIndex, currentVisibleTaskIndices) async {
                    setState(() {
                      reorderVisibleTasks(
                        oldIndex,
                        newIndex,
                        currentVisibleTaskIndices,
                      );
                    });

                    await saveTasks();
                  },
            );
          },
        );
      },
    );
  }

  Widget buildCountdownView() {
    return _buildCountdownView(compactMode: false, fixedHeight: null);
  }

  Widget buildOverviewCountdownView() {
    return _buildCountdownView(compactMode: true, fixedHeight: null);
  }

  Widget _buildCountdownView({
    required bool compactMode,
    required double? fixedHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final timerRunning = focusTimer?.isActive == true;
        final contentWidth = compactMode
            ? (constraints.maxWidth < 720
                  ? constraints.maxWidth
                  : kWideContentWidth.clamp(0, constraints.maxWidth).toDouble())
            : constraints.maxWidth;
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
        final digitalFontSize = compactMode
            ? (contentWidth < 420 ? 42.0 : 52.0)
            : (contentWidth < 540 ? 72.0 : 108.0);
        final availableHeight =
            fixedHeight ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 480.0);

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
          compactMode: compactMode,
        );
      },
    );
  }

  Widget buildInsightsView() {
    return InsightsSection(
      dailyCheckinsByDate: dailyCheckinsByDate,
      parseScoreField: parseScoreField,
      parseStringList: parseStringList,
      wideContentWidth: kWideContentWidth,
      todayCheckin: getTodayDailyCheckin(),
      symptomTrackerLabels: symptomTrackerLabels,
      dailyContextOptions: dailyContextOptions,
      otherMedicationOptions: otherMedicationOptions,
      dopamineCrashSymptomOptions: dopamineCrashSymptomOptions,
      dopamineCrashAdditionalSymptomOptions:
          dopamineCrashAdditionalSymptomOptions,
      onSetTodayDailyRating: setTodayDailyRating,
      onSetTodayMedicationTime: setTodayMedicationTime,
      onClearTodayMedicationTime: clearTodayMedicationTime,
      onSetTodayMedicationQuickTime: setTodayMedicationQuickTime,
      onToggleTodayOtherMedication: toggleTodayOtherMedication,
      onSetTodayCrashTimeField: setTodayCrashTimeField,
      onClearTodayCrashTimeField: clearTodayCrashTimeField,
      onToggleTodayCrashSymptomField: toggleTodayCrashSymptomField,
      onToggleTodayContextTag: toggleTodayContextTag,
      wfhAvailable: wfhAvailable,
      onWfhAvailableChanged: (next) {
        unawaited(setWfhAvailable(next));
      },
      gymAvailable: gymAvailable,
      onGymAvailableChanged: (next) {
        unawaited(setGymAvailable(next));
      },
    );
  }

  Widget buildNotesView() {
    return NotesSection(
      wideContentWidth: kWideContentWidth,
      noteEntries: noteEntries,
      selectedNoteId: selectedNoteId,
      inboxEntries: inboxEntries,
      displayNoteTitle: displayNoteTitle,
      notePreview: notePreview,
      onCreateNoteWithTitle: (title) async {
        await addNoteEntryWithTitle(title);
      },
      onCreateRecipeWithTitle: (title) async {
        await addRecipeEntryWithTitle(title);
      },
      onSelectNote: (noteId) async {
        selectNoteEntry(noteId);
      },
      onEditNote: (entry) async {
        await openNoteEntryDialog(existing: entry);
      },
      onConvertNoteToTask: (noteId) async {
        await convertNoteEntryToTask(noteId);
      },
      onDeleteNote: (noteId) async {
        await deleteNoteEntryById(noteId);
      },
      onEditInboxEntry: (index) async {
        await editInboxEntry(index);
      },
      onConvertInboxEntryToNote: (index) async {
        await convertInboxEntryToNote(index);
      },
      onConvertInboxEntryToTask: (index) async {
        await convertInboxEntryToTask(index);
      },
      onRemoveInboxEntry: (index) async {
        await removeInboxEntry(index);
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

  Widget _buildPlannerExperience({required bool dashboardMode}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final useWideWebOverviewColumns =
            !isNarrow && constraints.maxWidth >= 1200;
        final planner = DayPlannerSection(
          dashboardMode: dashboardMode,
          onOpenPlanner: () => setState(() => selectedMainSectionIndex = 0),
          upcomingOutlookEventsFuture: upcomingOutlookEventsFuture,
          loadUpcomingOutlookEvents: _loadUpcomingOutlookEvents,
          outlookLookAheadDays: outlookLookAheadDays,
          plannerDayOffset: plannerDayOffset,
          showWorkInPlanner: showWorkInPlanner,
          showHomeInPlanner: showHomeInPlanner,
          showPlannerInPlanner: showPlannerInPlanner,
          gymAvailable: gymAvailable,
          wfhAvailable: wfhAvailable,
          eveningAvailable: eveningAvailable,
          weeklyActivityTotals: weeklyActivityTotals,
          daysSinceLastMobility: getDaysSinceLastMobility(),
          gymCompletedToday: completedActivityPillarsToday().contains(
            ActivityPillar.gym,
          ),
          completedActivityPillarsToday: completedActivityPillarsToday(),
          executionStates: plannerExecutionStatesForDate(
            DateTime.now().add(Duration(days: plannerDayOffset)),
          ),
          preferredConcurrentEntryIds: preferredConcurrentEntryIdsForDate(
            DateTime.now().add(Duration(days: plannerDayOffset)),
          ),
          removedPlannerEntryIds: removedPlannerEntryIdsForDate(
            DateTime.now().add(Duration(days: plannerDayOffset)),
          ),
          plannerEntryOverrides: plannerEntryOverridesForDate(
            DateTime.now().add(Duration(days: plannerDayOffset)),
          ),
          workdayStartMinutes: plannerWorkdayStartMinutes,
          workdayEndMinutes: plannerWorkdayEndMinutes,
          tasks: tasks,
          isNarrow: isNarrow,
          useWideWebOverviewColumns: useWideWebOverviewColumns,
          isWorkTask: _isWorkTask,
          formatPlannerDate: OutlookFormattingService.formatPlannerDate,
          onPlannerDayOffsetChanged: (value) =>
              setState(() => plannerDayOffset = value),
          onShowWorkInPlannerChanged: (value) =>
              setState(() => showWorkInPlanner = value),
          onShowHomeInPlannerChanged: (value) =>
              setState(() => showHomeInPlanner = value),
          onShowPlannerInPlannerChanged: (value) =>
              setState(() => showPlannerInPlanner = value),
          onGymAvailableChanged: (value) => unawaited(setGymAvailable(value)),
          onWfhAvailableChanged: (value) => unawaited(setWfhAvailable(value)),
          onEveningAvailableChanged: (value) =>
              unawaited(setEveningAvailable(value)),
          onCompleteRecommendation: (value) =>
              unawaited(completeActivityRecommendation(value)),
          onViewActivityHistory: openActivityHistory,
          onPreferredConcurrentEntryIdsChanged: (ids) {
            final date = DateTime.now().add(Duration(days: plannerDayOffset));
            unawaited(setPreferredConcurrentEntryIds(date, ids));
          },
          onRemovePlannerEntry: (entryId) {
            final date = DateTime.now().add(Duration(days: plannerDayOffset));
            unawaited(
              setRemovedPlannerEntryIds(
                date,
                removedPlannerEntryIdsForDate(date)..add(entryId),
              ),
            );
          },
          onWorkdayHoursChanged: (hours) {
            setState(() {
              plannerWorkdayStartMinutes = hours.$1;
              plannerWorkdayEndMinutes = hours.$2;
            });
            unawaited(
              StorageService.savePlannerWorkdayHours(
                startMinutes: hours.$1,
                endMinutes: hours.$2,
              ),
            );
          },
          onEditPlannerEntryTime: (entryId, start, end) {
            final date = DateTime.now().add(Duration(days: plannerDayOffset));
            unawaited(setPlannerEntryTime(date, entryId, start, end));
          },
          onTogglePlannerEntryLock: (entryId, locked) {
            final date = DateTime.now().add(Duration(days: plannerDayOffset));
            unawaited(setPlannerEntryLocked(date, entryId, locked));
          },
          onExecutePlannerEntry: (entry, state) {
            final date = DateTime.now().add(Duration(days: plannerDayOffset));
            unawaited(executePlannerEntry(date, entry, state));
          },
          onOpenTask: (task) => unawaited(openTaskFromPriorityCard(task)),
        );
        if (dashboardMode) {
          return planner;
        }
        if (constraints.hasBoundedHeight) {
          return SizedBox(height: constraints.maxHeight, child: planner);
        }
        return SizedBox(
          height: MediaQuery.sizeOf(context).height - 32,
          child: planner,
        );
      },
    );
  }

  Widget _buildCombinedHomePlanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (!isWide) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: _buildPlannerExperience(dashboardMode: true),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: constraints.maxHeight,
                  child: _buildPlannerExperience(dashboardMode: false),
                ),
              ],
            ),
          );
        }

        final combinedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height - 120;
        return SizedBox(
          height: combinedHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildPlannerExperience(dashboardMode: true),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: SizedBox.expand(
                    child: _buildPlannerExperience(dashboardMode: false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                  buildHomeDashboard: () =>
                      _buildPlannerExperience(dashboardMode: true),
                  buildCombinedHomePlanner: _buildCombinedHomePlanner,
                  buildCountdownView: buildCountdownView,
                  buildInsightsView: buildInsightsView,
                  buildNotesView: buildNotesView,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: selectedMainSectionIndex == 2 ? null : null,
    );
  }
}
