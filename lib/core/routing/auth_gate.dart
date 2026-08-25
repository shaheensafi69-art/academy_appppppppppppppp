import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
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
  bool _isLoading = true;
  Widget _targetScreen = const WelcomeScreen();

  static const Color primaryPink = Color(0xFFF494AC);

  @override
  void initState() {
    super.initState();
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    try {
      _resolveUserSessionAndRole(supabase.auth.currentSession);

      supabase.auth.onAuthStateChange.listen(
        (data) {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
            _resolveUserSessionAndRole(session);
          } else if (event == AuthChangeEvent.signedOut) {
            _showFallbackScreen();
          }
        },
        onError: (error) {
          debugPrint('Auth stream error: $error');
          _showFallbackScreen();
        },
      );
    } catch (e) {
      debugPrint('Auth listener setup failed: $e');
      _showFallbackScreen();
    }
  }

  void _showFallbackScreen() {
    if (mounted) {
      setState(() {
        _targetScreen = const WelcomeScreen();
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveUserSessionAndRole(Session? session) async {
    try {
      // ۱. اگر کاربر لاگین نیست
      if (session == null) {
        if (mounted) {
          setState(() {
            _targetScreen = const WelcomeScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // ۲. گرفتن نقش کاربر از جدول profiles
      final user = session.user;
      String userRole = 'student'; // پیش‌فرض

      try {
        final response = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (response != null && response['role'] != null) {
          userRole = response['role'].toString();
        }
      } catch (dbError) {
        debugPrint("Database profile fetch warning: $dbError");
        // اگر اینترنت ضعیف بود یا جدول خطا داد، کاربر را پیش‌فرض به پنل استودنت می‌بریم تا کرش نکند
        userRole = 'student';
      }

      if (!mounted) return;

      // ۳. هدایت به پنل مربوطه
      Widget destination;
      if (userRole == 'super_admin' || userRole == 'admin') {
        destination = const AdminMainLayout();
      } else if (userRole == 'teacher') {
        destination = const TeacherMainLayout();
      } else {
        destination = const StudentMainLayout();
      }

      // ذخیره و آپدیت توکن FCM در دیتابیس سوپابیس برای کاربر فعال
      NotificationService().saveFCMTokenToDatabase();

      setState(() {
        _targetScreen = destination;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Auth Resolution Critical Error: $e");
      // محافظت کامل در برابر کرش: در صورت بروز خطای ناشناخته، کاربر به صفحه Welcome هدایت شود تا اپ بسته نشود
      if (mounted) {
        setState(() {
          _targetScreen = const WelcomeScreen();
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