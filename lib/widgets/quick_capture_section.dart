import 'package:flutter/material.dart';

class QuickCaptureSection extends StatelessWidget {
  const QuickCaptureSection({
    super.key,
    required this.inboxEntries,
    required this.inboxCaptureController,
    required this.onAddInboxEntry,
    required this.onConvertInboxEntryToTask,
    required this.onRemoveInboxEntry,
  });

  final List<String> inboxEntries;
  final TextEditingController inboxCaptureController;
  final Future<void> Function() onAddInboxEntry;
  final Future<void> Function(int index) onConvertInboxEntryToTask;
  final Future<void> Function(int index) onRemoveInboxEntry;

  @override
  Widget build(BuildContext context) {
    final previewEntries = inboxEntries.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick capture',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${inboxEntries.length} saved',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inboxCaptureController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async {
                    await onAddInboxEntry();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Quick capture a thought...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAddInboxEntry,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recent captures',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          if (previewEntries.isEmpty)
            Text(
              'Add a thought above and it will appear here.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            )
          else
            ...previewEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Convert to task',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: const Icon(Icons.task_alt, size: 16),
                        onPressed: () async {
                          await onConvertInboxEntryToTask(index);
                        },
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          await onRemoveInboxEntry(index);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
