import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MainContentView extends StatelessWidget {
  const MainContentView({
    super.key,
    required this.selectedMainSectionIndex,
    required this.buildTasksView,
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
  final Widget Function() buildCountdownView;
  final Widget Function() buildInsightsView;
  final Widget Function() buildNotesView;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && selectedMainSectionIndex == 0) {
      return SingleChildScrollView(
        child: buildTasksView(showOverview: true, showTaskList: false),
      );
    }

    switch (selectedMainSectionIndex) {
      case 0:
        return SingleChildScrollView(
          child: buildTasksView(showOverview: true, showTaskList: false),
        );
      case 1:
        return buildCountdownView();
      case 2:
        return buildTasksView(showOverview: false, showTaskList: true);
      case 3:
        return buildInsightsView();
      default:
        return buildNotesView();
    }
  }
}
