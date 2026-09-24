import 'package:flutter/material.dart';

import '../models/menu_planning.dart';
import '../models/task.dart';
import '../services/menu_recommendation_service.dart';

/// Menu-Based Planning's home screen: tasks grouped into restaurant-style
/// menu sections instead of a schedule, with recommendations that match the
/// user's current energy state.
class TodaysMenuPage extends StatefulWidget {
  const TodaysMenuPage({
    super.key,
    required this.tasks,
    required this.energyState,
    required this.onChangeEnergyState,
    required this.onToggleTask,
    required this.onCategorizeTask,
    required this.onReorderCategory,
  });

  final List<Task> tasks;
  final EnergyState? energyState;
  final VoidCallback onChangeEnergyState;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<Task> onCategorizeTask;
  final void Function(MenuCategory category, int oldIndex, int newIndex)
  onReorderCategory;

  @override
  State<TodaysMenuPage> createState() => _TodaysMenuPageState();
}

class _TodaysMenuPageState extends State<TodaysMenuPage> {
  final Set<MenuCategory> _collapsed = {};

  List<Task> _tasksFor(MenuCategory category) {
    return widget.tasks
        .where(
          (task) =>
              !task.done &&
              (task.menuCategory ?? MenuCategory.sideDish) == category,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.energyState;
    final recommendations = state == null
        ? const <TaskRecommendation>[]
        : MenuRecommendationService.recommend(widget.tasks, state, limit: 3);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        _buildEnergyBanner(context, state),
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRecommendations(context, recommendations, state!),
        ],
        const SizedBox(height: 16),
        for (final category in MenuCategory.values)
          _buildCategorySection(context, category),
      ],
    );
  }

  Widget _buildEnergyBanner(BuildContext context, EnergyState? state) {
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: Text(
          state?.emoji ?? '❓',
          style: const TextStyle(fontSize: 28),
        ),
        title: const Text(
          "Today's Menu",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          state == null
              ? 'Check in to get recommendations that match your capacity.'
              : 'Feeling: ${state.label}',
        ),
        trailing: OutlinedButton(
          onPressed: widget.onChangeEnergyState,
          child: Text(state == null ? 'Check in' : 'Change'),
        ),
      ),
    );
  }

  Widget _buildRecommendations(
    BuildContext context,
    List<TaskRecommendation> recommendations,
    EnergyState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended for you',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (MenuRecommendationService.shouldShowHyperfocusReminder(state))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Remember to take a recovery break afterwards.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            for (final recommendation in recommendations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  (recommendation.task.menuCategory ?? MenuCategory.sideDish)
                      .emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(recommendation.task.task),
                subtitle: Text(recommendation.reason),
                trailing: Checkbox(
                  value: recommendation.task.done,
                  onChanged: (_) => widget.onToggleTask(recommendation.task),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, MenuCategory category) {
    final tasksInCategory = _tasksFor(category);
    final isCollapsed = _collapsed.contains(category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Text(category.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(
              category.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              tasksInCategory.isEmpty
                  ? category.purpose
                  : '${tasksInCategory.length} to do',
            ),
            trailing: IconButton(
              icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less),
              onPressed: () => setState(() {
                if (isCollapsed) {
                  _collapsed.remove(category);
                } else {
                  _collapsed.add(category);
                }
              }),
            ),
          ),
          if (!isCollapsed && tasksInCategory.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasksInCategory.length,
              onReorder: (oldIndex, newIndex) =>
                  widget.onReorderCategory(category, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final task = tasksInCategory[index];
                return ListTile(
                  key: ValueKey(task.id),
                  leading: Checkbox(
                    value: task.done,
                    onChanged: (_) => widget.onToggleTask(task),
                  ),
                  title: Text(
                    task.task,
                    style: task.done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    [
                      (task.energyRequired ?? EnergyRequirement.medium).label,
                      (task.focusRequired ?? FocusRequirement.medium).label,
                    ].join(' • '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Categorize task',
                    onPressed: () => widget.onCategorizeTask(task),
                  ),
                );
              },
            )
          else if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No tasks here yet. Use the tune icon on a task to add it to this section.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
