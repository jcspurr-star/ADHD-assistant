import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.tabs,
    required this.syncBadge,
    required this.onBackupTap,
    required this.onOutlookTap,
    required this.onSettingsTap,
  });

  final Widget tabs;
  final Widget syncBadge;
  final VoidCallback onBackupTap;
  final VoidCallback onOutlookTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: tabs),
        const SizedBox(width: 8),
        syncBadge,
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.restore_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          tooltip: 'Recover backup',
          visualDensity: VisualDensity.compact,
          onPressed: onBackupTap,
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Link Outlook',
          visualDensity: VisualDensity.compact,
          onPressed: onOutlookTap,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          visualDensity: VisualDensity.compact,
          onPressed: onSettingsTap,
        ),
      ],
    );
  }
}
