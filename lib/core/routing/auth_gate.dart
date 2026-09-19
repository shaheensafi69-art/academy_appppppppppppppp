import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/activity_log_service.dart';
import '../services/auth_helper.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';
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
      supabase.auth.onAuthStateChange.listen(
        (data) {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          if (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.initialSession ||
              event == AuthChangeEvent.userUpdated) {
            if (session != null) {
              _resolveUserSessionAndRole(session);
            }
          } else if (event == AuthChangeEvent.signedOut) {
            _handleExplicitSignOut();
          }
        },
        onError: (error) {
          debugPrint('Auth stream error: $error');
        },
      );

      _checkInitialSession();
    } catch (e) {
      debugPrint('Auth listener setup failed: $e');
      _showFallbackScreen();
    }
  }

  Future<void> _checkInitialSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isUserLoggedIn =
          prefs.getBool(AuthHelper.keyUserLoggedIn) ?? false;
      final bool isExplicitlyLoggedOut =
          prefs.getBool(AuthHelper.keyUserExplicitlyLoggedOut) ?? false;

      // ۱. اگر کاربر قبلاً لاگین کرده و دکمه خروج را نزده است (حفظ ۱۰۰٪ سشن حتی در اینترنت ضعیف/آفلاین)
      if (isUserLoggedIn && !isExplicitlyLoggedOut) {
        // الف: اگر سشن سوپابیس همین حالا در حافظه موجود است
        if (supabase.auth.currentSession != null) {
          await _resolveUserSessionAndRole(supabase.auth.currentSession);
          return;
        }

        // ب: مهلت به سوپابیس برای لود سشن از استوریج محلی
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
          if (supabase.auth.currentSession != null) {
            await _resolveUserSessionAndRole(supabase.auth.currentSession);
            return;
          }
        }

        // ج: اگر به دلیل اینترنت ضعیف سشن هنوز نرسیده، مستقیماً لایوت با نقش کش‌شده لود شود تا کاربر به صفحه ولکام پرتاب نشود!
        final role = prefs.getString(AuthHelper.keyCachedUserRole) ?? 'student';
        Widget dest = const StudentMainLayout();
        if (role == 'super_admin' || role == 'admin') {
          dest = const AdminMainLayout();
        } else if (role == 'teacher') {
          dest = const TeacherMainLayout();
        }

        if (mounted) {
          setState(() {
            _targetScreen = dest;
            _isLoading = false;
          });
        }
        return;
      }

      // ۲. بررسی عادی سشن سوپابیس
      if (supabase.auth.currentSession != null) {
        await _resolveUserSessionAndRole(supabase.auth.currentSession);
        return;
      }

      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        if (supabase.auth.currentSession != null) {
          await _resolveUserSessionAndRole(supabase.auth.currentSession);
          return;
        }
      }

      // ۳. اگر واقعاً لاگینی وجود نداشت
      _showFallbackScreen();
    } catch (e) {
      debugPrint("Error in _checkInitialSession: $e");
      _showFallbackScreen();
    }
  }

  Future<void> _handleExplicitSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExplicit =
          prefs.getBool(AuthHelper.keyUserExplicitlyLoggedOut) ?? false;
      if (isExplicit) {
        _showFallbackScreen();
      } else {
        // نوسان موقت شبکه حین توکن رفرش است؛ سشن پایدار کاربر را تخریب نکن
        debugPrint(
            "Temporary signedOut event ignored because user did not explicitly log out");
      }
    } catch (_) {
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
      if (session == null) {
        _showFallbackScreen();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_explicitly_logged_out', false);

      // ۲. گرفتن نقش کاربر از جدول profiles با کش در SharedPreferences
      final user = session.user;
      String userRole = prefs.getString('cached_user_role_${user.id}') ??
          prefs.getString('cached_user_role') ??
          'student';

      try {
        final response = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (response != null && response['role'] != null) {
          userRole = response['role'].toString();
          await prefs.setString('cached_user_role_${user.id}', userRole);
          await prefs.setString('cached_user_role', userRole);
        }
      } catch (dbError) {
        debugPrint("Database profile fetch warning: $dbError");
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
      try {
        NotificationService().saveFCMTokenToDatabase();
      } catch (_) {}

      // ثبت خودکار فعالیت دستگاه کاربر در جدول دیتابیس device_activities
      try {
        ActivityLogService.instance.recordLogin(user.id);
      } catch (_) {}

      setState(() {
        _targetScreen = destination;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SecurityService.instance.verifyLockIfNeeded(context);
        }
      });
    } catch (e) {
      debugPrint("Auth Resolution Error: $e");
      if (mounted) {
        if (session != null) {
          // اگر سشن معتبر وجود دارد هرگز به صفحه لاگین بازنگردد
          try {
            final prefs = await SharedPreferences.getInstance();
            final role = prefs.getString('cached_user_role_${session.user.id}') ??
                prefs.getString('cached_user_role') ??
                'student';
            Widget fallback = const StudentMainLayout();
            if (role == 'super_admin' || role == 'admin') {
              fallback = const AdminMainLayout();
            } else if (role == 'teacher') {
              fallback = const TeacherMainLayout();
            }
            setState(() {
              _targetScreen = fallback;
              _isLoading = false;
            });
          } catch (_) {
            setState(() {
              _targetScreen = const StudentMainLayout();
              _isLoading = false;
            });
          }
        } else {
          _showFallbackScreen();
        }
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