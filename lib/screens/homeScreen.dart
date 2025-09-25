// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For formatting date/time
import '../model/taskModel.dart';
import '../viewmodels/task_view_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasks"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showTaskBottomSheet(context, ref),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
        child: Text(
          'You can add your tasks by clicking the "+" icon',
          style: TextStyle(color: Colors.black.withOpacity(0.6)),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            margin:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        task.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  if (task.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        "Due: ${DateFormat('dd MMM yyyy, hh:mm a').format(task.dueDate!.toLocal())}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                        ),
                      ),
                    ),
                  if (task.recurrence != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        task.recurrence == 1
                            ? "Repeats daily"
                            : "Repeats weekly",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  Checkbox(
                    value: task.isCompleted,
                    onChanged: (value) {
                      ref
                          .read(taskProvider.notifier)
                          .toggleComplete(index, value ?? false);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _editTask(context, ref, index, task),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => ref
                        .read(taskProvider.notifier)
                        .deleteTask(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTaskBottomSheet(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descrController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    int recurrence = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Add New Task",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: descrController,
                      decoration:
                      const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(selectedDate == null
                          ? "Select Due Date"
                          : "Due Date: ${DateFormat('dd MMM yyyy').format(selectedDate!)}"),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Text(selectedTime == null
                          ? "Select Time"
                          : "Time: ${selectedTime!.format(context)}"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<int>(
                      value: recurrence,
                      onChanged: (val) {
                        setState(() {
                          recurrence = val ?? 0;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("No Repeat")),
                        DropdownMenuItem(value: 1, child: Text("Daily")),
                        DropdownMenuItem(value: 2, child: Text("Weekly")),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty) return;

                        DateTime? dueDateTime;
                        if (selectedDate != null && selectedTime != null) {
                          dueDateTime = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                        }

                        final task = TaskModel(
                          title: titleController.text,
                          description: descrController.text,
                          dueDate: dueDateTime,
                          recurrence: recurrence,
                        );

                        ref.read(taskProvider.notifier).addTask(task);
                        Navigator.pop(context);
                      },
                      child: const Text("Add Task"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _editTask(
      BuildContext context, WidgetRef ref, int index, TaskModel task) {
    final titleController = TextEditingController(text: task.title);
    final descrController = TextEditingController(text: task.description);
    DateTime? selectedDate = task.dueDate;
    TimeOfDay? selectedTime =
    task.dueDate != null ? TimeOfDay.fromDateTime(task.dueDate!) : null;
    int recurrence = task.recurrence;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Edit Task",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: descrController,
                      decoration:
                      const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        selectedDate == null
                            ? "Select Due Date"
                            : "Due Date: ${DateFormat('dd MMM yyyy').format(selectedDate!)}",
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ??
                              TimeOfDay.fromDateTime(DateTime.now()),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Text(selectedTime == null
                          ? "Select Time"
                          : "Time: ${selectedTime!.format(context)}"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<int>(
                      value: recurrence,
                      onChanged: (val) {
                        setState(() {
                          recurrence = val ?? 0;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("No Repeat")),
                        DropdownMenuItem(value: 1, child: Text("Daily")),
                        DropdownMenuItem(value: 2, child: Text("Weekly")),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        DateTime? dueDateTime;
                        if (selectedDate != null && selectedTime != null) {
                          dueDateTime = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                        }

                        final updatedTask = TaskModel(
                          title: titleController.text,
                          description: descrController.text,
                          dueDate: dueDateTime,
                          recurrence: recurrence,
                          isCompleted: task.isCompleted,
                          firestoreId:
                          task.firestoreId, // ✅ keep Firestore link
                        );

                        ref
                            .read(taskProvider.notifier)
                            .updateTask(index, updatedTask);
                        Navigator.pop(context);
                      },
                      child: const Text("Update Task"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
