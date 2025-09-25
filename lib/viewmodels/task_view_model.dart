import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../model/taskModel.dart';
import '../services/notification_service.dart';

final taskProvider = StateNotifierProvider<TaskViewModel, List<TaskModel>>((ref) {
  return TaskViewModel();
});

class TaskViewModel extends StateNotifier<List<TaskModel>> {
  late Box<TaskModel> _taskBox;
  final _firestore = FirebaseFirestore.instance.collection("tasks");
  StreamSubscription? _connectivitySub;

  TaskViewModel() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _taskBox = Hive.box<TaskModel>('tasks');
    state = _taskBox.values.toList();

    // ✅ First sync any pending offline tasks
    await syncPendingTasks();

    // 🔄 Then fetch Firestore tasks and merge
    try {
      final snapshot = await _firestore.get();
      for (var doc in snapshot.docs) {
        final task = TaskModel.fromMap(doc.data(), id: doc.id);

        // Prevent duplicates: match either firestoreId OR localUuid
        bool alreadyExists = _taskBox.values.any((t) =>
        (t.firestoreId != null && t.firestoreId == doc.id) ||
            (t.localUuid != null && t.localUuid == task.localUuid));

        if (!alreadyExists) {
          await _taskBox.add(task..isSynced = true);
        }
      }
    } catch (_) {
      // offline, ignore
    }

    state = _taskBox.values.toList();

    // ✅ Auto-sync when connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPendingTasks();
      }
    });
  }

  Future<void> addTask(TaskModel task) async {
    // Assign a localUuid if missing
    task.localUuid ??= const Uuid().v4();

    // ✅ Save locally first
    final key = await _taskBox.add(task);
    state = _taskBox.values.toList();

    // Schedule notification if required
    if (task.dueDate != null) {
      await NotificationService.scheduleNotification(
        key,
        "Task Due",
        task.title,
        task.dueDate!,
        recurrence: task.recurrence,
      );
    }

    // Try syncing with Firestore
    try {
      final docRef = await _firestore.add(task.toMap());
      task.firestoreId = docRef.id;
      task.isSynced = true;
      await task.save();
    } catch (_) {
      task.isSynced = false; // offline, keep locally
      await task.save();
    }

    state = _taskBox.values.toList();
  }

  Future<void> updateTask(int index, TaskModel updated) async {
    final key = _taskBox.keyAt(index) as int;

    // Cancel old notification
    await NotificationService.cancelNotification(key);

    // Ensure localUuid is preserved
    if (updated.localUuid == null) {
      updated.localUuid = _taskBox.getAt(index)?.localUuid ?? const Uuid().v4();
    }

    // ✅ Update locally first
    await _taskBox.putAt(index, updated);
    state = _taskBox.values.toList();

    // Reschedule if needed
    if (updated.dueDate != null) {
      await NotificationService.scheduleNotification(
        key,
        "Task Due",
        updated.title,
        updated.dueDate!,
        recurrence: updated.recurrence,
      );
    }

    // Try Firestore update
    try {
      if (updated.firestoreId != null) {
        await _firestore.doc(updated.firestoreId!).update(updated.toMap());
      } else {
        final docRef = await _firestore.add(updated.toMap());
        updated.firestoreId = docRef.id;
      }
      updated.isSynced = true;
    } catch (_) {
      updated.isSynced = false;
    }
    await updated.save();
    state = _taskBox.values.toList();
  }

  Future<void> toggleComplete(int index, bool value) async {
    final task = _taskBox.getAt(index);
    if (task == null) return;

    // ✅ Update locally first
    task.isCompleted = value;
    await task.save();
    state = _taskBox.values.toList();

    final key = _taskBox.keyAt(index) as int;
    if (value) {
      await NotificationService.cancelNotification(key);
    } else if (task.dueDate != null) {
      await NotificationService.scheduleNotification(
        key,
        "Task Due",
        task.title,
        task.dueDate!,
        recurrence: task.recurrence,
      );
    }

    // Try Firestore update
    try {
      if (task.firestoreId != null) {
        await _firestore.doc(task.firestoreId!).update({'isCompleted': value});
      }
      task.isSynced = true;
    } catch (_) {
      task.isSynced = false;
    }

    await task.save();
    state = _taskBox.values.toList();
  }

  Future<void> deleteTask(int index) async {
    final key = _taskBox.keyAt(index) as int;
    final task = _taskBox.getAt(index);
    if (task == null) return;

    // Cancel any notification
    await NotificationService.cancelNotification(key);

    // ✅ Delete locally first
    await _taskBox.delete(key);
    state = _taskBox.values.toList();

    // Try Firestore delete
    try {
      if (task.firestoreId != null) {
        await _firestore.doc(task.firestoreId!).delete();
      }
    } catch (_) {
      // offline → task will remain deleted locally
      // but Firestore still has it until next sync
    }
  }

  /// 🔄 Sync all unsynced tasks with Firestore
  Future<void> syncPendingTasks() async {
    for (var task in _taskBox.values.where((t) => !t.isSynced)) {
      try {
        if (task.firestoreId != null) {
          // Update existing Firestore doc
          await _firestore.doc(task.firestoreId!).set(task.toMap());
        } else {
          // Look for Firestore doc with same localUuid
          final query = await _firestore
              .where('localUuid', isEqualTo: task.localUuid)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            // Found → update it
            final docId = query.docs.first.id;
            await _firestore.doc(docId).set(task.toMap());
            task.firestoreId = docId;
          } else {
            // Not found → create new doc
            final docRef = await _firestore.add(task.toMap());
            task.firestoreId = docRef.id;
          }
        }
        task.isSynced = true;
        await task.save();
      } catch (_) {
        // still offline, skip
      }
    }
    state = _taskBox.values.toList();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
