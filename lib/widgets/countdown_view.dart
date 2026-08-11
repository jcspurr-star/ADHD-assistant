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
    this.compactMode = false,
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
  final bool compactMode;

  @override
  Widget build(BuildContext context) {
    final focusMode = !compactMode;
    final clockFontSize = compactMode
        ? digitalFontSize.clamp(34.0, 52.0)
        : digitalFontSize.clamp(72.0, 140.0);
    final outerPadding = compactMode
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.fromLTRB(24, 22, 24, 22);
    final clockPadding = compactMode
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 28);

    final chunkyButtonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(170, 62),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    final chunkyOutlineStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(170, 62),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    final chunkyTextStyle = TextButton.styleFrom(
      minimumSize: const Size(170, 62),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    Widget buildControls() {
      if (focusMode) {
        return Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                      items: focusTimerPresets.map((minutes) {
                        return DropdownMenuItem<int>(
                          value: minutes,
                          child: Text(
                            '${minutes}m',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                  style: chunkyOutlineStyle,
                  child: const Text('Custom'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: timerRunning ? stopFocusTimer : startFocusTimer,
                  icon: Icon(
                    timerRunning ? Icons.pause : Icons.play_arrow,
                    size: 28,
                  ),
                  label: Text(timerRunning ? 'Pause' : 'Start'),
                  style: chunkyButtonStyle.copyWith(
                    backgroundColor: WidgetStatePropertyAll(accentColor),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                ),
                TextButton.icon(
                  onPressed: resetFocusTimer,
                  icon: const Icon(Icons.restart_alt, size: 28),
                  label: const Text('Reset'),
                  style: chunkyTextStyle,
                ),
              ],
            ),
          ],
        );
      }

      return Wrap(
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
                        focusTimerPresets.contains(selectedFocusTimerMinutes)
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
              padding: EdgeInsets.symmetric(
                horizontal: compactMode ? 10 : 14,
                vertical: compactMode ? 8 : 10,
              ),
            ),
            child: const Text('Custom'),
          ),
          ElevatedButton.icon(
            onPressed: timerRunning ? stopFocusTimer : startFocusTimer,
            icon: Icon(timerRunning ? Icons.pause : Icons.play_arrow, size: 18),
            label: Text(timerRunning ? 'Pause' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              visualDensity: compactMode
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              padding: EdgeInsets.symmetric(
                horizontal: compactMode ? 10 : 14,
                vertical: compactMode ? 8 : 10,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: resetFocusTimer,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              visualDensity: compactMode
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              padding: EdgeInsets.symmetric(
                horizontal: compactMode ? 10 : 14,
                vertical: compactMode ? 8 : 10,
              ),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: contentWidth,
        height: availableHeight,
        child: Container(
          width: contentWidth,
          padding: outerPadding,
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
                    size: focusMode ? 24 : 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Focus Sprint',
                    style: TextStyle(
                      fontSize: focusMode ? 22 : 15,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: focusMode ? 10 : 8,
                      vertical: focusMode ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accentColor.withAlpha(90)),
                    ),
                    child: Text(
                      '$completedPercent% done',
                      style: TextStyle(
                        fontSize: focusMode ? 14 : 11,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: focusMode ? 16 : 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  padding: clockPadding,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatFocusTime(remainingFocusTime),
                          style: TextStyle(
                            fontSize: clockFontSize,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D2A4A),
                            letterSpacing: focusMode ? 3.2 : 2.2,
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(height: compactMode ? 4 : 10),
                      Text(
                        timerCompletionCueActive
                            ? 'Time is up. Nice work.'
                            : (timerRunning ? 'In flow' : 'Paused'),
                        style: TextStyle(
                          fontSize: focusMode ? 20 : (compactMode ? 13 : 14),
                          fontWeight: FontWeight.w800,
                          color: timerCompletionCueActive
                              ? const Color(0xFFB2553B)
                              : accentColor,
                        ),
                      ),
                      SizedBox(height: compactMode ? 2 : 4),
                      Text(
                        phaseLabel,
                        style: TextStyle(
                          fontSize: focusMode ? 16 : (compactMode ? 11 : 12),
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compactMode ? 10 : 18),
              if (focusMode)
                buildControls()
              else
                SingleChildScrollView(child: buildControls()),
            ],
          ),
        ),
      ),
    );
  }
}
