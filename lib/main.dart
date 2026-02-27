// اسم الملف: lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'menu_screen.dart'; // استيراد ملف الشاشة
import 'constants.dart';   // استيراد ملف الثوابت الجديد

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Supabase باستخدام القيم الموجودة في ملف الثوابت
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق المطعم',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}