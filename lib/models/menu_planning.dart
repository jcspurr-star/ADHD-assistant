/// Menu-Based Planning: task categories modeled like a restaurant menu so
/// users pick tasks that match their current capacity instead of a schedule.
enum MenuCategory { appetizer, snack, mainCourse, sideDish, dessert }

enum EnergyRequirement { veryLow, low, medium, high }

enum FocusRequirement { low, medium, deep }

/// The user's self-reported capacity, captured via the daily check-in.
enum EnergyState {
  burntOut,
  lowEnergy,
  moderateEnergy,
  highEnergy,
  hyperfocused,
}

extension MenuCategoryDisplay on MenuCategory {
  String get label => switch (this) {
    MenuCategory.appetizer => 'Appetizers',
    MenuCategory.snack => 'Snacks',
    MenuCategory.mainCourse => 'Main Courses',
    MenuCategory.sideDish => 'Side Dishes',
    MenuCategory.dessert => 'Desserts',
  };

  String get emoji => switch (this) {
    MenuCategory.appetizer => '🍤',
    MenuCategory.snack => '🧃',
    MenuCategory.mainCourse => '🍔',
    MenuCategory.sideDish => '🥗',
    MenuCategory.dessert => '🍰',
  };

  String get purpose => switch (this) {
    MenuCategory.appetizer =>
      'Small, low-friction tasks that break task paralysis and build momentum.',
    MenuCategory.snack =>
      'Medium-effort transitional tasks that build momentum toward deeper work.',
    MenuCategory.mainCourse =>
      'Deep work for meaningful progress and high-value tasks.',
    MenuCategory.sideDish => 'Administrative and life-maintenance tasks.',
    MenuCategory.dessert =>
      'Recovery and restorative activities — valid on their own, not a reward to be earned.',
  };
}

extension EnergyRequirementDisplay on EnergyRequirement {
  String get label => switch (this) {
    EnergyRequirement.veryLow => 'Very low energy',
    EnergyRequirement.low => 'Low energy',
    EnergyRequirement.medium => 'Medium energy',
    EnergyRequirement.high => 'High energy',
  };

  int get level => switch (this) {
    EnergyRequirement.veryLow => 0,
    EnergyRequirement.low => 1,
    EnergyRequirement.medium => 2,
    EnergyRequirement.high => 3,
  };

  String get description => switch (this) {
    EnergyRequirement.veryLow =>
      'Barely any effort — doable even when running on empty.',
    EnergyRequirement.low =>
      'Light effort — fine on a tired or low-motivation day.',
    EnergyRequirement.medium =>
      'Moderate effort — needs a reasonable amount of energy to start.',
    EnergyRequirement.high =>
      'Demanding — best tackled when you feel energized.',
  };
}

extension FocusRequirementDisplay on FocusRequirement {
  String get label => switch (this) {
    FocusRequirement.low => 'Low focus',
    FocusRequirement.medium => 'Medium focus',
    FocusRequirement.deep => 'Deep focus',
  };

  String get description => switch (this) {
    FocusRequirement.low =>
      'Can be done with distractions or half your attention.',
    FocusRequirement.medium =>
      'Needs steady attention but can tolerate a few interruptions.',
    FocusRequirement.deep => 'Requires uninterrupted, sustained concentration.',
  };
}

extension EnergyStateDisplay on EnergyState {
  String get label => switch (this) {
    EnergyState.burntOut => 'Burnt Out',
    EnergyState.lowEnergy => 'Low Energy',
    EnergyState.moderateEnergy => 'Moderate Energy',
    EnergyState.highEnergy => 'High Energy',
    EnergyState.hyperfocused => 'Hyperfocused',
  };

  String get emoji => switch (this) {
    EnergyState.burntOut => '🌧',
    EnergyState.lowEnergy => '😴',
    EnergyState.moderateEnergy => '🙂',
    EnergyState.highEnergy => '⚡',
    EnergyState.hyperfocused => '🔥',
  };

  /// Matches the EnergyRequirement levels this state is comfortable with,
  /// ordered from best match (first) to worst.
  List<EnergyRequirement> get preferredEnergyOrder => switch (this) {
    EnergyState.burntOut => const [
      EnergyRequirement.veryLow,
      EnergyRequirement.low,
    ],
    EnergyState.lowEnergy => const [
      EnergyRequirement.low,
      EnergyRequirement.veryLow,
      EnergyRequirement.medium,
    ],
    EnergyState.moderateEnergy => const [
      EnergyRequirement.medium,
      EnergyRequirement.low,
      EnergyRequirement.high,
    ],
    EnergyState.highEnergy => const [
      EnergyRequirement.high,
      EnergyRequirement.medium,
    ],
    EnergyState.hyperfocused => const [
      EnergyRequirement.high,
      EnergyRequirement.medium,
    ],
  };
}
