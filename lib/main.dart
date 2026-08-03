import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart';
import 'services/storage_service.dart';
import 'dialogs/step_count_dialog.dart';
import 'dialogs/add_subtask_dialog.dart';
import 'dialogs/edit_task_dialog.dart';
import 'dialogs/edit_subtask_dialog.dart';
import 'dialogs/regenerate_subtasks_dialog.dart';
import 'widgets/subtask_tile.dart';
import 'widgets/task_tile.dart';

void main() {
  runApp(const ADHDApp());
}

class GeminiService {
  static Future<List<Map<String, dynamic>>> generateSubtasks(
    String task,
    int stepCount,
  ) async {
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$geminiApiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    """
You are an ADHD task initiation coach.

TASK:
$task

Generate $stepCount ADHD-friendly steps.

Return ONLY a JSON array of strings.
""",
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      return [
        {"text": "AI unavailable right now", "done": false},
      ];
    }

    final data = jsonDecode(response.body);

    final text = data["candidates"][0]["content"]["parts"][0]["text"];

    final List<dynamic> steps = jsonDecode(text);

    return steps.map((step) {
      return {"text": step.toString(), "done": false};
    }).toList();
  }
}

class ADHDApp extends StatelessWidget {
  const ADHDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'James ADHD Assistant',
      debugShowCheckedModeBanner: false,
      home: const ADHDHomePage(),
    );
  }
}

class ADHDHomePage extends StatefulWidget {
  const ADHDHomePage({super.key});

  @override
  State<ADHDHomePage> createState() => _ADHDHomePageState();
}

class _ADHDHomePageState extends State<ADHDHomePage> {
  final TextEditingController taskController = TextEditingController();

  List<Map<String, dynamic>> tasks = [];

  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final loadedTasks = await StorageService.loadTasks();

    for (final task in loadedTasks) {
      task["priority"] ??= "medium";
    }

