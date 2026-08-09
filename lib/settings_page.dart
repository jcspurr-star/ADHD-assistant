import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsPageResult {
  final List<String> categories;
  final String starterStepPrompt;
  final String taskSubtaskPrompt;
  final List<String> contextTodayOptions;
  final List<String> otherMedicationOptions;
  final List<String> dopamineCrashSymptomOptions;
  final List<String> dopamineCrashAdditionalSymptomOptions;
  final int priorityCardCount;
  final int outlookLookAheadDays;

  const SettingsPageResult({
    required this.categories,
    required this.starterStepPrompt,
    required this.taskSubtaskPrompt,
    required this.contextTodayOptions,
    required this.otherMedicationOptions,
    required this.dopamineCrashSymptomOptions,
    required this.dopamineCrashAdditionalSymptomOptions,
    required this.priorityCardCount,
    required this.outlookLookAheadDays,
  });
}

class SettingsPage extends StatefulWidget {
  final List<String> categories;
  final String starterStepPrompt;
  final String taskSubtaskPrompt;
  final List<String> contextTodayOptions;
  final List<String> otherMedicationOptions;
  final List<String> dopamineCrashSymptomOptions;
  final List<String> dopamineCrashAdditionalSymptomOptions;
  final int priorityCardCount;
  final int outlookLookAheadDays;
  final String defaultStarterStepPrompt;
  final String defaultTaskSubtaskPrompt;

