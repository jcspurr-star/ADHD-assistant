import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhd_assistant/models/note_entry.dart';
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/day_planner_service.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:adhd_assistant/services/planner_execution_service.dart';
import 'package:adhd_assistant/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('undo restores the previous persisted state', () async {
    SharedPreferences.setMockInitialValues({});

    await StorageService.saveTasks([Task(task: 'First')]);
    await StorageService.saveTasks([Task(task: 'Second')]);

    expect(await StorageService.undoLastChange(), isTrue);
    final restored = await StorageService.loadTasks();

    expect(restored.single.task, 'First');
  });

  test(
    'drops stale imported events beyond the requested look-ahead horizon',
    () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await StorageService.saveImportedOutlookEvents([
        OutlookCalendarEvent(
          id: 'past-event',
          subject: 'Past meeting',
          start: today.subtract(const Duration(days: 5)),
          end: today.subtract(const Duration(days: 5, hours: -1)),
          isAllDay: false,
        ),
        OutlookCalendarEvent(
          id: 'in-range-event',
          subject: 'Tomorrow meeting',
          start: today.add(const Duration(days: 1, hours: 9)),
          end: today.add(const Duration(days: 1, hours: 10)),
          isAllDay: false,
        ),
        OutlookCalendarEvent(
          id: 'stale-future-event',
          subject: 'Stale future meeting from an old import',
          start: today.add(const Duration(days: 20, hours: 9)),
          end: today.add(const Duration(days: 20, hours: 10)),
          isAllDay: false,
        ),
      ]);

      final events = await StorageService.getUpcomingOutlookEvents(
        lookAhead: const Duration(days: 2),
        maxItems: 10,
      );

      expect(events.map((event) => event.id), contains('past-event'));
      expect(events.map((event) => event.id), contains('in-range-event'));
      expect(
        events.map((event) => event.id),
        isNot(contains('stale-future-event')),
      );
    },
  );

  test('StorageService saves and loads Task objects', () async {
    SharedPreferences.setMockInitialValues({});

    final tasks = [
      Task(
        task: 'Alpha',
        done: false,
        expanded: false,
        doDate: '2024-01-02',
        effortMinutes: 240,
        nextSessionEffortMinutes: 45,
        absolutePriority: true,
        subtasks: [Subtask(text: 'Step 1', doDate: '2024-01-02')],
      ),
      Task(task: 'Beta', done: true, expanded: true, priority: 'high'),
    ];

    await StorageService.saveTasks(tasks);

    final loaded = await StorageService.loadTasks();

    expect(loaded.length, equals(2));
    expect(loaded[0].task, equals('Alpha'));
    expect(loaded[0].doDate, equals('2024-01-02'));
    expect(loaded[0].effortMinutes, equals(240));
    expect(loaded[0].nextSessionEffortMinutes, equals(45));
    expect(loaded[0].absolutePriority, isTrue);
    expect(loaded[0].subtasks.first.doDate, equals('2024-01-02'));
    expect(loaded[1].priority, equals('high'));
    expect(loaded[1].done, isTrue);
  });

  test('StorageService saves and loads note entries', () async {
    SharedPreferences.setMockInitialValues({});

    final entries = [
      NoteEntry(
        id: 'n1',
        title: 'Calls',
        content: 'Call GP on Monday',
        updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      ),
      NoteEntry(
        id: 'n2',
        title: 'Shopping',
        content: 'Buy vitamins',
        updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    ];
    await StorageService.saveNoteEntries(entries);

    final loadedEntries = await StorageService.loadNoteEntries();
    expect(loadedEntries.length, equals(2));
    expect(loadedEntries.first.title, equals('Calls'));
    expect(loadedEntries[1].content, equals('Buy vitamins'));
  });

  test('StorageService migrates legacy notes to note entries', () async {
    SharedPreferences.setMockInitialValues({'notes': 'Legacy notes block'});

    final loadedEntries = await StorageService.loadNoteEntries();

    expect(loadedEntries.length, equals(1));
    expect(loadedEntries.first.content, equals('Legacy notes block'));
  });

  test('StorageService saves and loads inbox entries', () async {
    SharedPreferences.setMockInitialValues({});

    final entries = ['Call dentist', 'Find passport', 'Buy sticky notes'];
    await StorageService.saveInboxEntries(entries);

    final loadedEntries = await StorageService.loadInboxEntries();
    expect(loadedEntries, equals(entries));
  });

  test(
    'allocates enough Outlook calendar items for the full planner horizon',
    () {
      expect(
        OneDriveSyncService.recommendedCalendarFetchLimitForLookAheadDays(14),
        equals(200),
      );
      expect(
        OneDriveSyncService.recommendedCalendarFetchLimitForLookAheadDays(1),
        equals(20),
      );
    },
  );

  test('applies the Outlook-compatible export settings to planner entries', () {
    final workCalendar = DayPlannerEntry(
      id: 'calendar-1',
      title: 'Team sync',
      type: 'calendar',
      start: DateTime(2026, 8, 27, 9, 0),
      end: DateTime(2026, 8, 27, 10, 0),
      subtitle: 'Work calendar',
      category: PlannerEventCategory.fixed,
    );
    final homeTask = DayPlannerEntry(
      id: 'task-1',
      title: 'Laundry',
      type: 'task',
      start: DateTime(2026, 8, 27, 11, 0),
      end: DateTime(2026, 8, 27, 12, 0),
      task: Task(task: 'Laundry'),
      category: PlannerEventCategory.planned,
    );
    final breakEntry = DayPlannerEntry(
      id: 'break-1',
      title: 'Break',
      type: 'break',
      start: DateTime(2026, 8, 27, 15, 0),
      end: DateTime(2026, 8, 27, 15, 30),
      category: PlannerEventCategory.informational,
    );

    final workCalendarPayload =
        OneDriveSyncService.outlookExportSettingsForPlannerEntry(workCalendar);
    expect(workCalendarPayload['categories'], equals(['Work']));
    expect(workCalendarPayload['showAs'], equals('busy'));
    expect(workCalendarPayload['isReminderOn'], isTrue);
    expect(workCalendarPayload['reminderMinutesBeforeStart'], equals(0));

    final homeTaskPayload =
        OneDriveSyncService.outlookExportSettingsForPlannerEntry(homeTask);
    expect(homeTaskPayload['categories'], equals(['Home']));
    expect(homeTaskPayload['showAs'], equals('free'));
    expect(homeTaskPayload['isReminderOn'], isFalse);
    expect(homeTaskPayload, isNot(contains('reminderMinutesBeforeStart')));

    final breakPayload =
        OneDriveSyncService.outlookExportSettingsForPlannerEntry(breakEntry);
    expect(breakPayload['categories'], equals(['Break']));
    expect(breakPayload['showAs'], equals('free'));
    expect(breakPayload['isReminderOn'], isTrue);
    expect(breakPayload['reminderMinutesBeforeStart'], equals(0));
  });

  test('exports concurrent movement activities with the Movement category', () {
    final standingDesk = DayPlannerEntry(
      id: 'movement-standing-1',
      title: 'Stand at your desk',
      type: 'movement',
      start: DateTime(2026, 8, 27, 9),
      end: DateTime(2026, 8, 27, 10),
      isConcurrent: true,
    );
    final walkingPad = DayPlannerEntry(
      id: 'movement-walking-1',
      title: 'Walk while you work',
      type: 'movement',
      start: DateTime(2026, 8, 27, 10),
      end: DateTime(2026, 8, 27, 11),
      isConcurrent: true,
    );

    for (final entry in [standingDesk, walkingPad]) {
      final payload = OneDriveSyncService.outlookExportSettingsForPlannerEntry(
        entry,
      );
      expect(payload['categories'], equals(['Movement']));
      expect(payload['showAs'], equals('free'));
      expect(payload['isReminderOn'], isTrue);
      expect(payload['reminderMinutesBeforeStart'], equals(0));
    }
  });

  test('applies Outlook export settings from an imported calendar source', () {
    final workCalendar = OutlookCalendarEvent(
      id: 'work-calendar-1',
      subject: 'Work meeting',
      start: DateTime(2026, 8, 27, 9),
      end: DateTime(2026, 8, 27, 10),
      isAllDay: false,
      calendarSource: 'work',
    );
    final homeCalendar = OutlookCalendarEvent(
      id: 'home-calendar-1',
      subject: 'Dentist',
      start: DateTime(2026, 8, 27, 11),
      end: DateTime(2026, 8, 27, 12),
      isAllDay: false,
    );

    final workPayload =
        OneDriveSyncService.outlookExportSettingsForCalendarEvent(workCalendar);
    expect(workPayload['categories'], equals(['Work']));
    expect(workPayload['showAs'], equals('busy'));
    expect(workPayload['isReminderOn'], isTrue);
    expect(workPayload['reminderMinutesBeforeStart'], equals(0));

    final homePayload =
        OneDriveSyncService.outlookExportSettingsForCalendarEvent(homeCalendar);
    expect(homePayload['categories'], equals(['Home']));
    expect(homePayload['showAs'], equals('free'));
    expect(homePayload['isReminderOn'], isFalse);
    expect(homePayload, isNot(contains('reminderMinutesBeforeStart')));
  });

  test('exports all-day calendar events as free with no reminder', () {
    final allDayWorkEvent = OutlookCalendarEvent(
      id: 'work-all-day-1',
      subject: 'Annual leave',
      start: DateTime(2026, 8, 27),
      end: DateTime(2026, 8, 28),
      isAllDay: true,
      calendarSource: 'work',
    );

    final payload = OneDriveSyncService.outlookExportSettingsForCalendarEvent(
      allDayWorkEvent,
    );
    expect(payload['categories'], equals(['Work']));
    expect(payload['showAs'], equals('free'));
    expect(payload['isReminderOn'], isFalse);
    expect(payload, isNot(contains('reminderMinutesBeforeStart')));
  });

  test('creates a backup snapshot when note entries are saved', () async {
    SharedPreferences.setMockInitialValues({});

    await StorageService.saveNoteEntries([
      NoteEntry(
        id: 'n1',
        title: 'Backup note',
        content: 'Should create a backup snapshot',
        updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    ]);

    final history = await StorageService.loadBackupHistory();

    expect(history, isNotEmpty);
    expect(history.first['state'], isA<Map>());
  });

  test('stores a local backup snapshot for recovery', () async {
    SharedPreferences.setMockInitialValues({});

    final tasks = [Task(task: 'Backup task', done: false, expanded: false)];

    await StorageService.saveTasks(tasks);

    final backup = await StorageService.loadLatestBackupState();

    expect(backup, isNotNull);
    expect(backup!['tasks'], isA<List>());
    expect(backup['tasks'], hasLength(1));
  });

  test('reports recovery preview for a specific backup entry', () async {
    SharedPreferences.setMockInitialValues({});

    await StorageService.saveTasks([
      Task(task: 'Backup task', done: false, expanded: false),
    ]);

    final history = await StorageService.loadBackupHistory();
    final backupEntry = history.first;

    await StorageService.saveTasks([
      Task(task: 'Current task', done: false, expanded: false),
    ]);

    final preview = await StorageService.getBackupRecoveryPreviewForBackupEntry(
      backupEntry,
    );

    expect(preview['hasBackup'], isTrue);
    expect(preview['missingTasks'], hasLength(1));
    expect(preview['missingTasks'][0]['task'], equals('Backup task'));
  });

  test('prefers the richer snapshot when timestamps are equal', () {
    final localState = {
      'tasks': <dynamic>[],
      'notes': '',
      'note_entries': <dynamic>[],
      'inbox_entries': <dynamic>[],
      'daily_checkins_by_date': <String, dynamic>{},
      'categories': <dynamic>[],
      'updated_at_utc': '2024-01-01T00:00:00.000Z',
    };

    final remoteState = {
      'tasks': <dynamic>[
        {'task': 'Take medication', 'done': false, 'expanded': false},
      ],
      'notes': 'A real note',
      'note_entries': <dynamic>[
        {'id': '1', 'title': 'Imported note', 'content': 'A real note'},
      ],
      'inbox_entries': <dynamic>['One item'],
      'daily_checkins_by_date': <String, dynamic>{
        '2024-01-01': {'mood': 'ok'},
      },
      'categories': <dynamic>['Wellness'],
      'updated_at_utc': '2024-01-01T00:00:00.000Z',
    };

    final chosen = StorageService.choosePreferredStateSnapshot(
      localState,
      remoteState,
    );

    expect(chosen, isNotNull);
    expect(chosen!['notes'], equals('A real note'));
    expect(chosen['categories'], contains('Wellness'));
  });

  test(
    'avoids overwriting a richer remote snapshot with a default local snapshot',
    () {
      final localState = {
        'tasks': <dynamic>[
          {'task': 'Take medication', 'done': false, 'expanded': false},
          {'task': 'Check calendar', 'done': false, 'expanded': false},
        ],
        'notes': '',
        'note_entries': <dynamic>[],
        'inbox_entries': <dynamic>[],
        'daily_checkins_by_date': <String, dynamic>{},
        'categories': <dynamic>[],
        'updated_at_utc': '2024-01-02T00:00:00.000Z',
      };

      final remoteState = {
        'tasks': <dynamic>[
          {'task': 'Take medication', 'done': false, 'expanded': false},
          {'task': 'Check calendar', 'done': false, 'expanded': false},
          {'task': 'Custom task', 'done': false, 'expanded': false},
        ],
        'notes': 'Custom note',
        'note_entries': <dynamic>[
          {'id': '1', 'title': 'Imported note', 'content': 'Custom note'},
        ],
        'inbox_entries': <dynamic>['One item'],
        'daily_checkins_by_date': <String, dynamic>{
          '2024-01-01': {'mood': 'ok'},
        },
        'categories': <dynamic>['Wellness'],
        'updated_at_utc': '2024-01-01T00:00:00.000Z',
      };

      final chosen = StorageService.choosePreferredStateSnapshot(
        localState,
        remoteState,
      );

      expect(chosen, isNotNull);
      expect(chosen!['notes'], equals('Custom note'));
      expect(chosen['tasks'], hasLength(3));
    },
  );
}
