import 'dart:convert';

enum ExecutionState { pending, completed, dismissed }

enum PlannerEventCategory { informational, reminder, fixed, planned }

enum TimeGrid { fifteenMinutes, thirtyMinutes }

class PlannerExecutionRecord {
  const PlannerExecutionRecord({
    required this.entryId,
    required this.state,
    required this.updatedAt,
  });

  final String entryId;
  final ExecutionState state;
  final DateTime updatedAt;

  factory PlannerExecutionRecord.fromJson(Map<String, dynamic> json) {
    final stateName = json['state']?.toString();
    final state = ExecutionState.values.firstWhere(
      (value) => value.name == stateName,
      orElse: () => ExecutionState.pending,
    );
    return PlannerExecutionRecord(
      entryId: json['entryId']?.toString() ?? '',
      state: state,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'state': state.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class PlannerExecutionSummary {
  const PlannerExecutionSummary({
    required this.plannedCount,
    required this.completedCount,
    required this.remainingCount,
  });

  final int plannedCount;
  final int completedCount;
  final int remainingCount;
}

class PlannerExecutionService {
  static DateTime snapToGrid(DateTime value, TimeGrid grid) {
    final interval = grid == TimeGrid.fifteenMinutes ? 15 : 30;
    final minutes = value.hour * 60 + value.minute;
    final snapped = ((minutes + interval - 1) ~/ interval) * interval;
    final clamped = snapped.clamp(0, 24 * 60 - 1).toInt();
    return DateTime(
      value.year,
      value.month,
      value.day,
      clamped ~/ 60,
      clamped % 60,
    );
  }

  static Map<String, ExecutionState> statesFromEncoded(
    Iterable<String> encoded,
  ) {
    final states = <String, ExecutionState>{};
    for (final value in encoded) {
      try {
        final record = PlannerExecutionRecord.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map),
        );
        if (record.entryId.isNotEmpty) states[record.entryId] = record.state;
      } catch (_) {
        continue;
      }
    }
    return states;
  }

  static List<String> toEncoded(Map<String, ExecutionState> states) {
    return states.entries
        .map(
          (entry) => jsonEncode(
            PlannerExecutionRecord(
              entryId: entry.key,
              state: entry.value,
              updatedAt: DateTime.now(),
            ).toJson(),
          ),
        )
        .toList();
  }

  static PlannerExecutionSummary summarize(
    Iterable<String> entryIds,
    Map<String, ExecutionState> states,
  ) {
    var completed = 0;
    var dismissed = 0;
    var planned = 0;
    for (final entryId in entryIds) {
      planned++;
      switch (states[entryId] ?? ExecutionState.pending) {
        case ExecutionState.completed:
          completed++;
        case ExecutionState.dismissed:
          dismissed++;
        case ExecutionState.pending:
          break;
      }
    }
    return PlannerExecutionSummary(
      plannedCount: planned,
      completedCount: completed,
      remainingCount: planned - completed - dismissed,
    );
  }
}
