import 'package:flutter/material.dart';

class TaskDetailsPane extends StatelessWidget {
  const TaskDetailsPane({
    super.key,
    required this.hasSelection,
    this.title,
    this.child,
    this.placeholderText = 'Select a task to show details',
  });

  final bool hasSelection;
  final String? title;
  final Widget? child;
  final String placeholderText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: !hasSelection
          ? Center(
              child: Text(
                placeholderText,
                style: TextStyle(
                  color: Colors.blueGrey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ?child,
                ],
              ),
            ),
    );
  }
}
