class Subtask {
  String text;
  bool done;
  bool aiSuggested;
  String? doDate;

  Subtask({
    required this.text,
    this.done = false,
    this.aiSuggested = false,
    this.doDate,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      text: json["text"],
      done: json["done"] ?? false,
      aiSuggested: json["aiSuggested"] ?? false,
      doDate: json["doDate"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "text": text,
      "done": done,
      "aiSuggested": aiSuggested,
      "doDate": doDate,
    };
  }
}

class Task {
  String id;
  String task;
  bool done;
  bool expanded;
  List<Subtask> aiSubtasks;
  List<Subtask> subtasks;
  String priority;
  String? dueDate;
  String? doDate;
  int? effortMinutes;
  int? nextSessionEffortMinutes;
  String nextAction;
  String category;
  String starterTinyStep;
  String starterSetupChecklist;
  String starterIfStuck;
  String? snoozedUntilUtc;
  String description;
  String notes;
  List<String> tags;
  String? completedAtUtc;
  bool absolutePriority;
  // When true, once the due date passes without completion the task stops
  // appearing in the planner at all (instead of the usual backlog carry-over).
  bool excludeWhenOverdue;
  // When true, the task is blocked on someone/something else and is excluded
  // from planning entirely until the flag is cleared.
  bool waitingOnOthers;

  Task({
    String? id,
    required this.task,
    this.done = false,
    this.expanded = false,
    List<Subtask>? aiSubtasks,
    List<Subtask>? subtasks,
    this.priority = "medium",
    this.dueDate,
    this.doDate,
    this.effortMinutes,
    this.nextSessionEffortMinutes,
    this.nextAction = '',
    this.category = 'None',
    this.starterTinyStep = '',
    this.starterSetupChecklist = '',
    this.starterIfStuck = '',
    this.snoozedUntilUtc,
    this.description = '',
    this.notes = '',
    List<String>? tags,
    this.completedAtUtc,
    this.absolutePriority = false,
    this.excludeWhenOverdue = false,
    this.waitingOnOthers = false,
  }) : id = id ?? 'task-${DateTime.now().microsecondsSinceEpoch}',
       aiSubtasks = aiSubtasks ?? [],
       subtasks = subtasks ?? [],
       tags = tags ?? [];

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json["id"] ?? 'legacy-task-${json["task"] ?? "untitled"}',
      task: json["task"],
      done: json["done"] ?? false,
      expanded: json["expanded"] ?? false,
      subtasks:
          (json["subtasks"] as List<dynamic>?)
              ?.map((s) => Subtask.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          [],
      aiSubtasks:
          (json["aiSubtasks"] as List<dynamic>?)
              ?.map((s) => Subtask.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          [],
      priority: json["priority"] ?? "medium",
      dueDate: json["dueDate"],
      doDate: json["doDate"],
      effortMinutes: json["effortMinutes"],
      nextSessionEffortMinutes: json["nextSessionEffortMinutes"],
      nextAction: json["nextAction"] ?? '',
      category: json["category"] ?? 'None',
      starterTinyStep: json["starterTinyStep"] ?? '',
      starterSetupChecklist: json["starterSetupChecklist"] ?? '',
      starterIfStuck: json["starterIfStuck"] ?? '',
      snoozedUntilUtc: json["snoozedUntilUtc"],
      description: json["description"] ?? '',
      notes: json["notes"] ?? '',
      tags:
          (json["tags"] as List<dynamic>?)
              ?.map((tag) => tag.toString())
              .toList() ??
          [],
      completedAtUtc: json["completedAtUtc"],
          absolutePriority: json["absolutePriority"] ?? false,
      excludeWhenOverdue: json["excludeWhenOverdue"] ?? false,
      waitingOnOthers: json["waitingOnOthers"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "task": task,
      "done": done,
      "expanded": expanded,
      "aiSubtasks": aiSubtasks.map((s) => s.toJson()).toList(),
      "subtasks": subtasks.map((s) => s.toJson()).toList(),
      "priority": priority,
      "dueDate": dueDate,
      "doDate": doDate,
      "effortMinutes": effortMinutes,
      "nextSessionEffortMinutes": nextSessionEffortMinutes,
      "nextAction": nextAction,
      "category": category,
      "starterTinyStep": starterTinyStep,
      "starterSetupChecklist": starterSetupChecklist,
      "starterIfStuck": starterIfStuck,
      "snoozedUntilUtc": snoozedUntilUtc,
      "description": description,
      "notes": notes,
      "tags": tags,
      "completedAtUtc": completedAtUtc,
      "absolutePriority": absolutePriority,
      "excludeWhenOverdue": excludeWhenOverdue,
      "waitingOnOthers": waitingOnOthers,
    };
  }
}
