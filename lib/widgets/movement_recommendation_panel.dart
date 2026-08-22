import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';

/// Presentation-only panel for the rules-based movement planner.
///
/// Renders the activity context and progress sections from data supplied by the
/// caller. Contains no business logic — all values are pre-computed by
/// [MovementRecommendationService].
class MovementRecommendationPanel extends StatelessWidget {
  const MovementRecommendationPanel({
    super.key,
    required this.dayContext,
    required this.todayTargets,
    required this.weeklyProgress,
    required this.dailyTotals,
    required this.onGymAvailableChanged,
    required this.onWfhAvailableChanged,
    required this.onEveningAvailableChanged,
    required this.onViewActivityHistory,
    this.showContext = true,
  });

  final DayContext dayContext;
  final DayTypeTargets todayTargets;
  final Map<ActivityPillar, ActivityProgress> weeklyProgress;
  final DailyActivityTotals dailyTotals;
  final ValueChanged<bool> onGymAvailableChanged;
  final ValueChanged<bool> onWfhAvailableChanged;
  final ValueChanged<bool> onEveningAvailableChanged;
  final VoidCallback onViewActivityHistory;
  final bool showContext;

  static const _accent = Color(0xFFB05A00);

  String _pillarLabel(ActivityPillar pillar) {
    return switch (pillar) {
      ActivityPillar.walking => 'Walking',
      ActivityPillar.standing => 'Standing',
      ActivityPillar.gym => 'Gym',
      ActivityPillar.zwift => 'Zwift',
      ActivityPillar.mobility => 'Mobility',
    };
  }

  IconData _pillarIcon(ActivityPillar pillar) {
    return switch (pillar) {
      ActivityPillar.walking => Icons.directions_walk_rounded,
      ActivityPillar.standing => Icons.accessibility_new_rounded,
      ActivityPillar.gym => Icons.fitness_center_rounded,
      ActivityPillar.zwift => Icons.directions_bike_rounded,
      ActivityPillar.mobility => Icons.self_improvement_rounded,
    };
  }

  String _pillarUnit(ActivityPillar pillar) {
    return switch (pillar) {
      ActivityPillar.standing => 'min',
      ActivityPillar.walking => 'min',
      ActivityPillar.gym ||
      ActivityPillar.zwift ||
      ActivityPillar.mobility => 'sessions',
    };
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.teal.shade800,
      ),
    );
  }

  Widget _buildContextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Today's context"),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _contextChip(
              label: 'Gym morning',
              selected: dayContext.gymMorning,
              onChanged: onGymAvailableChanged,
            ),
            _contextChip(
              label: dayContext.workLocation == WorkLocation.home
                  ? 'Home'
                  : 'Office',
              selected: dayContext.workLocation == WorkLocation.home,
              onChanged: onWfhAvailableChanged,
            ),
            _contextChip(
              label: dayContext.eveningAvailable
                  ? 'Evening available'
                  : 'Evening unavailable',
              selected: dayContext.eveningAvailable,
              onChanged: onEveningAvailableChanged,
            ),
          ],
        ),
      ],
    );
  }

  Widget _contextChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : _accent,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: _accent,
      backgroundColor: _accent.withAlpha(40),
      side: BorderSide(
        color: selected ? _accent : _accent.withAlpha(145),
        width: selected ? 1.4 : 1.1,
      ),
      onSelected: onChanged,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildWeeklyProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader('Weekly progress')),
            TextButton.icon(
              onPressed: onViewActivityHistory,
              icon: const Icon(Icons.history, size: 13),
              label: const Text('View history'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final pillar in ActivityPillar.values)
          _buildProgressRow(weeklyProgress[pillar]!),
      ],
    );
  }

  Widget _buildDailyProgressSection() {
    final values = <ActivityPillar, ({num current, num target})>{
      ActivityPillar.walking: (
        current: dailyTotals.walkingMinutes,
        target: todayTargets.walkingMinutes.minMinutes,
      ),
      ActivityPillar.standing: (
        current: dailyTotals.standingMinutes,
        target: todayTargets.standingMinutes.minMinutes,
      ),
      ActivityPillar.gym: (
        current: dailyTotals.gymSessions,
        target: todayTargets.gym == RecommendationLevel.no ? 0 : 1,
      ),
      ActivityPillar.zwift: (
        current: dailyTotals.zwiftSessions,
        target: todayTargets.zwift == RecommendationLevel.no ? 0 : 1,
      ),
      ActivityPillar.mobility: (
        current: dailyTotals.mobilitySessions,
        target: todayTargets.mobility == RecommendationLevel.no ? 0 : 1,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Today's progress"),
        const SizedBox(height: 2),
        Text(
          todayTargets.notes,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        for (final entry in values.entries)
          _buildProgressBarRow(
            pillar: entry.key,
            current: entry.value.current,
            target: entry.value.target,
            percent: entry.value.target <= 0
                ? 0
                : (entry.value.current / entry.value.target)
                      .clamp(0.0, 1.0)
                      .toDouble(),
          ),
      ],
    );
  }

  Widget _buildProgressRow(ActivityProgress progress) {
    final percent = (progress.percentComplete / 100).clamp(0.0, 1.0);
    return _buildProgressBarRow(
      pillar: progress.pillar,
      current: progress.current,
      target: progress.target,
      percent: percent,
      metricsWidth: 140,
    );
  }

  Widget _buildProgressBarRow({
    required ActivityPillar pillar,
    required num current,
    required num target,
    required double percent,
    double metricsWidth = 140,
    String? status,
  }) {
    final statusColor = status == 'Target reached'
        ? Colors.green.shade700
        : status == 'In progress'
        ? Colors.orange.shade700
        : Colors.blueGrey.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Row(
              children: [
                Icon(_pillarIcon(pillar), size: 13, color: _accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _pillarLabel(pillar),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                backgroundColor: _accent.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: metricsWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$current/$target ${_pillarUnit(pillar)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showContext) ...[
            _buildContextSection(),
            const SizedBox(height: 8),
          ],
          _buildDailyProgressSection(),
          const SizedBox(height: 8),
          _buildWeeklyProgressSection(),
        ],
      ),
    );
  }
}
