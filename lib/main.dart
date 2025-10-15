import 'package:flutter/material.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ChatBotApp());
  } catch (e) {
    print('Firebase initialization error: $e');
  }
}

class ChatBotApp extends StatelessWidget {
  const ChatBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AskPSU Management System',
      theme: ThemeData.light(), // You can use dark if you prefer
      home: const AdminLoginPage(), 
    );
  }
}
