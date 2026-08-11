import 'package:flutter/material.dart';

import 'insights_view.dart';

typedef ParseScoreField =
    int Function(Map<String, dynamic> raw, String key, {dynamic legacyValue});

class InsightsSection extends StatelessWidget {
  const InsightsSection({
    super.key,
    required this.dailyCheckinsByDate,
    required this.parseScoreField,
    required this.parseStringList,
    required this.wideContentWidth,
  });

  final Map<String, Map<String, dynamic>> dailyCheckinsByDate;
  final ParseScoreField parseScoreField;
  final List<String> Function(dynamic value) parseStringList;
  final double wideContentWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : wideContentWidth.clamp(0, constraints.maxWidth).toDouble();

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
}
