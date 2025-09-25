// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:new_task_app/screens/homeScreen.dart';
import 'package:new_task_app/services/notification_service.dart';

import 'model/taskModel.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TaskModelAdapter());
  await Hive.openBox<TaskModel>('tasks');
  await NotificationService.init();
  await Firebase.initializeApp();
  FirebaseFirestore.instance
      .collection("test")
      .add({"message": "Hello Firebase!"})
      .then((value) => print("✅ Firebase write successful: ${value.id}"))
      .catchError((error) => print("❌ Firebase write failed: $error"));



  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
