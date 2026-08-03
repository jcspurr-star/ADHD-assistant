import 'package:flutter/material.dart';

void main() {
  runApp(const ADHDApp());
}

class ADHDApp extends StatelessWidget {
  const ADHDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'James ADHD Assistant',
      home: const ADHDHomePage(),
      debugShowCheckedModeBanner: false,
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

  List<Map<String, dynamic>> tasks = [
    {"task": "Take medication", "done": false},
    {"task": "Check calendar", "done": false},
  ];

  void addTask() {
    if (taskController.text.trim().isNotEmpty) {
      setState(() {
        tasks.add({"task": taskController.text.trim(), "done": false});
      });
      taskController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("James ADHD Assistant")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Today's Tasks",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: taskController,
              decoration: const InputDecoration(
                labelText: "Add a new task",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(onPressed: addTask, child: const Text("Add Task")),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text(tasks[index]["task"]),
                    value: tasks[index]["done"],
                    onChanged: (value) {
                      setState(() {
                        tasks[index]["done"] = value;
                      });
                    },
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
