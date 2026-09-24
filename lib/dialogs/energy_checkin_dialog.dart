import 'package:flutter/material.dart';

import '../models/menu_planning.dart';

/// "How are you feeling right now?" — Menu-Based Planning's daily (and
/// on-demand) energy check-in.
Future<EnergyState?> showEnergyCheckInDialog(
  BuildContext context, {
  EnergyState? currentState,
}) {
  return showDialog<EnergyState>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('How are you feeling right now?'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final state in EnergyState.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, state),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: state == currentState
                          ? Colors.blue.shade50
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(state.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Text(
                          state.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
        ],
      );
    },
  );
}
