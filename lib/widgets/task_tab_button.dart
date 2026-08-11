import 'package:flutter/material.dart';

class TaskTabButton extends StatelessWidget {
  const TaskTabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue.shade600 : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.grey.shade800,
          side: BorderSide(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
