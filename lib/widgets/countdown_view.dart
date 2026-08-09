import 'package:flutter/material.dart';

class CountdownView extends StatelessWidget {
  const CountdownView({
    super.key,
    required this.contentWidth,
    required this.availableHeight,
    required this.timerRunning,
    required this.completedPercent,
    required this.accentColor,
    required this.phaseLabel,
    required this.digitalFontSize,
    required this.timerCompletionCueActive,
    required this.remainingFocusTime,
    required this.selectedFocusTimerSeconds,
    required this.selectedFocusTimerMinutes,
    required this.focusTimerPresets,
    required this.formatFocusTime,
    required this.setFocusTimerPreset,
    required this.setCustomFocusTimer,
    required this.startFocusTimer,
    required this.stopFocusTimer,
    required this.resetFocusTimer,
  });

  final double contentWidth;
  final double availableHeight;
  final bool timerRunning;
  final int completedPercent;
  final Color accentColor;
  final String phaseLabel;
  final double digitalFontSize;
  final bool timerCompletionCueActive;
  final Duration remainingFocusTime;
  final int selectedFocusTimerSeconds;
  final int selectedFocusTimerMinutes;
  final List<int> focusTimerPresets;
  final String Function(Duration duration) formatFocusTime;
  final ValueChanged<int> setFocusTimerPreset;
  final VoidCallback setCustomFocusTimer;
  final VoidCallback startFocusTimer;
  final VoidCallback stopFocusTimer;
  final VoidCallback resetFocusTimer;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: contentWidth,
        height: availableHeight,
        child: SingleChildScrollView(
          child: Container(
            width: contentWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: timerRunning
                    ? const [Color(0xFFE8FBF5), Color(0xFFF3FAFF)]
                    : const [Color(0xFFEEF3FF), Color(0xFFF8FAFF)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: timerRunning
                    ? const Color(0xFFA9E3CF)
                    : const Color(0xFFC3D3F4),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withAlpha(28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      timerRunning
                          ? Icons.auto_awesome
                          : Icons.hourglass_bottom_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Focus Sprint',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accentColor.withAlpha(90)),
                      ),
                      child: Text(
                        '$completedPercent% done',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: timerCompletionCueActive
                        ? const Color(0xFFFFF0EC)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: timerCompletionCueActive
                          ? const Color(0xFFE68668)
                          : accentColor.withAlpha(90),
                      width: timerCompletionCueActive ? 2.2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (timerCompletionCueActive
                                    ? const Color(0xFFE68668)
                                    : accentColor)
                                .withAlpha(timerCompletionCueActive ? 95 : 32),
                        blurRadius: timerCompletionCueActive ? 24 : 12,
                        spreadRadius: timerCompletionCueActive ? 2 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatFocusTime(remainingFocusTime),
                        style: TextStyle(
                          fontSize: digitalFontSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D2A4A),
                          letterSpacing: 2.2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timerCompletionCueActive
                            ? 'Time is up. Nice work.'
                            : (timerRunning ? 'In flow' : 'Paused'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: timerCompletionCueActive
                              ? const Color(0xFFB2553B)
                              : accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phaseLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value:
                              selectedFocusTimerSeconds == 0 &&
                                  focusTimerPresets.contains(
                                    selectedFocusTimerMinutes,
                                  )
                              ? selectedFocusTimerMinutes
                              : null,
                          hint: const Text('Preset'),
                          isDense: true,
                          items: focusTimerPresets.map((minutes) {
                            return DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('${minutes}m'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setFocusTimerPreset(value);
                          },
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: setCustomFocusTimer,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor.withAlpha(120)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Set'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: timerRunning ? null : startFocusTimer,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: timerRunning ? stopFocusTimer : null,
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Pause'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor.withAlpha(140)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: resetFocusTimer,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
