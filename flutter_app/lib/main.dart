import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_keys.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.init();
  } catch (e) {
    debugPrint('Firebase initialization skipped: $e');
  }
  runApp(const DaymapApp());
}

class DaymapApp extends StatelessWidget {
  const DaymapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daymap',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'pretendard',
      ),
      home: const HomeScreen(),
    );
  }
}
