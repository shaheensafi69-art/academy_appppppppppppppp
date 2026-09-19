import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/welcome_screen.dart';

/// 🔐 هلپر مرکزی و پایدار برای مدیریت وضعیت ورود و خروج کاربران
class AuthHelper {
  AuthHelper._();

  static const String keyUserLoggedIn = 'user_is_logged_in';
  static const String keyUserExplicitlyLoggedOut = 'user_explicitly_logged_out';
  static const String keyCachedUserRole = 'cached_user_role';

  /// ثبت وضعیت ورود موفقیت‌آمیز کاربر
  static Future<void> markUserLoggedIn({
    required String userId,
    required String role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyUserLoggedIn, true);
      await prefs.setBool(keyUserExplicitlyLoggedOut, false);
      await prefs.setString('cached_user_role_$userId', role);
      await prefs.setString(keyCachedUserRole, role);
      await prefs.setString('logged_in_user_id', userId);
    } catch (e) {
      debugPrint("AuthHelper markUserLoggedIn warning: $e");
    }
  }

  /// خروج قطعی، فوق‌سریع و ایمن از حساب کاربری بدون معطلی حتی در اینترنت ضعیف یا آفلاین
  static Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyUserLoggedIn, false);
      await prefs.setBool(keyUserExplicitlyLoggedOut, true);
      await prefs.remove(keyCachedUserRole);

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await prefs.remove('cached_user_role_${user.id}');
        await prefs.remove('logged_in_user_id');
      }

      // ۱. خروج فوری سشن محلی دستگاه (با مهلت حداکثر ۲ ثانیه تا کاربر مسدود نشود)
      try {
        await Supabase.instance.client.auth
            .signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint("Local sign-out notice: $e");
      }

      // ۲. فراخوانی غیرهمگام خروج سرور سوپابیس در پس‌زمینه (Best-effort)
      Supabase.instance.client.auth.signOut().catchError((err) {
        debugPrint("Remote sign-out background notice: $err");
        return null;
      });
    } catch (e) {
      debugPrint("AuthHelper logout error: $e");
    } finally {
      // ۳. پاکسازی کامل پشته صفحات و هدایت فوری به صفحه ورود / خوش‌آمدگویی
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }
}
