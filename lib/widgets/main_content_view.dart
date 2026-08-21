import 'package:flutter/material.dart';

class MainContentView extends StatelessWidget {
  const MainContentView({
    super.key,
    required this.selectedMainSectionIndex,
    required this.buildTasksView,
    required this.buildHomeDashboard,
    required this.buildCombinedHomePlanner,
    required this.buildCountdownView,
    required this.buildInsightsView,
    required this.buildNotesView,
  });

  final int selectedMainSectionIndex;
  final Widget Function({
    required bool showOverview,
    required bool showTaskList,
  })
  buildTasksView;
  final Widget Function() buildHomeDashboard;
  final Widget Function() buildCombinedHomePlanner;
  final Widget Function() buildCountdownView;
  final Widget Function() buildInsightsView;
  final Widget Function() buildNotesView;

  @override
  Widget build(BuildContext context) {
    switch (selectedMainSectionIndex) {
      case 0:
        return buildCombinedHomePlanner();
      case 1:
        return buildCountdownView();
      case 2:
        return buildTasksView(showOverview: false, showTaskList: true);
      case 3:
        return buildInsightsView();
      case 4:
        return buildNotesView();
      default:
        return buildHomeDashboard();
    }
  }
}
