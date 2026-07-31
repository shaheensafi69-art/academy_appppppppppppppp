import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت دروازه احراز هویت و صفحه ولکام اسکرین
// ignore: unused_import
import 'core/routing/auth_gate.dart'; 
import 'features/auth/screens/welcome_screen.dart'; // 👈 مسیر ولکام اسکرین شما

Future<void> main() async {
  // این خط به فلاتر می‌گوید قبل از اجرای اپلیکیشن، هسته اصلی را آماده کن
  WidgetsFlutterBinding.ensureInitialized();

  // خواندن تمام کلیدها از فایل .env
  await dotenv.load(fileName: ".env");

  // اتصال به دیتابیس سوپابیس با استفاده از کلیدها
  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!,
    // ignore: deprecated_member_use
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!,
  );

  runApp(const SafiAcademyApp());
}

class SafiAcademyApp extends StatelessWidget {
  const SafiAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safi Academy',
      debugShowCheckedModeBanner: false, // حذف نوار قرمز Debug از گوشه تصویر
      theme: ThemeData(
        // رنگ‌بندی پایه اپلیکیشن (مشابه تم تیره سایت شما)
        scaffoldBackgroundColor: const Color(0xFF020202), 
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
        ),
        useMaterial3: true,
      ),
      // 👈 اپلیکیشن به محض باز شدن، اول صفحه WelcomeScreen را نشان می‌دهد
      // و بعد از زدن دکمه Get Started، کاربر به AuthGate (صفحه لاگین یا داشبورد) هدایت می‌شود
      home: const WelcomeScreen(), 
    );
  }
}