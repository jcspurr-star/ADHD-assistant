class Task {
  String task;
  bool done;
  bool expanded;
  List<Map<String, dynamic>> subtasks;

  Task({
    required this.task,
    this.done = false,
    this.expanded = false,
    this.subtasks = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      task: json["task"],
      done: json["done"] ?? false,
      expanded: json["expanded"] ?? false,
      subtasks: List<Map<String, dynamic>>.from(json["subtasks"] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "task": task,
      "done": done,
      "expanded": expanded,
      "subtasks": subtasks,
    };
  }
}
