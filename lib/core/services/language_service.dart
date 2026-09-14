import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLanguage {
  final String code;
  final String name;
  final String englishName;
  final String flag;
  final bool isRtl;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.englishName,
    required this.flag,
    required this.isRtl,
  });
}

class LanguageService {
  LanguageService._internal();
  static final LanguageService instance = LanguageService._internal();

  static const String _prefKey = 'user_selected_language';

  // لیست کامل ۹ زبان با نام‌های بومی، پرچم‌ها و وضعیت راست‌چین/چپ‌چین
  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en',
      name: 'English',
      englishName: 'English',
      flag: '🇬🇧',
      isRtl: false,
    ),
    AppLanguage(
      code: 'fa',
      name: 'فارسی / دری',
      englishName: 'Persian (Dari)',
      flag: '🇦🇫',
      isRtl: true,
    ),
    AppLanguage(
      code: 'ps',
      name: 'پښتو',
      englishName: 'Pashto',
      flag: '🇦🇫',
      isRtl: true,
    ),
    AppLanguage(
      code: 'de',
      name: 'Deutsch',
      englishName: 'German',
      flag: '🇩🇪',
      isRtl: false,
    ),
    AppLanguage(
      code: 'fr',
      name: 'Français',
      englishName: 'French',
      flag: '🇫🇷',
      isRtl: false,
    ),
    AppLanguage(
      code: 'ur',
      name: 'اردو',
      englishName: 'Urdu',
      flag: '🇵🇰',
      isRtl: true,
    ),
    AppLanguage(
      code: 'tr',
      name: 'Türkçe',
      englishName: 'Turkish',
      flag: '🇹🇷',
      isRtl: false,
    ),
    AppLanguage(
      code: 'ru',
      name: 'Русский',
      englishName: 'Russian',
      flag: '🇷🇺',
      isRtl: false,
    ),
    AppLanguage(
      code: 'ar',
      name: 'العربية',
      englishName: 'Arabic',
      flag: '🇸🇦',
      isRtl: true,
    ),
  ];

  final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  Locale get currentLocale => localeNotifier.value;
  String get currentLanguageCode => localeNotifier.value.languageCode;

  bool get isCurrentRtl {
    return isRtl(currentLanguageCode);
  }

  static bool isRtl(String code) {
    return code == 'fa' || code == 'ps' || code == 'ur' || code == 'ar';
  }

  AppLanguage get currentLanguage {
    return supportedLanguages.firstWhere(
      (lang) => lang.code == currentLanguageCode,
      orElse: () => supportedLanguages.first,
    );
  }

  /// مقداردهی اولیه سرویس زبان از حافظه محلی کاربر
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null && supportedLanguages.any((l) => l.code == savedCode)) {
        localeNotifier.value = Locale(savedCode);
      }
    } catch (e) {
      debugPrint('LanguageService init warning: $e');
    }
  }

  /// تغییر زبان برنامه و ذخیره در SharedPreferences و همگام‌سازی با Supabase
  Future<void> changeLanguage(String code) async {
    if (!supportedLanguages.any((lang) => lang.code == code)) return;

    localeNotifier.value = Locale(code);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (e) {
      debugPrint('Error saving language to prefs: $e');
    }

    // به‌روزرسانی زبان انتخابی در پروفایل کاربر در سوپابیس
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'preferred_language': code})
            .eq('id', currentUser.id);
      }
    } catch (e) {
      debugPrint('Supabase profile language sync notice: $e');
    }
  }
}

/// اکستنشن‌های کاربردی برای دسترسی سریع به کدهای ترجمه و RTL
extension LocalizedContext on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this) ??
        (throw StateError('AppLocalizations not found in context'));
  }

  bool get isRtl {
    return Directionality.of(this) == TextDirection.rtl;
  }
}
