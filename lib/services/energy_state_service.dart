import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/menu_planning.dart';

/// Persists the user's self-reported energy state for Menu-Based Planning's
/// daily check-in ("How are you feeling right now?").
class EnergyStateService {
  static const _energyStateKey = 'menu_planning_energy_state';
  static const _lastCheckInDateKey = 'menu_planning_last_checkin_date';

  static String _todayKey([DateTime? now]) {
    final today = now ?? DateTime.now();
    return '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
  }

  /// The currently persisted energy state, if any has been set.
  static Future<EnergyState?> loadEnergyState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_energyStateKey);
    if (raw == null) return null;
    for (final value in EnergyState.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  /// True when the user hasn't checked in yet today.
  static Future<bool> needsCheckInToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_lastCheckInDateKey);
    return lastDate != _todayKey();
  }

  static Future<void> saveEnergyState(EnergyState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_energyStateKey, state.name);
    await prefs.setString(_lastCheckInDateKey, _todayKey());
  }
}
