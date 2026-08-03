import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static Future<List<Map<String, dynamic>>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTasks = prefs.getString('tasks');

    if (savedTasks == null) {
      return [
        {"task": "Take medication", "done": false, "expanded": false},
        {"task": "Check calendar", "done": false, "expanded": false},
      ];
    }

    return List<Map<String, dynamic>>.from(jsonDecode(savedTasks));
  }

  static Future<void> saveTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('tasks', jsonEncode(tasks));
  }
}
