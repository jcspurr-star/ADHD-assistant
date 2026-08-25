import 'package:flutter/material.dart';

class MainSectionTabs extends StatelessWidget {
  const MainSectionTabs({
    super.key,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Home',
      'Timer',
      'Task list',
      'Insights',
      'Notes',
      'Tasks V2',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          final currentLabel =
              selectedIndex >= 0 && selectedIndex < labels.length
              ? labels[selectedIndex]
              : labels.first;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<int>(
                tooltip: 'Select page',
                icon: const Icon(Icons.menu),
                onSelected: onSelectIndex,
                itemBuilder: (context) => [
                  for (var index = 0; index < labels.length; index++)
                    PopupMenuItem<int>(
                      value: index,
                      child: Text(labels[index]),
                    ),
                ],
              ),
              Text(
                currentLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(labels.length, (index) {
              final isSelected = selectedIndex == index;
              return Padding(
                padding: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : 8,
                ),
                child: OutlinedButton(
                  onPressed: () => onSelectIndex(index),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.blue.shade700
                        : Colors.white,
                    foregroundColor: isSelected
                        ? Colors.white
                        : Colors.grey.shade800,
                    side: BorderSide(
                      color: isSelected
                          ? Colors.blue.shade700
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    labels[index],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
