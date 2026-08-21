import 'package:flutter/material.dart';

class SymptomTrackerSection extends StatelessWidget {
  const SymptomTrackerSection({
    super.key,
    required this.checkin,
    required this.symptomTrackerLabels,
    required this.dailyContextOptions,
    required this.otherMedicationOptions,
    required this.dopamineCrashSymptomOptions,
    required this.dopamineCrashAdditionalSymptomOptions,
    required this.useWideWebOverviewColumns,
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

  final Map<String, dynamic> checkin;
  final Map<String, String> symptomTrackerLabels;
  final List<String> dailyContextOptions;
  final List<String> otherMedicationOptions;
  final List<String> dopamineCrashSymptomOptions;
  final List<String> dopamineCrashAdditionalSymptomOptions;
  final bool useWideWebOverviewColumns;

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

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList();
    }
    return <String>[];
  }

  Widget _buildSubtleScrollHint(Color color) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: color.withAlpha(170),
          ),
          const SizedBox(width: 2),
          Text(
            'scroll',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withAlpha(170),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final otherMedicationsTaken = _parseStringList(
      checkin['otherMedicationsTaken'],
    );
    final dopamineCrashStartTime = (checkin['dopamineCrashStartTime'] ?? '')
        .toString();
    final dopamineCrashEndTime = (checkin['dopamineCrashEndTime'] ?? '')
        .toString();
    final dopamineCrashSymptoms = _parseStringList(
      checkin['dopamineCrashSymptoms'],
    );
    final dopamineCrashAdditionalSymptoms = _parseStringList(
      checkin['dopamineCrashSymptomsAdditional'],
    );
    final contextTags = _parseStringList(checkin['contextTags']);

    final fixedContextColumns = <List<String>>[
      ['Good sleep', 'Bad sleep', 'Gym'],
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

    final trackerViewportHeight = MediaQuery.of(context).size.height;
    final fallbackTrackerTabHeight = useWideWebOverviewColumns
        ? (trackerViewportHeight * 0.36).clamp(250.0, 390.0).toDouble()
        : (trackerViewportHeight * 0.28).clamp(200.0, 288.0).toDouble();

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
            color: hasSelection ? Colors.white : accentColor.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasSelection
                  ? accentColor.withAlpha(90)
                  : accentColor.withAlpha(55),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, rowConstraints) {
              final useCompactControls = rowConstraints.maxWidth < 430;
              final labelWidth = (rowConstraints.maxWidth * 0.24)
                  .clamp(
                    useCompactControls ? 78.0 : 105.0,
                    useCompactControls ? 122.0 : 155.0,
                  )
                  .toDouble();
              final ratingChipSpacing = useCompactControls ? 3.0 : 4.0;

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
                    child: LayoutBuilder(
                      builder: (context, chipConstraints) {
                        const ratingValues = <int>[
                          0,
                          1,
                          2,
                          3,
                          4,
                          5,
                          6,
                          7,
                          8,
                          9,
                          10,
                        ];

                        Widget buildRatingChip(int rating) {
                          return ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                rating.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            selected: value == rating,
                            labelPadding: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 0,
                            ),
                            selectedColor: accentColor.withAlpha(44),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: accentColor.withAlpha(80)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) async {
                              await onSetTodayDailyRating(field, rating);
                            },
                            visualDensity: VisualDensity.compact,
                          );
                        }

                        Widget buildNaChip() {
                          return ChoiceChip(
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
                            side: BorderSide(color: accentColor.withAlpha(80)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) async {
                              await onSetTodayDailyRating(field, -1);
                            },
                            visualDensity: VisualDensity.compact,
                          );
                        }

                        final gridSpacing = ratingChipSpacing;
                        Widget buildChipRow(List<Widget> chips) {
                          return Row(
                            children: chips.asMap().entries.map((entry) {
                              final index = entry.key;
                              final chip = entry.value;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index == chips.length - 1
                                        ? 0
                                        : gridSpacing,
                                  ),
                                  child: chip,
                                ),
                              );
                            }).toList(),
                          );
                        }

                        final topRowChips = ratingValues
                            .take(6)
                            .map((rating) => buildRatingChip(rating))
                            .toList();

                        final bottomRowChips = [
                          ...ratingValues
                              .skip(6)
                              .map((rating) => buildRatingChip(rating)),
                          buildNaChip(),
                        ];

                        final allRatingChips = [
                          ...ratingValues.map(
                            (rating) => buildRatingChip(rating),
                          ),
                          buildNaChip(),
                        ];
                        final canUseSingleRow =
                            useWideWebOverviewColumns &&
                            chipConstraints.maxWidth >= 500;

                        return Column(
                          children: [
                            if (canUseSingleRow)
                              buildChipRow(allRatingChips)
                            else ...[
                              buildChipRow(topRowChips),
                              SizedBox(height: gridSpacing),
                              buildChipRow(bottomRowChips),
                            ],
                          ],
                        );
                      },
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
                await onSetTodayMedicationTime(timeField, timeHelpText);
              },
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              child: const Text('Set'),
            ),
            if (timeValue.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await onClearTodayMedicationTime(timeField);
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await onSetTodayMedicationQuickTime(field, quickTime);
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(quickLabel),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await onSetTodayMedicationTime(field, pickerHelpText);
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Set'),
                ),
                if (value.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await onClearTodayMedicationTime(field);
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

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
                        await onToggleTodayCrashSymptomField(field, symptom);
                      },
                      labelPadding: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

    Widget buildGeneralTab() {
      return SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 14),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(columnCount, (columnIndex) {
                    final tags = contextColumns[columnIndex];
                    final isLast = columnIndex == columnCount - 1;

                    return Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: tags.map((tag) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: chipVerticalGap,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: chipHeight,
                                    child: FilterChip(
                                      label: SizedBox(
                                        width: double.infinity,
                                        child: Text(
                                          tag,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          softWrap: true,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                      selected: switch (tag) {
                                        'WFH' => wfhAvailable,
                                        'WFO' => !wfhAvailable,
                                        'Gym' => gymAvailable,
                                        _ => contextTags.contains(tag),
                                      },
                                      onSelected: (_) async {
                                        if (tag == 'WFH' || tag == 'WFO') {
                                          onWfhAvailableChanged(!wfhAvailable);
                                        } else if (tag == 'Gym') {
                                          onGymAvailableChanged(!gymAvailable);
                                        } else {
                                          await onToggleTodayContextTag(tag);
                                        }
                                      },
                                      labelPadding: EdgeInsets.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
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
                              color: Colors.indigo.shade100.withAlpha(150),
                            ),
                            const SizedBox(width: columnGap - 4),
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
              label: symptomTrackerLabels['restlessness']!,
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
              label: symptomTrackerLabels['emotionalRegulation']!,
              field: 'emotionalRegulation',
              value: emotionalRegulation,
            ),
            Text(
              '1 = low, 10 = very strong',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    Widget buildMealsTab() {
      return SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildMealRow(
              label: 'Breakfast quality',
              scoreField: 'breakfastScore',
              scoreValue: breakfastScore,
              timeField: 'breakfastTime',
              timeValue: breakfastTime,
              timeHelpText: 'When did you have breakfast?',
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
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    Widget buildMedicationTab() {
      return SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildMedicationTimeRow(
              label: 'Concerta XL',
              field: 'concertaXlTime',
              value: concertaXlTime,
              pickerHelpText: 'When did you take Concerta XL?',
              quickTime: '08:00',
              quickLabel: '8:00 AM',
            ),
            buildMedicationTimeRow(
              label: 'Concerta IR',
              field: 'concertaIrTime',
              value: concertaIrTime,
              pickerHelpText: 'When did you take Concerta IR?',
              quickTime: '16:30',
              quickLabel: '4:30 PM',
            ),
            const SizedBox(height: 8),
            const Text(
              'Other medications',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 6.0;
                const targetColumns = 4;
                if (otherMedicationOptions.isEmpty) {
                  return const SizedBox.shrink();
                }

                final columns = otherMedicationOptions.length < targetColumns
                    ? otherMedicationOptions.length
                    : targetColumns;
                final chipWidth =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: otherMedicationOptions.map((med) {
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
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        selected: otherMedicationsTaken.contains(med),
                        onSelected: (_) async {
                          await onToggleTodayOtherMedication(med);
                        },
                        labelPadding: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
    }

    Widget buildCrashTab() {
      return SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Crash start:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                    await onSetTodayCrashTimeField(
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
                      await onClearTodayCrashTimeField(
                        'dopamineCrashStartTime',
                      );
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                    await onSetTodayCrashTimeField(
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
                      await onClearTodayCrashTimeField('dopamineCrashEndTime');
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
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
              options: dopamineCrashAdditionalSymptomOptions,
              selected: dopamineCrashAdditionalSymptoms,
              field: 'dopamineCrashSymptomsAdditional',
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        return Container(
          clipBehavior: Clip.hardEdge,
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
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Colors.indigo.shade400,
                  ),
                ],
              ),
              _buildSubtleScrollHint(Colors.indigo.shade500),
              const SizedBox(height: 8),
              if (hasBoundedHeight)
                Expanded(
                  child: DefaultTabController(
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
                        Expanded(
                          child: TabBarView(
                            children: [
                              buildGeneralTab(),
                              buildMealsTab(),
                              buildMedicationTab(),
                              buildCrashTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
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
                        height: fallbackTrackerTabHeight,
                        child: TabBarView(
                          children: [
                            buildGeneralTab(),
                            buildMealsTab(),
                            buildMedicationTab(),
                            buildCrashTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
