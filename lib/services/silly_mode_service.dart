import '../models/task.dart';

// Playful, opt-in reframing helpers for "Silly mode" — silly alt-titles,
// joke priority labels, rotating flavor lines and completion celebrations.
// Deliberately absurd-object humour (jokes about the TASK, never the user)
// and kept clean/safe rather than crude.
class SillyModeService {
  SillyModeService._();

  // Mirrors the persisted setting in main.dart's state; widgets read this
  // directly at build time so no extra plumbing is needed to react to it.
  static bool enabled = false;

  static const List<String> _titleTemplates = [
    'Operation: {task}',
    'The Legendary Quest of {task}',
    '{task} (now with 100% more drama)',
    'Boss Battle: {task}',
    'Mission Improbable: {task}',
    '{task}: Special Edition',
    'The Great {task} Caper',
    'Codename: {task}',
    '{task}, but make it an adventure',
    'Defender-of-the-To-Do-List vs. {task}',
  ];

  static const Map<String, String> _priorityLabels = {
    'high': 'DEFCON: Handle Now',
    'medium': 'Mild Chaos',
    'low': 'Someday, Probably',
  };

  static const List<String> _flavorLines = [
    'This task has been legally required to be mildly annoying.',
    'Scientists agree: doing this will not summon a raccoon.',
    'No dragons were harmed in the making of this task.',
    'Warning: completing this may cause a small sense of pride.',
    'This task is 12% more fun if you hum while doing it.',
    'Rumour has it, finishing this unlocks a mysterious sense of relief.',
    'Somewhere, a tiny gremlin is rooting for you to finish this.',
    'This task does not bite. Probably.',
    'Plot twist: this might take less time than dreading it did.',
    'Approved by the Council of Vaguely Important Chores.',
  ];

  static const List<String> _bossBattleLines = [
    'This task has evaded you before. It grows bolder.',
    'The task is taunting you from the backlog. Rude.',
    'Round two: this task thinks it can outlast you. It cannot.',
    'This task has been building its confidence. Humble it.',
  ];

  static const List<String> _celebrationLines = [
    'Incredible. Bureaucracy fears you now.',
    'Task obliterated. Take a bow.',
    'You have defeated the to-do. XP +100.',
    'Legendary. Somewhere a gremlin is applauding.',
    'That task never stood a chance.',
    'Achievement unlocked: "Did The Thing".',
    'You plus task equals task loses. Every time.',
    'Certified Task Slayer.',
  ];

  static int _stableIndex(String seed, int length) {
    if (length <= 0) return 0;
    return seed.hashCode.abs() % length;
  }

  static bool appliesTo(Task task) => enabled && !task.sillyModeExempt;

  static String altTitle(Task task) {
    final template =
        _titleTemplates[_stableIndex(task.id, _titleTemplates.length)];
    return template.replaceAll('{task}', task.task);
  }

  static String priorityLabel(String priority, String fallback) {
    return _priorityLabels[priority] ?? fallback;
  }

  static String flavorLine(Task task) {
    final today = DateTime.now();
    final daySeed =
        '${task.id}-${today.year}-${today.month}-${today.day}';
    return _flavorLines[_stableIndex(daySeed, _flavorLines.length)];
  }

  static String bossBattleLine(Task task) {
    return _bossBattleLines[_stableIndex(task.id, _bossBattleLines.length)];
  }

  static String randomCelebrationLine() {
    final index =
        DateTime.now().microsecondsSinceEpoch % _celebrationLines.length;
    return _celebrationLines[index];
  }
}
