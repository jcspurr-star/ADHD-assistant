import 'dart:convert';
import 'package:http/http.dart' as http;

import '../secrets.dart';

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
