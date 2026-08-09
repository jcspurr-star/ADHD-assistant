import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:adhd_assistant/models/task.dart';
import 'package:adhd_assistant/secrets.dart';

class GeminiService {
  static const String defaultStarterStepPromptTemplate = '''
You are an ADHD task initiation coach.

TASK:
{task}

Generate {stepCount} ADHD-friendly steps.

Return ONLY a JSON object with this property:
- steps: array of strings
''';

  static const String defaultSubtaskPromptTemplate = '''
You are helping break a task into practical subtasks.

MAIN TASK:
{task}

EXISTING SUBTASKS:
{existingSubtasks}

Generate up to {stepCount} useful subtasks.

If the existing subtasks list is empty, create a strong first-pass subtask list.
If the existing subtasks list already has items, only suggest missing subtasks that would meaningfully improve coverage.
Do not repeat or reword existing subtasks.

Return ONLY a JSON object with this property:
- steps: array of strings
''';

  static Future<GeminiTaskBreakdown> generateSubtasks(
    String task,
    int stepCount, {
    String? promptTemplate,
  }) async {
    final prompt = (promptTemplate == null || promptTemplate.trim().isEmpty)
        ? defaultStarterStepPromptTemplate
        : promptTemplate;

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
                "text": prompt
                    .replaceAll('{task}', task)
                    .replaceAll('{stepCount}', stepCount.toString()),
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      return GeminiTaskBreakdown(
        subtasks: [Subtask(text: "AI unavailable right now", done: false)],
      );
    }

    final data = jsonDecode(response.body);
    final text = data["candidates"][0]["content"]["parts"][0]["text"];
    final Map<String, dynamic> breakdown = jsonDecode(text);

    return GeminiTaskBreakdown(
      subtasks: (breakdown["steps"] as List<dynamic>)
          .map((step) => Subtask(text: step.toString(), done: false))
          .toList(),
    );
  }

  static Future<GeminiTaskBreakdown> generateTaskSubtasks(
    String task,
    List<Subtask> existingSubtasks,
    int stepCount, {
    String? promptTemplate,
  }) async {
    final prompt = (promptTemplate == null || promptTemplate.trim().isEmpty)
        ? defaultSubtaskPromptTemplate
        : promptTemplate;

    final existingText = existingSubtasks.isEmpty
        ? '- none yet'
        : existingSubtasks.map((subtask) => '- ${subtask.text}').join('\n');

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
                "text": prompt
                    .replaceAll('{task}', task)
                    .replaceAll('{existingSubtasks}', existingText)
                    .replaceAll('{stepCount}', stepCount.toString()),
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      return GeminiTaskBreakdown(
        subtasks: [Subtask(text: 'AI unavailable right now', done: false)],
      );
    }

    final data = jsonDecode(response.body);
    final text = data["candidates"][0]["content"]["parts"][0]["text"];
    final Map<String, dynamic> breakdown = jsonDecode(text);

    return GeminiTaskBreakdown(
      subtasks: (breakdown["steps"] as List<dynamic>)
          .map((step) => Subtask(text: step.toString(), done: false))
          .toList(),
    );
  }
}

class GeminiTaskBreakdown {
  final List<Subtask> subtasks;

  GeminiTaskBreakdown({required this.subtasks});
}
