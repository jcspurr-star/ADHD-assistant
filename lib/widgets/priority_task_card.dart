import 'package:flutter/material.dart';

class PriorityTaskCard extends StatelessWidget {
  const PriorityTaskCard({
    super.key,
    required this.width,
    required this.position,
    required this.title,
    required this.categoryLabel,
    required this.priorityLabel,
    required this.dateLabel,
    required this.priorityAccentColor,
    required this.useWideWebOverviewColumns,
    this.onTap,
  });

  final double width;
  final int position;
  final String? title;
  final String? categoryLabel;
  final String? priorityLabel;
  final String? dateLabel;
  final Color priorityAccentColor;
  final bool useWideWebOverviewColumns;
  final VoidCallback? onTap;

  Widget _buildMetaBox(
    String value, {
    required bool isUrgencyBox,
    required Color accentColor,
  }) {
    return Tooltip(
      message: value.trim().isEmpty ? 'No value' : value,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isUrgencyBox
              ? accentColor.withAlpha(72)
              : Colors.white.withAlpha(170),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUrgencyBox
                ? accentColor.withAlpha(180)
                : Colors.grey.shade300,
            width: isUrgencyBox ? 1.5 : 1,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value.isEmpty ? ' ' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isUrgencyBox ? Colors.black : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: useWideWebOverviewColumns ? 124 : 0,
          ),
          child: title == null
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No task',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('Add more tasks to fill this slot.'),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          position == 0
                              ? '#1'
                              : position == 1
                              ? '#2'
                              : '#3',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              title!,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildMetaBox(
                      priorityLabel ?? '',
                      isUrgencyBox: true,
                      accentColor: priorityAccentColor,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetaBox(
                            categoryLabel ?? '',
                            isUrgencyBox: false,
                            accentColor: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetaBox(
                            dateLabel ?? '',
                            isUrgencyBox: false,
                            accentColor: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );

    if (onTap == null) {
      return SizedBox(width: width, child: card);
    }

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}
