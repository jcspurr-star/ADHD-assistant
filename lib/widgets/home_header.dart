import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.tabs,
    required this.syncBadge,
    required this.isBusy,
    required this.showImportCalendar,
    required this.onUndo,
    required this.onOutlookTap,
    required this.onImportCalendar,
    required this.onSettingsTap,
  });

  final Widget tabs;
  final Widget syncBadge;
  final bool isBusy;
  final bool showImportCalendar;
  final VoidCallback onUndo;
  final VoidCallback onOutlookTap;
  final VoidCallback onImportCalendar;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    Widget buildActions(BoxConstraints constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              syncBadge,
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo last action',
                visualDensity: VisualDensity.compact,
                onPressed: isBusy ? null : onUndo,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Sync Outlook'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: isBusy ? null : onOutlookTap,
              ),
              if (showImportCalendar)
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload ICS'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: isBusy ? null : onImportCalendar,
                ),
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
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tabs,
              const SizedBox(height: 6),
              buildActions(constraints),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: tabs),
            const SizedBox(width: 8),
            Expanded(child: buildActions(constraints)),
          ],
        );
      },
    );
  }
}
