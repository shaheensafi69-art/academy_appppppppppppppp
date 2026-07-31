import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت صفحات اصلی پنل‌ها
import '../../features/auth/screens/login_screen.dart' as login_screen;
import '../../features/admin/screens/admin_main_layout.dart';
import '../../features/dashboard/screens/student_main_layout.dart';
import '../../features/teacher/screens/teacher_main_layout.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Widget _targetScreen = const login_screen.LoginScreen();

  // رنگ اصلی صورتی غلیظ
  static const Color primaryPink = Color(0xFFC2185B);

  @override
  void initState() {
    super.initState();
    _resolveUserSessionAndRole();
  }

  Future<void> _resolveUserSessionAndRole() async {
    try {
      final session = supabase.auth.currentSession;

      // ۱. اگر کاربر لاگین نیست
      if (session == null) {
        if (mounted) {
          setState(() {
            _targetScreen = const login_screen.LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // ۲. اگر کاربر لاگین است -> گرفتن نقش از جدول profiles
      final user = session.user;
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final userRole = response?['role'] ?? 'student';

      if (!mounted) return;

      // ۳. تعیین پنل بر اساس نقش کاربر
      Widget destination;
      if (userRole == 'super_admin' || userRole == 'admin') {
        destination = const AdminMainLayout();
      } else if (userRole == 'teacher') {
        destination = const TeacherMainLayout();
      } else {
        destination = const StudentMainLayout();
      }

      setState(() {
        _targetScreen = destination;
        _isLoading = false;
      });
    } catch (e) {
      // در صورت بروز خطا، بازگشت به صفحه لاگین جهت امنیت
      if (mounted) {
        setState(() {
          _targetScreen = const login_screen.LoginScreen();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink),
              const SizedBox(height: 16),
              Text(
                "VERIFYING SESSION...",
                style: TextStyle(
                  // ignore: deprecated_member_use
                  color: primaryPink.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _targetScreen;
  }
}