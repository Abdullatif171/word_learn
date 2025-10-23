// main.dart
import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'firebase_options.dart';
// Firebase için gereken import'lar
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Firebase'in başlatılması için bu iki satır şart
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,

  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}