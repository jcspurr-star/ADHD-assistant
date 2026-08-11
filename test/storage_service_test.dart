import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhd_assistant/models/note_entry.dart';
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
