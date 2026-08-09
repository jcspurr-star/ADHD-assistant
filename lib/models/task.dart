class Subtask {
  String text;
  bool done;
  bool aiSuggested;

  Subtask({required this.text, this.done = false, this.aiSuggested = false});

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      text: json["text"],
      done: json["done"] ?? false,
      aiSuggested: json["aiSuggested"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {"text": text, "done": done, "aiSuggested": aiSuggested};
  }
}

class Task {
  String task;
  bool done;
  bool expanded;
  List<Subtask> aiSubtasks;
  List<Subtask> subtasks;
  String priority;
  String? dueDate;
  String category;
  String starterTinyStep;
  String starterSetupChecklist;
  String starterIfStuck;
  String? snoozedUntilUtc;

  Task({
    required this.task,
    this.done = false,
    this.expanded = false,
    List<Subtask>? aiSubtasks,
    List<Subtask>? subtasks,
    this.priority = "medium",
    this.dueDate,
    this.category = 'None',
    this.starterTinyStep = '',
    this.starterSetupChecklist = '',
    this.starterIfStuck = '',
    this.snoozedUntilUtc,
  }) : aiSubtasks = aiSubtasks ?? [],
       subtasks = subtasks ?? [];

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
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
      category: json["category"] ?? 'None',
      starterTinyStep: json["starterTinyStep"] ?? '',
      starterSetupChecklist: json["starterSetupChecklist"] ?? '',
      starterIfStuck: json["starterIfStuck"] ?? '',
      snoozedUntilUtc: json["snoozedUntilUtc"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "task": task,
      "done": done,
      "expanded": expanded,
      "aiSubtasks": aiSubtasks.map((s) => s.toJson()).toList(),
      "subtasks": subtasks.map((s) => s.toJson()).toList(),
      "priority": priority,
      "dueDate": dueDate,
      "category": category,
      "starterTinyStep": starterTinyStep,
      "starterSetupChecklist": starterSetupChecklist,
      "starterIfStuck": starterIfStuck,
      "snoozedUntilUtc": snoozedUntilUtc,
    };
  }
}
