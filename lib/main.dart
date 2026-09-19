import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/auth_gate.dart';
import 'core/services/ad_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/language_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/security_service.dart';
import 'core/theme/app_theme_service.dart';
import 'core/utils/system_ui_helper.dart';
import 'l10n/generated/app_localizations.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemUiHelper.init();

  // مقداردهی اولیه سرویس زبان
  await LanguageService.instance.init();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Dotenv initialization warning: $e');
  }

  bool isInitialized = false;
  for (int attempt = 1; attempt <= 3; attempt++) {
    try {
      await Supabase.initialize(
        url: 'https://enpuoypqpklndnnhndax.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucHVveXBxcGtsbmRubmhuZGF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzg1MjgsImV4cCI6MjA5ODY1NDUyOH0.slU2vYIzM0BXG_3ksR5pcfvP-cpFH7IkwIyuzF1pNCo',
      );
      isInitialized = true;
      break;
    } catch (e) {
      debugPrint('Supabase initialization attempt $attempt failed: $e');
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  if (isInitialized) {
    // مقداردهی اولیه فایربیس و نوتیفیکیشن‌ها
    try {
      NotificationService().initPushNotifications();
    } catch (_) {}

    // مقداردهی اولیه دیپ‌لینک‌ها برای باز کردن مستقیم ویدیوهای ریلز
    try {
      DeepLinkService().init(appNavigatorKey);
    } catch (_) {}

    // مقداردهی اولیه سرویس تبلیغات گوگل بدون کند کردن شروع برنامه
    try {
      AdService.instance.initialize();
    } catch (_) {}

    // مقداردهی اولیه سرویس تم‌های لوکس و رنگ‌های برنامه
    try {
      await AppThemeService.instance.initialize();
    } catch (_) {}
  }

  runApp(const SafiAcademyApp());
}

class SafiAcademyApp extends StatefulWidget {
  const SafiAcademyApp({super.key});

  @override
  State<SafiAcademyApp> createState() => _SafiAcademyAppState();
}

class _SafiAcademyAppState extends State<SafiAcademyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      SecurityService.instance.markSessionLocked();
    } else if (state == AppLifecycleState.resumed) {
      final context = appNavigatorKey.currentContext;
      if (context != null) {
        SecurityService.instance.verifyLockIfNeeded(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance.localeNotifier,
      builder: (context, currentLocale, _) {
        return ValueListenableBuilder<LuxuryPalette>(
          valueListenable: AppThemeService.instance.currentPaletteNotifier,
          builder: (context, luxuryPalette, _) {
            return MaterialApp(
              key: ValueKey('safi_app_${currentLocale.languageCode}_${luxuryPalette.id}'),
              navigatorKey: appNavigatorKey,
              title: 'Safi Academy',
              debugShowCheckedModeBanner: false,
              locale: currentLocale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              localeResolutionCallback: (locale, supportedLocales) {
                for (var supported in supportedLocales) {
                  if (supported.languageCode == currentLocale.languageCode) {
                    return supported;
                  }
                }
                return supportedLocales.first;
              },
              theme: luxuryPalette.toThemeData(),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}
