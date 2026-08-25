class PlannerBreakPolicy {
  static const int maxFocusSessionMinutes = 60;
  static const int recoveryBreakMinutes = 15;
  static const int minAvailableTimeMinutes = 30;
  static const int maxAvailableTimeMinutes = 60;

  static int recoveryBreakMinutesForFocus(int cumulativeFocusMinutes) {
    return cumulativeFocusMinutes >= maxFocusSessionMinutes
        ? recoveryBreakMinutes
        : 0;
  }
}
