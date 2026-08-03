import 'package:flutter/material.dart';

Future<int?> showStepCountDialog(BuildContext context) async {
  final controller = TextEditingController(text: "5");

  return await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Generate Subtasks"),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: "Number of steps"),
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
            final count = int.tryParse(controller.text);

            Navigator.pop(context, count);
          },
          child: const Text("Generate"),
        ),
      ],
    ),
  );
}
