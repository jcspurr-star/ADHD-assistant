import 'package:flutter/material.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({
    super.key,
    required this.records,
    required this.contentWidth,
  });

  final List<Map<String, dynamic>> records;
  final double contentWidth;

  List<Map<String, dynamic>> takeLastRecords(int count) {
    if (records.length <= count) {
      return records;
    }
    return records.sublist(records.length - count);
  }

  double averageForField(List<Map<String, dynamic>> input, String field) {
    final values = input
        .map((record) => record[field])
        .whereType<int>()
        .where((value) => value >= 0)
        .toList();
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  String formatDateShort(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  Widget buildStatCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget buildTrendRow({
    required String title,
    required String field,
    required Color color,
  }) {
    final recent = takeLastRecords(14);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '14-day trend',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(recent.length, (index) {
                final score = (recent[index][field] as int?) ?? -2;
                final normalized = score >= 0 ? (score / 10.0) : 0.0;
                final barHeight = score >= 0
                    ? (8 + (normalized * 34)).clamp(8, 42).toDouble()
                    : 6.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: score >= 0
                            ? color.withAlpha(190)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  formatDateShort(recent.first['date'] as DateTime),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  formatDateShort(recent.last['date'] as DateTime),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildContextBreakdown() {
    final last30 = takeLastRecords(30);
    final counts = <String, int>{};

    for (final record in last30) {
      final tags = (record['contextTags'] as List<String>?) ?? <String>[];
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxValue = top.isEmpty
        ? 1
        : top.map((entry) => entry.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Context Tags (last 30 days)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (top.isEmpty)
            Text(
              'No context data yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ...top.map((entry) {
            final ratio = entry.value / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade400,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: contentWidth,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No tracker data yet. Add a few daily entries and Insights will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    final last7 = takeLastRecords(7);
    final avgFocus = averageForField(last7, 'focus');
    final avgRestless = averageForField(last7, 'restlessness');
    final avgWork = averageForField(last7, 'workTaskScore');
    final avgHome = averageForField(last7, 'homeTaskScore');
    final crashDays = records
        .where((record) => (record['hasCrash'] as bool?) ?? false)
        .length;
    final avgCrashSymptoms =
        records
            .map((record) => (record['crashSymptomCount'] as int?) ?? 0)
            .where((count) => count > 0)
            .fold<int>(0, (sum, item) => sum + item) /
        (records
                .map((record) => (record['crashSymptomCount'] as int?) ?? 0)
                .where((count) => count > 0)
                .isEmpty
            ? 1
            : records
                  .map((record) => (record['crashSymptomCount'] as int?) ?? 0)
                  .where((count) => count > 0)
                  .length);

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Insights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${records.length} days tracked',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  final isNarrow = cardConstraints.maxWidth < 680;
                  final cards = [
                    buildStatCard(
                      title: 'Focus avg (7d)',
                      value: avgFocus == 0 ? '-' : avgFocus.toStringAsFixed(1),
                      subtitle: 'Score out of 10',
                    ),
                    buildStatCard(
                      title: 'Restlessness avg (7d)',
                      value: avgRestless == 0
                          ? '-'
                          : avgRestless.toStringAsFixed(1),
                      subtitle: 'Score out of 10',
                    ),
                    buildStatCard(
                      title: 'Task quality avg (7d)',
                      value: (avgWork == 0 && avgHome == 0)
                          ? '-'
                          : ((avgWork + avgHome) / 2).toStringAsFixed(1),
                      subtitle: 'Work + Home combined',
                    ),
                    buildStatCard(
                      title: 'Crash days',
                      value: crashDays.toString(),
                      subtitle: avgCrashSymptoms > 0
                          ? 'Avg ${avgCrashSymptoms.toStringAsFixed(1)} symptoms'
                          : 'No crash symptom logs yet',
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      children: cards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Row(
                    children: List.generate(cards.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == cards.length - 1 ? 0 : 8,
                          ),
                          child: cards[index],
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 10),
              buildTrendRow(
                title: 'Focus drift',
                field: 'focus',
                color: const Color(0xFF2F6FE4),
              ),
              const SizedBox(height: 8),
              buildTrendRow(
                title: 'Restlessness',
                field: 'restlessness',
                color: const Color(0xFF6B5BDB),
              ),
              const SizedBox(height: 8),
              buildTrendRow(
                title: 'Overwhelm',
                field: 'overwhelm',
                color: const Color(0xFFC14E7B),
              ),
              const SizedBox(height: 8),
              buildTrendRow(
                title: 'Emotional regulation',
                field: 'emotionalRegulation',
                color: const Color(0xFF2E9B8C),
              ),
              const SizedBox(height: 10),
              buildContextBreakdown(),
            ],
          ),
        ),
      ),
    );
  }
}
