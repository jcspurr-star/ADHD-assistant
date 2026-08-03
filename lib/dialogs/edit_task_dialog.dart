import 'package:flutter/material.dart';

Future<String?> showEditTaskDialog(
  BuildContext context,
  String currentValue,
) async {
  final controller = TextEditingController(text: currentValue);

  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Task"),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}
