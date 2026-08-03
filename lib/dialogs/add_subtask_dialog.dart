import 'package:flutter/material.dart';

Future<String?> showAddSubtaskDialog(BuildContext context) async {
  final controller = TextEditingController();

  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Add Subtask"),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          Navigator.pop(context, controller.text.trim());
        },
        decoration: const InputDecoration(labelText: "Subtask"),
      ),
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
          child: const Text("Add"),
        ),
      ],
    ),
  );
}
