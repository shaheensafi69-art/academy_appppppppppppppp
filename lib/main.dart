import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت صفحه ولکام اسکرین و پنل‌های مختلف
import '../../features/auth/screens/welcome_screen.dart';
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

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color surfaceWhite = Colors.white;
  static const Color textGrey = Color(0xFF6B7280);

  Future<String> _fetchUserRole(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return response?['role'] ?? 'student';
    } catch (e) {
      debugPrint("Error fetching user role: $e");
      return 'student';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // بررسی وضعیت سشن کاربر
        final session = supabase.auth.currentSession;

        // ۱. اگر کاربر لاگین نبود، اپلیکیشن از WelcomeScreen شروع می‌شود
        if (session == null) {
          return const WelcomeScreen();
        }

        // ۲. اگر کاربر از قبل لاگین بود، نقش او را واکشی کرده و به داشبورد مربوطه می‌رویم
        return FutureBuilder<String>(
          future: _fetchUserRole(session.user.id),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: surfaceWhite,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
                      const SizedBox(height: 14),
                      Text(
                        "LOADING DASHBOARD...",
                        style: TextStyle(
                          color: textGrey,
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

            final userRole = roleSnapshot.data ?? 'student';

            // ۳. هدایت مستقیم به پنل بر اساس رول کاربر
            if (userRole == 'super_admin' || userRole == 'admin') {
              return const AdminMainLayout();
            } else if (userRole == 'teacher') {
              return const TeacherMainLayout();
            } else {
              return const StudentMainLayout();
            }
          },
        );
      },
    );
  }
}