import 'package:hive/hive.dart';

part 'taskModel.g.dart'; // Hive will generate this

@HiveType(typeId: 0)
class TaskModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  bool isSynced;

  @HiveField(4)
  DateTime? dueDate;

  /// 0 = none, 1 = daily, 2 = weekly
  @HiveField(5)
  int recurrence;

  /// 🔑 Firestore docId
  @HiveField(6)
  String? firestoreId;

  /// 🔑 Local UUID to uniquely track tasks across offline/online
  @HiveField(7) // ⚡ new field → safe
  String? localUuid;

  TaskModel({
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isSynced = false,
    this.dueDate,
    this.recurrence = 0,
    this.firestoreId,
    this.localUuid, // <-- new
  });

  /// ✅ Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'isSynced': isSynced,
      'dueDate': dueDate?.toIso8601String(),
      'recurrence': recurrence,
      'firestoreId': firestoreId,
      'localUuid': localUuid, // <-- include it
    };
  }

  /// ✅ Create from Firestore map
  factory TaskModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return TaskModel(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      isSynced: map['isSynced'] ?? false,
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      recurrence: map['recurrence'] ?? 0,
      firestoreId: id ?? map['firestoreId'],
      localUuid: map['localUuid'], // <-- recover if it exists
    );
  }
}