  const SettingsPage({
    super.key,
    required this.categories,
    required this.starterStepPrompt,
    required this.taskSubtaskPrompt,
    required this.contextTodayOptions,
    required this.otherMedicationOptions,
    required this.dopamineCrashSymptomOptions,
    required this.dopamineCrashAdditionalSymptomOptions,
    required this.priorityCardCount,
    required this.outlookLookAheadDays,
    required this.defaultStarterStepPrompt,
    required this.defaultTaskSubtaskPrompt,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String exampleTask =
      'Reply to the landlord about the boiler repair';
  static const int exampleStepCount = 4;

  late List<String> categories;
  late List<String> contextTodayOptions;
  late List<String> otherMedicationOptions;
  late List<String> dopamineCrashSymptomOptions;
  late List<String> dopamineCrashAdditionalSymptomOptions;
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController editCategoryController = TextEditingController();
  final TextEditingController promptController = TextEditingController();
  final TextEditingController taskSubtaskPromptController =
      TextEditingController();
  final TextEditingController contextOptionController = TextEditingController();
  final TextEditingController contextEditController = TextEditingController();
  final TextEditingController otherMedicationController =
      TextEditingController();
  final TextEditingController otherMedicationEditController =
      TextEditingController();
  final TextEditingController crashSymptomController = TextEditingController();
  final TextEditingController crashSymptomEditController =
      TextEditingController();
  final TextEditingController crashAdditionalController =
      TextEditingController();
  final TextEditingController crashAdditionalEditController =
      TextEditingController();
  late int priorityCardCount;
  late int outlookLookAheadDays;
  int? contextEditingIndex;
  int? otherMedicationEditingIndex;
  int? crashSymptomEditingIndex;
  int? crashAdditionalEditingIndex;
  int? editingIndex;

  @override
  void initState() {
    super.initState();
    categories = List<String>.from(widget.categories);
    contextTodayOptions = List<String>.from(widget.contextTodayOptions);
    otherMedicationOptions = List<String>.from(widget.otherMedicationOptions);
    dopamineCrashSymptomOptions = List<String>.from(
      widget.dopamineCrashSymptomOptions,
    );
    dopamineCrashAdditionalSymptomOptions = List<String>.from(
      widget.dopamineCrashAdditionalSymptomOptions,
    );
    promptController.text = widget.starterStepPrompt;
    taskSubtaskPromptController.text = widget.taskSubtaskPrompt;
    priorityCardCount = widget.priorityCardCount;
    outlookLookAheadDays = widget.outlookLookAheadDays;
  }

  @override
  void dispose() {
    categoryController.dispose();
    editCategoryController.dispose();
    promptController.dispose();
    taskSubtaskPromptController.dispose();
    contextOptionController.dispose();
    contextEditController.dispose();
    otherMedicationController.dispose();
    otherMedicationEditController.dispose();
    crashSymptomController.dispose();
    crashSymptomEditController.dispose();
    crashAdditionalController.dispose();
    crashAdditionalEditController.dispose();
    super.dispose();
  }

  bool addOption(List<String> options, TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty || options.contains(value)) {
      return false;
    }

    options.add(value);
    controller.clear();
    return true;
  }

  bool saveEditedOption(
    List<String> options,
    int index,
    TextEditingController controller,
  ) {
    final value = controller.text.trim();
    final currentValue = options[index];
    if (value.isEmpty || (value != currentValue && options.contains(value))) {
      return false;
    }

    options[index] = value;
    return true;
  }

  List<String> missingPlaceholders(String prompt, List<String> placeholders) {
    return placeholders
        .where((placeholder) => !prompt.contains(placeholder))
        .toList();
  }

  void saveAndPop() {
    final starterPrompt = promptController.text.trim();
    final taskSubtaskPrompt = taskSubtaskPromptController.text.trim();

    final missingStarterPlaceholders = missingPlaceholders(
      starterPrompt,
      const ['{task}', '{stepCount}'],
    );

    if (missingStarterPlaceholders.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Starter prompt must include ${missingStarterPlaceholders.join(' and ')}.',
          ),
        ),
      );
      return;
    }

    final missingSubtaskPlaceholders = missingPlaceholders(
      taskSubtaskPrompt,
      const ['{task}', '{existingSubtasks}', '{stepCount}'],
    );

    if (missingSubtaskPlaceholders.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subtask prompt must include ${missingSubtaskPlaceholders.join(' and ')}.',
          ),
        ),
      );
      return;
    }

    final result = SettingsPageResult(
      categories: categories.isEmpty ? ['None'] : categories,
      starterStepPrompt: starterPrompt,
      taskSubtaskPrompt: taskSubtaskPrompt,
      contextTodayOptions: contextTodayOptions,
      otherMedicationOptions: otherMedicationOptions,
      dopamineCrashSymptomOptions: dopamineCrashSymptomOptions,
      dopamineCrashAdditionalSymptomOptions:
          dopamineCrashAdditionalSymptomOptions,
      priorityCardCount: priorityCardCount,
      outlookLookAheadDays: outlookLookAheadDays,
    );
    Navigator.pop(context, result);
  }

  Widget buildEditableOptionsSection({
    required String title,
    required String description,
    required List<String> options,
    required TextEditingController addController,
    required TextEditingController editController,
    required int? editingIndex,
    required VoidCallback onAdd,
    required void Function(int index) onStartEdit,
    required VoidCallback onSaveEdit,
    required VoidCallback onCancelEdit,
    required void Function(int index) onRemove,
  }) {
    return buildSectionCard(
      title: title,
      description: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              if (index < options.length) {
                final isEditing = editingIndex == index;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: isEditing
                      ? BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: isEditing
                        ? TextField(
                            controller: editController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => onSaveEdit(),
                            decoration: const InputDecoration(
                              labelText: 'Edit option',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          )
                        : Text(options[index]),
                    trailing: isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: onSaveEdit,
                                tooltip: 'Save option',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: onCancelEdit,
                                tooltip: 'Cancel edit',
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => onStartEdit(index),
                                tooltip: 'Edit option',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => onRemove(index),
                                tooltip: 'Remove option',
                              ),
                            ],
                          ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onAdd(),
                        decoration: const InputDecoration(
                          labelText: 'New option',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(onPressed: onAdd, child: const Text('Add')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildTrackerOptionsSection() {
    return buildSectionCard(
      title: 'Tracker options',
      description:
          'Add or rename the options shown in Context Today, Other medications, and the crash tracker.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildEditableOptionsSection(
            title: 'Context today',
            description:
                'These are the tags shown in the Context Today section on the main screen.',
            options: contextTodayOptions,
            addController: contextOptionController,
            editController: contextEditController,
            editingIndex: contextEditingIndex,
            onAdd: () {
              setState(() {
                addOption(contextTodayOptions, contextOptionController);
              });
            },
            onStartEdit: (index) {
              setState(() {
                contextEditingIndex = index;
                contextEditController.text = contextTodayOptions[index];
              });
            },
            onSaveEdit: () {
              if (contextEditingIndex == null) return;
              setState(() {
                if (saveEditedOption(
                  contextTodayOptions,
                  contextEditingIndex!,
                  contextEditController,
                )) {
                  contextEditingIndex = null;
                  contextEditController.clear();
                }
              });
            },
            onCancelEdit: () {
              setState(() {
                contextEditingIndex = null;
                contextEditController.clear();
              });
            },
            onRemove: (index) {
              setState(() {
                contextTodayOptions.removeAt(index);
                if (contextEditingIndex == index) {
                  contextEditingIndex = null;
                  contextEditController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          buildEditableOptionsSection(
            title: 'Other medications',
            description:
                'These buttons appear in the Medication tab of the tracker.',
            options: otherMedicationOptions,
            addController: otherMedicationController,
            editController: otherMedicationEditController,
            editingIndex: otherMedicationEditingIndex,
            onAdd: () {
              setState(() {
                addOption(otherMedicationOptions, otherMedicationController);
              });
            },
            onStartEdit: (index) {
              setState(() {
                otherMedicationEditingIndex = index;
                otherMedicationEditController.text =
                    otherMedicationOptions[index];
              });
            },
            onSaveEdit: () {
              if (otherMedicationEditingIndex == null) return;
              setState(() {
                if (saveEditedOption(
                  otherMedicationOptions,
                  otherMedicationEditingIndex!,
                  otherMedicationEditController,
                )) {
                  otherMedicationEditingIndex = null;
                  otherMedicationEditController.clear();
                }
              });
            },
            onCancelEdit: () {
              setState(() {
                otherMedicationEditingIndex = null;
                otherMedicationEditController.clear();
              });
            },
            onRemove: (index) {
              setState(() {
                otherMedicationOptions.removeAt(index);
                if (otherMedicationEditingIndex == index) {
                  otherMedicationEditingIndex = null;
                  otherMedicationEditController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          buildEditableOptionsSection(
            title: 'Crash symptoms',
            description:
                'These are the core symptom chips shown in the Crash tab.',
            options: dopamineCrashSymptomOptions,
            addController: crashSymptomController,
            editController: crashSymptomEditController,
            editingIndex: crashSymptomEditingIndex,
            onAdd: () {
              setState(() {
                addOption(dopamineCrashSymptomOptions, crashSymptomController);
              });
            },
            onStartEdit: (index) {
              setState(() {
                crashSymptomEditingIndex = index;
                crashSymptomEditController.text =
                    dopamineCrashSymptomOptions[index];
              });
            },
            onSaveEdit: () {
              if (crashSymptomEditingIndex == null) return;
              setState(() {
                if (saveEditedOption(
                  dopamineCrashSymptomOptions,
                  crashSymptomEditingIndex!,
                  crashSymptomEditController,
                )) {
                  crashSymptomEditingIndex = null;
                  crashSymptomEditController.clear();
                }
              });
            },
            onCancelEdit: () {
              setState(() {
                crashSymptomEditingIndex = null;
                crashSymptomEditController.clear();
              });
            },
            onRemove: (index) {
              setState(() {
                dopamineCrashSymptomOptions.removeAt(index);
                if (crashSymptomEditingIndex == index) {
                  crashSymptomEditingIndex = null;
                  crashSymptomEditController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          buildEditableOptionsSection(
            title: 'Additional crash symptoms',
            description:
                'These are the extra symptom chips shown in the Crash tab.',
            options: dopamineCrashAdditionalSymptomOptions,
            addController: crashAdditionalController,
            editController: crashAdditionalEditController,
            editingIndex: crashAdditionalEditingIndex,
            onAdd: () {
              setState(() {
                addOption(
                  dopamineCrashAdditionalSymptomOptions,
                  crashAdditionalController,
                );
              });
            },
            onStartEdit: (index) {
              setState(() {
                crashAdditionalEditingIndex = index;
                crashAdditionalEditController.text =
                    dopamineCrashAdditionalSymptomOptions[index];
              });
            },
            onSaveEdit: () {
              if (crashAdditionalEditingIndex == null) return;
              setState(() {
                if (saveEditedOption(
                  dopamineCrashAdditionalSymptomOptions,
                  crashAdditionalEditingIndex!,
                  crashAdditionalEditController,
                )) {
                  crashAdditionalEditingIndex = null;
                  crashAdditionalEditController.clear();
                }
              });
            },
            onCancelEdit: () {
              setState(() {
                crashAdditionalEditingIndex = null;
                crashAdditionalEditController.clear();
              });
            },
            onRemove: (index) {
              setState(() {
                dopamineCrashAdditionalSymptomOptions.removeAt(index);
                if (crashAdditionalEditingIndex == index) {
                  crashAdditionalEditingIndex = null;
                  crashAdditionalEditController.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildDisplaySection() {
    return buildSectionCard(
      title: 'Display',
      description:
          'Choose how many priority cards are shown at the top and how many Outlook days appear on Today.',
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Priority cards shown'),
          DropdownButton<int>(
            value: priorityCardCount,
            items: const [1, 2, 3]
                .map(
                  (count) => DropdownMenuItem<int>(
                    value: count,
                    child: Text('$count'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                priorityCardCount = value;
              });
            },
          ),
          const Text('Outlook days shown'),
          DropdownButton<int>(
            value: outlookLookAheadDays,
            items: const [1, 2, 3, 4, 5, 6, 7]
                .map(
                  (days) =>
                      DropdownMenuItem<int>(value: days, child: Text('$days')),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                outlookLookAheadDays = value;
              });
            },
          ),
        ],
      ),
    );
  }

  void insertPlaceholder(TextEditingController controller, String placeholder) {
    final selection = controller.selection;
    final currentText = controller.text;
    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    final updatedText = currentText.replaceRange(start, end, placeholder);
    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + placeholder.length),
    );
  }

  void resetPromptToDefault() {
    setState(() {
      promptController.text = widget.defaultStarterStepPrompt;
      promptController.selection = TextSelection.collapsed(
        offset: promptController.text.length,
      );
    });
  }

  Future<void> copyDefaultPrompt() async {
    await Clipboard.setData(
      ClipboardData(text: widget.defaultStarterStepPrompt),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default prompt copied to clipboard.')),
    );
  }

  void resetTaskSubtaskPromptToDefault() {
    setState(() {
      taskSubtaskPromptController.text = widget.defaultTaskSubtaskPrompt;
      taskSubtaskPromptController.selection = TextSelection.collapsed(
        offset: taskSubtaskPromptController.text.length,
      );
    });
  }

  Future<void> copyDefaultTaskSubtaskPrompt() async {
    await Clipboard.setData(
      ClipboardData(text: widget.defaultTaskSubtaskPrompt),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default subtask prompt copied to clipboard.'),
      ),
    );
  }

  String buildPreviewPrompt() {
    final prompt = promptController.text.trim().isEmpty
        ? widget.defaultStarterStepPrompt
        : promptController.text;

    return prompt
        .replaceAll('{task}', exampleTask)
        .replaceAll('{stepCount}', exampleStepCount.toString());
  }

  String buildTaskSubtaskPreviewPrompt() {
    final prompt = taskSubtaskPromptController.text.trim().isEmpty
        ? widget.defaultTaskSubtaskPrompt
        : taskSubtaskPromptController.text;

    return prompt
        .replaceAll('{task}', exampleTask)
        .replaceAll(
          '{existingSubtasks}',
          '- Email landlord\n- Find boiler photo',
        )
        .replaceAll('{stepCount}', exampleStepCount.toString());
  }

  void addCategory() {
    final category = categoryController.text.trim();
    if (category.isEmpty || categories.contains(category)) {
      return;
    }

    setState(() {
      categories.add(category);
      categoryController.clear();
    });
  }

  void startEditingCategory(int index) {
    setState(() {
      editingIndex = index;
      editCategoryController.text = categories[index];
    });
  }

  void saveEditedCategory() {
    if (editingIndex == null) {
      return;
    }

    final newCategory = editCategoryController.text.trim();
    final currentCategory = categories[editingIndex!];
    if (newCategory.isEmpty ||
        (newCategory != currentCategory && categories.contains(newCategory))) {
      return;
    }

    setState(() {
      categories[editingIndex!] = newCategory;
      editingIndex = null;
      editCategoryController.clear();
    });
  }

  void cancelEditingCategory() {
    setState(() {
      editingIndex = null;
      editCategoryController.clear();
    });
  }

  void removeCategory(int index) {
    setState(() {
      categories.removeAt(index);
    });
  }

  Widget buildSectionCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget buildPromptSection() {
    return buildSectionCard(
      title: 'AI prompts',
      description:
          'Customize AI starter-step prompts. {task} and {stepCount} must stay in the prompt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Insert {task}'),
                onPressed: () {
                  insertPlaceholder(promptController, '{task}');
                },
              ),
              ActionChip(
                label: const Text('Insert {stepCount}'),
                onPressed: () {
                  insertPlaceholder(promptController, '{stepCount}');
                },
              ),
              TextButton(
                onPressed: copyDefaultPrompt,
                child: const Text('Copy default'),
              ),
              TextButton(
                onPressed: resetPromptToDefault,
                child: const Text('Reset to default prompt'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: promptController,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'AI prompt',
              helperText:
                  'Saving is blocked if {task} or {stepCount} is removed.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preview with example values',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  buildPreviewPrompt(),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTaskSubtaskPromptSection() {
    return buildSectionCard(
      title: 'Subtasks prompt',
      description:
          'Customize the Gemini request for full subtask suggestions. {task}, {existingSubtasks}, and {stepCount} must stay in the prompt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Insert {task}'),
                onPressed: () {
                  insertPlaceholder(taskSubtaskPromptController, '{task}');
                },
              ),
              ActionChip(
                label: const Text('Insert {existingSubtasks}'),
                onPressed: () {
                  insertPlaceholder(
                    taskSubtaskPromptController,
                    '{existingSubtasks}',
                  );
                },
              ),
              ActionChip(
                label: const Text('Insert {stepCount}'),
                onPressed: () {
                  insertPlaceholder(taskSubtaskPromptController, '{stepCount}');
                },
              ),
              TextButton(
                onPressed: copyDefaultTaskSubtaskPrompt,
                child: const Text('Copy default'),
              ),
              TextButton(
                onPressed: resetTaskSubtaskPromptToDefault,
                child: const Text('Reset to default prompt'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: taskSubtaskPromptController,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Subtasks prompt',
              helperText:
                  'Saving is blocked if {task}, {existingSubtasks}, or {stepCount} is removed.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preview with example values',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  buildTaskSubtaskPreviewPrompt(),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCategorySection() {
    return buildSectionCard(
      title: 'Task categories',
      description: 'Edit the categories available when assigning a task.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              if (index < categories.length) {
                final isEditing = editingIndex == index;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: isEditing
                      ? BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: isEditing
                        ? TextField(
                            controller: editCategoryController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => saveEditedCategory(),
                            decoration: const InputDecoration(
                              labelText: 'Edit category',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          )
                        : Text(categories[index]),
                    trailing: isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: saveEditedCategory,
                                tooltip: 'Save category',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: cancelEditingCategory,
                                tooltip: 'Cancel edit',
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  startEditingCategory(index);
                                },
                                tooltip: 'Edit category',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  removeCategory(index);
                                },
                                tooltip: 'Remove category',
                              ),
                            ],
                          ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: categoryController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => addCategory(),
                        decoration: const InputDecoration(
                          labelText: 'New category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: addCategory,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (didPop) {
          return;
        }
        saveAndPop();
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            actions: [
              TextButton(
                onPressed: saveAndPop,
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Categories'),
                Tab(text: 'AI Prompts'),
                Tab(text: 'Tracker Options'),
              ],
            ),
          ),
          body: Container(
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Manage AI prompts and task display/category options.',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          buildCategorySection(),
                          const SizedBox(height: 16),
                          buildDisplaySection(),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          buildPromptSection(),
                          const SizedBox(height: 16),
                          buildTaskSubtaskPromptSection(),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [buildTrackerOptionsSection()],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