    setState(() {
      tasks = loadedTasks;
    });
  }

  Future<void> saveTasks() async {
    await StorageService.saveTasks(tasks);
  }

  Future<void> addTask() async {
    if (taskController.text.trim().isNotEmpty) {
      setState(() {
        tasks.add({
          "task": taskController.text.trim(),
          "done": false,
          "expanded": false,
          "priority": "medium",
        });
      });

      taskController.clear();

      await saveTasks();
    }
  }

  Future<void> addSubtask(int taskIndex) async {
    final text = await showAddSubtaskDialog(context);

    if (text == null || text.isEmpty) {
      return;
    }

    setState(() {
      tasks[taskIndex]["subtasks"] ??= [];

      tasks[taskIndex]["subtasks"].add({"text": text, "done": false});

      tasks[taskIndex]["expanded"] = true;
    });

    await saveTasks();
  }

  Future<void> createSubtasks(int index, int stepCount) async {
    if (tasks[index].containsKey("subtasks")) {
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      List<Map<String, dynamic>> subtasks =
          await GeminiService.generateSubtasks(tasks[index]["task"], stepCount);
      setState(() {
        tasks[index]["subtasks"] = subtasks;
        tasks[index]["expanded"] = true;
      });

      await saveTasks();
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Future<void> handleGenerateSubtasks(int index) async {
    final stepCount = await showStepCountDialog(context);

    if (!mounted || stepCount == null || stepCount <= 0) {
      return;
    }

    await createSubtasks(index, stepCount);
  }

  Future<void> regenerateSubtasks(int index, int stepCount) async {
    setState(() {
      isGenerating = true;
    });

    try {
      final subtasks = await GeminiService.generateSubtasks(
        tasks[index]["task"],
        stepCount,
      );

      setState(() {
        tasks[index]["subtasks"] = subtasks;
        tasks[index]["expanded"] = true;
      });

      await saveTasks();
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Future<void> handleRegenerateSubtasks(int index) async {
    final confirmed = await showRegenerateSubtasksDialog(context);

    if (!mounted || !confirmed) {
      return;
    }

    final stepCount = await showStepCountDialog(context);

    if (!mounted || stepCount == null || stepCount <= 0) {
      return;
    }

    await regenerateSubtasks(index, stepCount);
  }

  Future<void> editTask(int index) async {
    final updatedText = await showEditTaskDialog(context, tasks[index]["task"]);

    if (updatedText == null || updatedText.isEmpty) {
      return;
    }

    setState(() {
      tasks[index]["task"] = updatedText;
    });

    await saveTasks();
  }

  Future<void> editSubtask(int taskIndex, int subtaskIndex) async {
    final updatedText = await showEditSubtaskDialog(
      context,
      tasks[taskIndex]["subtasks"][subtaskIndex]["text"],
    );

    if (updatedText == null || updatedText.isEmpty) {
      return;
    }

    setState(() {
      tasks[taskIndex]["subtasks"][subtaskIndex]["text"] = updatedText;
    });

    await saveTasks();
  }

  Future<void> moveSubtaskUp(int taskIndex, int subtaskIndex) async {
    if (subtaskIndex == 0) return;

    setState(() {
      final item = tasks[taskIndex]["subtasks"].removeAt(subtaskIndex);

      tasks[taskIndex]["subtasks"].insert(subtaskIndex - 1, item);
    });

    await saveTasks();
  }

  Future<void> moveSubtaskDown(int taskIndex, int subtaskIndex) async {
    if (subtaskIndex == tasks[taskIndex]["subtasks"].length - 1) {
      return;
    }

    setState(() {
      final item = tasks[taskIndex]["subtasks"].removeAt(subtaskIndex);

      tasks[taskIndex]["subtasks"].insert(subtaskIndex + 1, item);
    });

    await saveTasks();
  }

  Future<void> toggleTask(int index, bool? value) async {
    setState(() {
      tasks[index]["done"] = value ?? false;
    });

    await saveTasks();
  }

  Future<void> toggleSubtask(
    int taskIndex,
    int subtaskIndex,
    bool? value,
  ) async {
    setState(() {
      tasks[taskIndex]["subtasks"][subtaskIndex]["done"] = value ?? false;

      bool allDone = tasks[taskIndex]["subtasks"].every(
        (subtask) => subtask["done"] == true,
      );

      tasks[taskIndex]["done"] = allDone;
    });

    await saveTasks();
  }

  Future<void> toggleExpanded(int index) async {
    setState(() {
      tasks[index]["expanded"] = !(tasks[index]["expanded"] ?? false);
    });

    await saveTasks();
  }

  Future<void> deleteTask(int index) async {
    setState(() {
      tasks.removeAt(index);
    });

    await saveTasks();
  }

  Future<void> deleteSubtask(int taskIndex, int subtaskIndex) async {
    setState(() {
      tasks[taskIndex]["subtasks"].removeAt(subtaskIndex);

      if (tasks[taskIndex]["subtasks"].isEmpty) {
        tasks[taskIndex].remove("subtasks");
        tasks[taskIndex]["done"] = false;
      }
    });

    await saveTasks();
  }

  void showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text("Delete '${tasks[index]["task"]}'?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteTask(index);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void showDeleteSubtaskConfirmation(int taskIndex, int subtaskIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Subtask"),
        content: Text(
          "Delete '${tasks[taskIndex]["subtasks"][subtaskIndex]["text"]}'?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await deleteSubtask(taskIndex, subtaskIndex);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  double getTaskProgress(Map<String, dynamic> task) {
    if (!task.containsKey("subtasks")) {
      return task["done"] == true ? 1.0 : 0.0;
    }

    final subtasks = task["subtasks"] as List<dynamic>;

    if (subtasks.isEmpty) {
      return 0.0;
    }

    final completed = subtasks
        .where((subtask) => subtask["done"] == true)
        .length;

    return completed / subtasks.length;
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "high":
        return Colors.red;

      case "medium":
        return Colors.orange;

      case "low":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  String getPriorityLabel(String priority) {
    switch (priority) {
      case "high":
        return "High";

      case "medium":
        return "Medium";

      case "low":
        return "Low";

      default:
        return "Medium";
    }
  }

  Future<void> changePriority(int index) async {
    String selected = tasks[index]["priority"];
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Task Priority"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.red),
                  title: const Text("High"),
                  trailing: selected == "high" ? const Icon(Icons.check) : null,
                  onTap: () {
                    setStateDialog(() {
                      selected = "high";
                    });
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.orange),
                  title: const Text("Medium"),
                  trailing: selected == "medium"
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setStateDialog(() {
                      selected = "medium";
                    });
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.green),
                  title: const Text("Low"),
                  trailing: selected == "low" ? const Icon(Icons.check) : null,
                  onTap: () {
                    setStateDialog(() {
                      selected = "low";
                    });
                  },
                ),
              ],
            );
          },
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () async {
              tasks[index]["priority"] = selected;

              Navigator.pop(context);

              await saveTasks();

              if (mounted) {
                setState(() {});
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  int getPriorityScore(String priority) {
    switch (priority) {
      case "high":
        return 3;
      case "medium":
        return 2;
      case "low":
        return 1;
      default:
        return 2;
    }
  }

  Map<String, dynamic>? getNextTask() {
    final unfinishedTasks = tasks
        .where((task) => task["done"] != true)
        .toList();

    if (unfinishedTasks.isEmpty) {
      return null;
    }

    unfinishedTasks.sort((a, b) {
      return getPriorityScore(
        b["priority"],
      ).compareTo(getPriorityScore(a["priority"]));
    });

    return unfinishedTasks.first;
  }

  String getRecommendation() {
    final task = getNextTask();

    if (task == null) {
      return "🎉 Everything is complete!";
    }

    if (task.containsKey("subtasks")) {
      final incomplete = task["subtasks"]
          .where((s) => s["done"] != true)
          .toList();

      if (incomplete.isNotEmpty) {
        return '''
Task:
${task["task"]}

Next step:
${incomplete.first["text"]}
''';
      }
    }

    return '''
Task:
${task["task"]}
''';
  }

  Future<void> setDueDate(int index) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      tasks[index]["dueDate"] = pickedDate.toIso8601String().split("T").first;
    });

    await saveTasks();
  }

  String formatDueDate(String? dueDate) {
    if (dueDate == null) {
      return "";
    }

    final date = DateTime.parse(dueDate);

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final targetDate = DateTime(date.year, date.month, date.day);

    final difference = targetDate.difference(today).inDays;

    if (difference < 0) {
      return "Overdue";
    }

    if (difference == 0) {
      return "Today";
    }

    if (difference == 1) {
      return "Tomorrow";
    }

    if (difference <= 7) {
      return "In $difference days";
    }

    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> recommendNextTask() async {
    final recommendation = getRecommendation();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recommendation"),
        content: Text(recommendation),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('James ADHD Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Today's Tasks",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.psychology),
              label: const Text("What Should I Do Next?"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Recommendation"),
                    content: Text(getRecommendation()),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (isGenerating)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text("Generating ADHD starter steps..."),
                  ],
                ),
              ),
            TextField(
              controller: taskController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                await addTask();
              },
              decoration: const InputDecoration(
                labelText: 'Add a new task',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(onPressed: addTask, child: const Text('Add Task')),

            const SizedBox(height: 20),

            Expanded(
              child: ReorderableListView.builder(
                itemCount: tasks.length,
                onReorderItem: (oldIndex, newIndex) async {
                  setState(() {
                    final item = tasks.removeAt(oldIndex);
                    tasks.insert(newIndex, item);
                  });

                  await saveTasks();
                },
                itemBuilder: (context, index) {
                  return Container(
                    key: ValueKey("${tasks[index]["task"]}_$index"),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TaskTile(
                          task: tasks[index],
                          dueDateText: formatDueDate(tasks[index]["dueDate"]),
                          progress: getTaskProgress(tasks[index]),
                          isGenerating: isGenerating,
                          onToggle: (value) {
                            toggleTask(index, value);
                          },
                          onExpand: () {
                            toggleExpanded(index);
                          },
                          onGenerate: () {
                            handleGenerateSubtasks(index);
                          },
                          onRegenerate: () {
                            handleRegenerateSubtasks(index);
                          },
                          onAddSubtask: () {
                            addSubtask(index);
                          },
                          onPriority: () {
                            changePriority(index);
                          },
                          onEdit: () {
                            editTask(index);
                          },
                          onDelete: () {
                            showDeleteConfirmation(index);
                          },
                          onDueDate: () {
                            setDueDate(index);
                          },
                        ),
                        if (tasks[index].containsKey("subtasks") &&
                            tasks[index]["expanded"] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: Column(
                              children: List.generate(
                                tasks[index]["subtasks"].length,
                                (subIndex) {
                                  return SubtaskTile(
                                    subtask: tasks[index]["subtasks"][subIndex],

                                    onChanged: (value) {
                                      toggleSubtask(index, subIndex, value);
                                    },

                                    onMoveUp: () {
                                      moveSubtaskUp(index, subIndex);
                                    },

                                    onMoveDown: () {
                                      moveSubtaskDown(index, subIndex);
                                    },

                                    onEdit: () {
                                      editSubtask(index, subIndex);
                                    },

                                    onDelete: () {
                                      showDeleteSubtaskConfirmation(
                                        index,
                                        subIndex,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
