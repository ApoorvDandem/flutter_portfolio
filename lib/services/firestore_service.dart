import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../model/taskModel.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = "tasks"; // you can customize per user later

  /// ✅ Add task to Firestore and mark as synced in Hive
  Future<void> addTask(TaskModel task) async {
    try {
      DocumentReference docRef = await _firestore.collection(collectionName).add(task.toMap());
      task.isSynced = true;
      await task.save(); // update in Hive
      print("✅ Task added to Firestore with id: ${docRef.id}");
    } catch (e) {
      print("❌ Error adding task to Firestore: $e");
    }
  }

  /// ✅ Update task in Firestore
  Future<void> updateTask(TaskModel task, String docId) async {
    try {
      await _firestore.collection(collectionName).doc(docId).update(task.toMap());
      task.isSynced = true;
      await task.save();
      print("✅ Task updated in Firestore");
    } catch (e) {
      print("❌ Error updating task: $e");
    }
  }

  /// ✅ Delete task from Firestore
  Future<void> deleteTask(String docId, TaskModel task) async {
    try {
      await _firestore.collection(collectionName).doc(docId).delete();
      await task.delete(); // remove from Hive
      print("✅ Task deleted from Firestore & Hive");
    } catch (e) {
      print("❌ Error deleting task: $e");
    }
  }

  /// ✅ Sync unsynced tasks from Hive → Firestore
  Future<void> syncTasks() async {
    final taskBox = Hive.box<TaskModel>('tasks');
    for (var task in taskBox.values) {
      if (!task.isSynced) {
        await addTask(task);
      }
    }
    print("🔄 Sync completed");
  }

  /// ✅ Fetch tasks from Firestore → return as list
  Future<List<TaskModel>> fetchTasks() async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs.map((doc) => TaskModel.fromMap(doc.data())).toList();
    } catch (e) {
      print("❌ Error fetching tasks: $e");
      return [];
    }
  }
}
