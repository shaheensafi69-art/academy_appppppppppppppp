import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت صفحات اصلی پنل‌ها و صفحه خوش‌آمدگویی
import '../../features/auth/screens/welcome_screen.dart'; // <--- صفحه خوش‌آمدگویی (یا نام دلخواه شما)
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
  Widget _targetScreen = const WelcomeScreen(); // پیش‌فرض صفحه خوش‌آمدگویی است

  // رنگ اصلی صورتی غلیظ
  static const Color primaryPink = Color(0xFFC2185B);

  @override
  void initState() {
    super.initState();
    _initializeAuthListener();
  }

  /// گوش دادن به تغییرات نشست (Auth State Changes) برای پایداری ۱۰۰٪ لاگین
  void _initializeAuthListener() {
    // بررسی اولیه نشست موجود
    _resolveUserSessionAndRole(supabase.auth.currentSession);

    // گوش دادن به تغییرات بعدی (مانند باز شدن مجدد اپلیکیشن یا قطع و وصل شبکه)
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _resolveUserSessionAndRole(session);
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _targetScreen = const WelcomeScreen(); // بازگشت به ویلکم اسکرین در صورت لاگ اوت دستی
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _resolveUserSessionAndRole(Session? session) async {
    try {
      // ۱. اگر کاربر لاگین نیست -> هدایت به صفحه خوش‌آمدگویی (WelcomeScreen)
      if (session == null) {
        if (mounted) {
          setState(() {
            _targetScreen = const WelcomeScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // ۲. اگر کاربر لاگین است -> گرفتن نقش از جدول profiles با مکانیزم ایمن در برابر خطا
      final user = session.user;
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      // اگر پروفایل هنوز کامل ساخته نشده بود یا خطای موقت شبکه داد، نقش پیش‌فرض را student در نظر می‌گیریم تا لاگ‌اوت نشود
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
      debugPrint("Auth Resolution Error: $e");
      // در صورت بروز خطای اینترنت، اگر نشست معتبر است، کاربر را لاگ‌اوت نکنیم بلکه به پنل پیش‌فرض هدایتش کنیم
      if (mounted) {
        setState(() {
          // اگر کاربر سشن معتبر دارد اما خطای اینترنت رخ داده، او را به پنل استیودنت یا آخرین وضعیت هدایت کن تا بیرون پرت نشود
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