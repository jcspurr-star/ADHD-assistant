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
      return LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumnLayout = constraints.maxWidth >= 980;

          if (useTwoColumnLayout) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 900),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 900),
                        child: buildTasksView(
                          showOverview: true,
                          showTaskList: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 900),
                        child: SingleChildScrollView(
                          child: buildTasksView(
                            showOverview: false,
                            showTaskList: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 900),
                      child: SizedBox(width: 460, child: buildCountdownView()),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildTasksView(showOverview: true, showTaskList: false),
                const SizedBox(height: 16),
                buildTasksView(showOverview: false, showTaskList: true),
                const SizedBox(height: 16),
                buildCountdownView(),
              ],
            ),
          );
        },
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
