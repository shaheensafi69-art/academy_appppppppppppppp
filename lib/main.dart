import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت دروازه احراز هویت و صفحه ولکام اسکرین
// ignore: unused_import
import 'core/routing/auth_gate.dart'; 
import 'features/auth/screens/welcome_screen.dart'; // 👈 مسیر ولکام اسکرین شما

Future<void> main() async {
  // این خط به فلاتر می‌گوید قبل از اجرای اپلیکیشن، هسته اصلی را آماده کن
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 اتصال مستقیم و بدون وابستگی به فایل .env (مخصوص بیلد مطمئن روی موبایل)
  await Supabase.initialize(
    url: 'https://enpuoypqpklndnnhndax.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucHVveXBxcGtsbmRubmhuZGF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzg1MjgsImV4cCI6MjA5ODY1NDUyOH0.slU2vYIzM0BXG_3ksR5pcfvP-cpFH7IkwIyuzF1pNCo',
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