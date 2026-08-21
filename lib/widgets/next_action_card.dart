import 'package:flutter/material.dart';

import '../services/next_action_service.dart';

class NextActionCard extends StatelessWidget {
  const NextActionCard({
    super.key,
    required this.recommendation,
    this.onOpen,
    this.onComplete,
  });

  final NextActionRecommendation recommendation;
  final VoidCallback? onOpen;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final canOpen = onOpen != null;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: InkWell(
        onTap: canOpen ? onOpen : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.next_plan_outlined, color: Colors.teal.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What should I do next?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.teal.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recommendation.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (recommendation.description.trim().isNotEmpty)
                          Text(
                            recommendation.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        Text(
                          'Reason: ${recommendation.reason}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${recommendation.estimatedMinutes} mins',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  if (canOpen) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: Colors.teal.shade600),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Complete'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
