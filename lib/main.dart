import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'notification_service.dart';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await initializeDateFormatting('lv_LV', null);

  runApp(const WorkHourTrackerApp());
}

class WorkHourTrackerApp extends StatelessWidget {
  const WorkHourTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF24562B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF24562B),
          secondary: Colors.grey,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 192, 192, 192),
        appBarTheme: const AppBarTheme(color: Color(0xFF24562B)),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF24562B),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const LoginPage(),
    );
  }
}
