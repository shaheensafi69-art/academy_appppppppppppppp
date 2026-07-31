import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت صفحات اصلی پنل‌ها
import '../../features/auth/screens/login_screen.dart' as login_screen;
import '../../features/admin/screens/admin_main_layout.dart';
import '../../features/dashboard/screens/student_main_layout.dart'; // 👈 ایمپورت پنل کامل دانشجو
import '../../features/teacher/screens/teacher_main_layout.dart'; // 👈 ایمپورت لایوت کامل و پیشرفته استاد

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndRole();
    });
  }

  Future<void> _checkAuthAndRole() async {
    final session = supabase.auth.currentSession;

    // ۱. اگر کاربر لاگین نیست -> انتقال به صفحه لاگین
    if (session == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement( 
        MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
      );
      return;
    }

    // ۲. اگر کاربر لاگین است -> گرفتن نقش از جدول profiles در دیتابیس
    try {
      final user = session.user;
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final userRole = response['role'] ?? 'student';

      if (!mounted) return;

      // ۳. هدایت کاربر به پنل مخصوص خودش بر اساس فیلد role در دیتابیس
      if (userRole == 'super_admin' || userRole == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminMainLayout()), 
        );
      } else if (userRole == 'teacher') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeacherMainLayout()), // 👈 هدایت استاد به لایوت حرفه‌ای
        );
      } else {
        // حالت پیش‌فرض برای student (هدایت به پنل فول آپشن دانشجویی)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StudentMainLayout()),
        );
      }
    } catch (e) {
      // در صورت بروز هرگونه خطا برمی‌گردیم به صفحه لاگین
      if (!mounted) return;
      Navigator.of(context).pushReplacement( 
        MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // لودینگ اسکرین در هنگام بررسی سشن و نقش کاربر
    return const Scaffold(
      backgroundColor: Color(0xFF020202),
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}