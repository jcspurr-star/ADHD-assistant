import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.tabs,
    required this.syncBadge,
    required this.isBusy,
    required this.onUndo,
    required this.onSettingsTap,
  });

  final Widget tabs;
  final Widget syncBadge;
  final bool isBusy;
  final VoidCallback onUndo;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    Widget buildUndoWithDivider() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last action',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: const CircleBorder(),
            ),
            onPressed: isBusy ? null : onUndo,
          ),
          Container(
            width: 2,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade500,
          ),
        ],
      );
    }

    Widget buildActions() {
      return LayoutBuilder(
        builder: (context, actionsConstraints) {
          // Measure the actual space allocated to the actions row itself
          // (not the whole header) so right-aligned buttons aren't pushed
          // out of view when this sits beside the tabs in a wide Row.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: actionsConstraints.maxWidth,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  syncBadge,
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSettingsTap,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  buildUndoWithDivider(),
                  Expanded(child: tabs),
                ],
              ),
              const SizedBox(height: 6),
              buildActions(),
            ],
          );
        }
        return Row(
          children: [
            buildUndoWithDivider(),
            Expanded(child: tabs),
            const SizedBox(width: 8),
            Expanded(child: buildActions()),
          ],
        );
      },
    );
  }
}
