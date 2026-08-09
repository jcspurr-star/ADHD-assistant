import 'package:flutter_test/flutter_test.dart';
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/services/recommendation_service.dart';

void main() {
  test(
    'Add task, set due date, change priority, add subtask, recommendation ordering',
    () {
      final tasks = <Task>[];

      // Add two tasks
      tasks.add(Task(task: 'Task A'));
      tasks.add(Task(task: 'Task B'));

      // Set due dates: Task A tomorrow, Task B today
      final now = DateTime.now();
      tasks[0].dueDate = now
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      tasks[1].dueDate = now.toIso8601String().split('T').first;

      // Set priorities
      tasks[0].priority = 'high';
      tasks[1].priority = 'low';

      // Add subtasks to Task B and mark first as incomplete
      tasks[1].subtasks.add(Subtask(text: 'Step 1', done: false));
      tasks[1].subtasks.add(Subtask(text: 'Step 2', done: false));

      // Recommendation should pick Task B (due today) over Task A (tomorrow)
      final rec = RecommendationService.getRecommendation(tasks);

      expect(rec.contains('Task:'), isTrue);
      expect(rec.contains('Task B'), isTrue);
      expect(rec.contains('Next step') || rec.contains('Due:'), isTrue);
    },
  );
}
