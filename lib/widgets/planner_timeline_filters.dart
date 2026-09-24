import 'package:flutter/material.dart';

import 'planner_category_colors.dart';

class PlannerTimelineFilters extends StatelessWidget {
  const PlannerTimelineFilters({
    super.key,
    required this.showWorkCalendar,
    required this.showWorkTasks,
    required this.showHomeCalendar,
    required this.showHomeTasks,
    required this.showMovement,
    required this.showPersonal,
    required this.showBreak,
    required this.onShowWorkCalendarChanged,
    required this.onShowWorkTasksChanged,
    required this.onShowHomeCalendarChanged,
    required this.onShowHomeTasksChanged,
    required this.onShowMovementChanged,
    required this.onShowPersonalChanged,
    required this.onShowBreakChanged,
  });

  final bool showWorkCalendar;
  final bool showWorkTasks;
  final bool showHomeCalendar;
  final bool showHomeTasks;
  final bool showMovement;
  final bool showPersonal;
  final bool showBreak;
  final ValueChanged<bool> onShowWorkCalendarChanged;
  final ValueChanged<bool> onShowWorkTasksChanged;
  final ValueChanged<bool> onShowHomeCalendarChanged;
  final ValueChanged<bool> onShowHomeTasksChanged;
  final ValueChanged<bool> onShowMovementChanged;
  final ValueChanged<bool> onShowPersonalChanged;
  final ValueChanged<bool> onShowBreakChanged;

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    final labelWidget = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : color,
      ),
    );
    return SizedBox(
      width: 128,
      child: FilterChip(
        label: SizedBox(width: 112, child: labelWidget),
        selected: selected,
        showCheckmark: false,
        selectedColor: color,
        backgroundColor: color.withAlpha(40),
        side: BorderSide(
          color: selected ? color : color.withAlpha(145),
          width: selected ? 1.4 : 1.1,
        ),
        onSelected: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      _chip(
        label: 'Work calendar',
        selected: showWorkCalendar,
        color: PlannerCategoryColors.workCalendar,
        onChanged: onShowWorkCalendarChanged,
      ),
      _chip(
        label: 'Work tasks',
        selected: showWorkTasks,
        color: PlannerCategoryColors.workTasks,
        onChanged: onShowWorkTasksChanged,
      ),
      _chip(
        label: 'Home calendar',
        selected: showHomeCalendar,
        color: PlannerCategoryColors.homeCalendar,
        onChanged: onShowHomeCalendarChanged,
      ),
      _chip(
        label: 'Home tasks',
        selected: showHomeTasks,
        color: PlannerCategoryColors.homeTasks,
        onChanged: onShowHomeTasksChanged,
      ),
      _chip(
        label: 'Movement',
        selected: showMovement,
        color: PlannerCategoryColors.movement,
        onChanged: onShowMovementChanged,
      ),
      _chip(
        label: 'Personal',
        selected: showPersonal,
        color: PlannerCategoryColors.personal,
        onChanged: onShowPersonalChanged,
      ),
      _chip(
        label: 'Break',
        selected: showBreak,
        color: PlannerCategoryColors.breakEntry,
        onChanged: onShowBreakChanged,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          dense: true,
          visualDensity: VisualDensity.compact,
          minTileHeight: 32,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: const Icon(Icons.filter_list, size: 16),
          title: const Text(
            'Timeline filters',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          children: [Wrap(spacing: 4, runSpacing: 4, children: chips)],
        ),
      ),
    );
  }
}
