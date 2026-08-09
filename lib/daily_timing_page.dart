import 'package:flutter/material.dart';

class DailyTimingPage extends StatefulWidget {
  final List<String> initialSlots;
  final List<String> initialReminderTimes;
  final String initialDopamineCrashTime;
  final String initialMedicationTime;

  const DailyTimingPage({
    super.key,
    required this.initialSlots,
    required this.initialReminderTimes,
    required this.initialDopamineCrashTime,
    required this.initialMedicationTime,
  });

  @override
  State<DailyTimingPage> createState() => _DailyTimingPageState();
}

class _DailyTimingPageState extends State<DailyTimingPage> {
  static const List<String> checkInPresetSlots = [
    'Morning',
    'Midday',
    'Afternoon',
    'Evening',
  ];

  late List<String> selectedSlots;
  late List<String> reminderTimes;
  late String dopamineCrashTime;
  late String medicationTime;

  @override
  void initState() {
    super.initState();
    selectedSlots = List<String>.from(widget.initialSlots);
    reminderTimes = List<String>.from(widget.initialReminderTimes)..sort();
    dopamineCrashTime = widget.initialDopamineCrashTime;
    medicationTime = widget.initialMedicationTime;
  }

  TimeOfDay? parseStoredTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String formatPickedTime(TimeOfDay value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Future<void> setTimeField({required bool isCrash}) async {
    final currentValue = isCrash ? dopamineCrashTime : medicationTime;
    final initial = parseStoredTime(currentValue) ?? TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isCrash
          ? 'When did you feel the crash?'
          : 'When did you take medication?',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isCrash) {
        dopamineCrashTime = formatPickedTime(picked);
      } else {
        medicationTime = formatPickedTime(picked);
      }
    });
  }

  Future<void> addReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Add check-in reminder time',
    );

    if (picked == null) {
      return;
    }

    final formatted = formatPickedTime(picked);
    setState(() {
      if (!reminderTimes.contains(formatted)) {
        reminderTimes.add(formatted);
        reminderTimes.sort();
      }
    });
  }

  void saveAndClose() {
    Navigator.pop(context, {
      'checkInSlots': selectedSlots,
      'checkInReminderTimes': reminderTimes,
      'dopamineCrashTime': dopamineCrashTime,
      'medicationTime': medicationTime,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily timing'),
        actions: [
          TextButton(
            onPressed: saveAndClose,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Times of day I want to check in',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: checkInPresetSlots.map((slot) {
                    return FilterChip(
                      label: Text(slot),
                      selected: selectedSlots.contains(slot),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedSlots.add(slot);
                          } else {
                            selectedSlots.remove(slot);
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Exact reminder times',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: addReminderTime,
                      icon: const Icon(Icons.add_alarm, size: 16),
                      label: const Text('Add time'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                if (reminderTimes.isNotEmpty) const SizedBox(height: 8),
                if (reminderTimes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: reminderTimes.map((time) {
                      return InputChip(
                        label: Text(time),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () {
                          setState(() {
                            reminderTimes.remove(time);
                          });
                        },
                      );
                    }).toList(),
                  ),
                if (reminderTimes.isEmpty)
                  Text(
                    'No reminder times set yet.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dopamine crash: ${dopamineCrashTime.isEmpty ? 'Not set' : dopamineCrashTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await setTimeField(isCrash: true);
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Set'),
                    ),
                    if (dopamineCrashTime.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            dopamineCrashTime = '';
                          });
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Medication taken: ${medicationTime.isEmpty ? 'Not set' : medicationTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await setTimeField(isCrash: false);
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Set'),
                    ),
                    if (medicationTime.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            medicationTime = '';
                          });
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: saveAndClose,
            icon: const Icon(Icons.check),
            label: const Text('Save timing changes'),
          ),
        ],
      ),
    );
  }
}
