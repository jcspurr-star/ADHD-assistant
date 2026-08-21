import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';

/// Presentation-only panel for the rules-based movement planner.
///
/// Renders the four planner sections (today's context, today's targets,
/// weekly progress, recommended next actions) from data supplied by the
/// caller. Contains no business logic — all values are pre-computed by
/// [MovementRecommendationService].
class MovementRecommendationPanel extends StatelessWidget {
  const MovementRecommendationPanel({
    super.key,
    required this.dayContext,
    required this.todayTargets,
    required this.weeklyProgress,
    required this.recommendations,
    required this.onGymAvailableChanged,
    required this.onWfhAvailableChanged,
    required this.onEveningAvailableChanged,
    required this.completedActivityPillars,
    required this.onCompleteRecommendation,
    required this.onViewActivityHistory,
    this.showContext = true,
  });

  final DayContext dayContext;
  final DayTypeTargets todayTargets;
  final Map<ActivityPillar, ActivityProgress> weeklyProgress;
  final List<ActivityRecommendation> recommendations;
  final ValueChanged<bool> onGymAvailableChanged;
  final ValueChanged<bool> onWfhAvailableChanged;
  final ValueChanged<bool> onEveningAvailableChanged;
  final Set<ActivityPillar> completedActivityPillars;
  final ValueChanged<ActivityRecommendation> onCompleteRecommendation;
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
      ActivityPillar.standing => 'hrs',
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

  Widget _buildTargetsSection() {
    final standingHoursMin = (todayTargets.standingMinutes.minMinutes / 60);
    final standingHoursMax = (todayTargets.standingMinutes.maxMinutes / 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Today's targets"),
        const SizedBox(height: 4),
        Text(
          'Walking: ${todayTargets.walkingMinutes.minMinutes}-${todayTargets.walkingMinutes.maxMinutes} min',
          style: const TextStyle(fontSize: 11),
        ),
        Text(
          'Standing: ${standingHoursMin.toStringAsFixed(0)}-${standingHoursMax.toStringAsFixed(0)} hrs',
          style: const TextStyle(fontSize: 11),
        ),
        Text(
          'Gym: ${todayTargets.gym.name} • Mobility: ${todayTargets.mobility.name} • Zwift: ${todayTargets.zwift.name}',
          style: const TextStyle(fontSize: 11),
        ),
        Text(
          todayTargets.notes,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
      ],
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

  Widget _buildProgressRow(ActivityProgress progress) {
    final percent = (progress.percentComplete / 100).clamp(0.0, 1.0);
    final status = progress.current >= progress.target
        ? 'Complete'
        : progress.deficit == 0
        ? 'On Track'
        : 'Behind';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(_pillarIcon(progress.pillar), size: 13, color: _accent),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: Text(
              _pillarLabel(progress.pillar),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
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
          Text(
            '${progress.current}/${progress.target} ${_pillarUnit(progress.pillar)}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          Text(
            '${progress.percentComplete.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: status == 'Complete'
                  ? Colors.green.shade700
                  : status == 'On Track'
                  ? Colors.orange.shade700
                  : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recommended next actions'),
        const SizedBox(height: 4),
        if (recommendations.isEmpty)
          Text(
            'No movement recommendations for today\'s context.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          )
        else
          for (final recommendation in recommendations)
            Builder(
              builder: (context) {
                final completed = completedActivityPillars.contains(
                  recommendation.pillar,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _pillarIcon(recommendation.pillar),
                        size: 14,
                        color: Colors.teal.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recommendation.title,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              recommendation.description,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recommendation.estimatedDuration.inMinutes} min',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: completed
                            ? null
                            : () => onCompleteRecommendation(recommendation),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: Text(
                          completed ? 'Complete' : 'Mark complete',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ],
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
          _buildTargetsSection(),
          const SizedBox(height: 8),
          _buildWeeklyProgressSection(),
          const SizedBox(height: 8),
          _buildRecommendationsSection(),
        ],
      ),
    );
  }
}
