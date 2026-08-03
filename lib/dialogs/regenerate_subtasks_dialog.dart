import 'package:flutter/material.dart';

Future<bool> showRegenerateSubtasksDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Regenerate Subtasks"),
          content: const Text(
            "Replace existing subtasks with a new AI-generated set?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Replace"),
            ),
          ],
        ),
      ) ??
      false;
}
