import 'package:adhd_assistant/services/planner_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'execution summary counts completed, skipped, and remaining entries',
    () {
      final summary = PlannerExecutionService.summarize(
        const ['task-1', 'movement-1', 'break-1', 'buffer-1'],
        const {
          'task-1': ExecutionState.completed,
          'movement-1': ExecutionState.skipped,
        },
      );

      expect(summary.plannedCount, 4);
      expect(summary.completedCount, 1);
      expect(summary.skippedCount, 1);
      expect(summary.remainingCount, 2);
    },
  );

  test('execution records round trip and legacy state defaults pending', () {
    final record = PlannerExecutionRecord(
      entryId: 'task-1',
      state: ExecutionState.completed,
      updatedAt: DateTime.utc(2026, 8, 21, 9),
    );
    final decoded = PlannerExecutionRecord.fromJson(record.toJson());
    final legacy = PlannerExecutionRecord.fromJson({'entryId': 'old'});

    expect(decoded.entryId, 'task-1');
    expect(decoded.state, ExecutionState.completed);
    expect(legacy.state, ExecutionState.pending);
  });

  test('encoded execution states can be restored', () {
    final encoded = PlannerExecutionService.toEncoded(const {
      'task-1': ExecutionState.completed,
      'break-1': ExecutionState.skipped,
    });
    final restored = PlannerExecutionService.statesFromEncoded(encoded);

    expect(restored['task-1'], ExecutionState.completed);
    expect(restored['break-1'], ExecutionState.skipped);
  });

  test(
    'dismissed items are not remaining and grid snapping is predictable',
    () {
      final summary = PlannerExecutionService.summarize(
        const ['task-1', 'task-2', 'task-3'],
        const {
          'task-1': ExecutionState.dismissed,
          'task-2': ExecutionState.deferred,
        },
      );
      final snapped = PlannerExecutionService.snapToGrid(
        DateTime(2026, 8, 21, 10, 7),
        TimeGrid.fifteenMinutes,
      );

      expect(summary.remainingCount, 2);
      expect(snapped, DateTime(2026, 8, 21, 10, 15));
    },
  );
}
