import 'package:flutter/material.dart';
import 'screens/chat_screen.dart'; // Import ChatScreen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LLM Graph Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Enable Material 3
      ),
      home: const ChatScreen(), // Set ChatScreen as the home screen
      // Remove the default counter app code (MyHomePage)
    );
  }
}
// Remove the MyHomePage and _MyHomePageState classes entirely
