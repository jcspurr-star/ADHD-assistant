import 'package:flutter/material.dart';

import 'insights_view.dart';
import 'symptom_tracker_section.dart';

typedef ParseScoreField =
    int Function(Map<String, dynamic> raw, String key, {dynamic legacyValue});

class InsightsSection extends StatelessWidget {
  const InsightsSection({
    super.key,
    required this.dailyCheckinsByDate,
    required this.parseScoreField,
    required this.parseStringList,
    required this.wideContentWidth,
    required this.todayCheckin,
    required this.symptomTrackerLabels,
    required this.dailyContextOptions,
    required this.otherMedicationOptions,
    required this.dopamineCrashSymptomOptions,
    required this.dopamineCrashAdditionalSymptomOptions,
    required this.onSetTodayDailyRating,
    required this.onSetTodayMedicationTime,
    required this.onClearTodayMedicationTime,
    required this.onSetTodayMedicationQuickTime,
    required this.onToggleTodayOtherMedication,
    required this.onSetTodayCrashTimeField,
    required this.onClearTodayCrashTimeField,
    required this.onToggleTodayCrashSymptomField,
    required this.onToggleTodayContextTag,
    required this.wfhAvailable,
    required this.onWfhAvailableChanged,
    required this.gymAvailable,
    required this.onGymAvailableChanged,
  });

  final Map<String, Map<String, dynamic>> dailyCheckinsByDate;
  final ParseScoreField parseScoreField;
  final List<String> Function(dynamic value) parseStringList;
  final double wideContentWidth;
  final Map<String, dynamic> todayCheckin;
  final Map<String, String> symptomTrackerLabels;
  final List<String> dailyContextOptions;
  final List<String> otherMedicationOptions;
  final List<String> dopamineCrashSymptomOptions;
  final List<String> dopamineCrashAdditionalSymptomOptions;
  final Future<void> Function(String field, int value) onSetTodayDailyRating;
  final Future<void> Function(String field, String helpText)
  onSetTodayMedicationTime;
  final Future<void> Function(String field) onClearTodayMedicationTime;
  final Future<void> Function(String field, String value)
  onSetTodayMedicationQuickTime;
  final Future<void> Function(String medication) onToggleTodayOtherMedication;
  final Future<void> Function(String field, String helpText)
  onSetTodayCrashTimeField;
  final Future<void> Function(String field) onClearTodayCrashTimeField;
  final Future<void> Function(String field, String symptom)
  onToggleTodayCrashSymptomField;
  final Future<void> Function(String tag) onToggleTodayContextTag;
  final bool wfhAvailable;
  final ValueChanged<bool> onWfhAvailableChanged;
  final bool gymAvailable;
  final ValueChanged<bool> onGymAvailableChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : constraints.maxWidth;

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

        final showSideBySide = constraints.maxWidth >= 900;
        final trackerWidth = showSideBySide
            ? ((contentWidth - 12) / 2).clamp(0.0, contentWidth).toDouble()
            : contentWidth;
        final insightsWidth = showSideBySide ? trackerWidth : contentWidth;

        Widget buildTracker() {
          return SizedBox(
            width: trackerWidth,
            height: showSideBySide ? 860 : null,
            child: SymptomTrackerSection(
              checkin: todayCheckin,
              symptomTrackerLabels: symptomTrackerLabels,
              dailyContextOptions: dailyContextOptions,
              otherMedicationOptions: otherMedicationOptions,
              dopamineCrashSymptomOptions: dopamineCrashSymptomOptions,
              dopamineCrashAdditionalSymptomOptions:
                  dopamineCrashAdditionalSymptomOptions,
              useWideWebOverviewColumns: constraints.maxWidth >= 1200,
              onSetTodayDailyRating: onSetTodayDailyRating,
              onSetTodayMedicationTime: onSetTodayMedicationTime,
              onClearTodayMedicationTime: onClearTodayMedicationTime,
              onSetTodayMedicationQuickTime: onSetTodayMedicationQuickTime,
              onToggleTodayOtherMedication: onToggleTodayOtherMedication,
              onSetTodayCrashTimeField: onSetTodayCrashTimeField,
              onClearTodayCrashTimeField: onClearTodayCrashTimeField,
              onToggleTodayCrashSymptomField: onToggleTodayCrashSymptomField,
              onToggleTodayContextTag: onToggleTodayContextTag,
              wfhAvailable: wfhAvailable,
              onWfhAvailableChanged: onWfhAvailableChanged,
              gymAvailable: gymAvailable,
              onGymAvailableChanged: onGymAvailableChanged,
            ),
          );
        }

        return SingleChildScrollView(
          child: showSideBySide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTracker(),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: insightsWidth,
                      child: InsightsView(
                        records: records,
                        contentWidth: insightsWidth,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTracker(),
                    const SizedBox(height: 12),
                    InsightsView(records: records, contentWidth: contentWidth),
                  ],
                ),
        );
      },
    );
  }
}
