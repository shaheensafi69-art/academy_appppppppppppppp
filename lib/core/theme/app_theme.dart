import 'package:flutter/material.dart';

class AppTheme {
  // رنگ‌های اصلی برند (Brand Colors)
  static const Color primary = Color(0xFF0284C7); // آبی/سایان اختصاصی Safi
  static const Color primaryDark = Color(0xFF0369A1);
  static const Color secondary = Color(0xFF10B981); // زمردی
  static const Color accent = Color(0xFF6366F1); // نیلی
  
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color textDark = Color(0xFF0F172A); // متن مشکی/تیره با کنتراست بالا
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundLight,
    
    // ترکیب رنگ‌ها (Color Scheme)
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surfaceLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textDark,
      error: Color(0xFFEF4444),
    ),

    // تایپوگرافی
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
      bodyLarge: TextStyle(fontSize: 16, color: textDark),
      bodyMedium: TextStyle(fontSize: 14, color: textMuted),
    ),

    // اصلاح کامل رنگ متون تقویم و انتخاب تاریخ (رفع مشکل متن سفید)
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      headerBackgroundColor: primary,
      headerForegroundColor: Colors.white,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return textDark; // رنگ مشکی/تیره برای روزهای تقویم
      }),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return textDark; // رنگ مشکی/تیره برای سال‌ها
      }),
      todayForegroundColor: const WidgetStatePropertyAll(primary),
      surfaceTintColor: Colors.transparent,
      dayStyle: const TextStyle(fontWeight: FontWeight.w500, color: textDark),
      weekdayStyle: const TextStyle(fontWeight: FontWeight.w600, color: textMuted),
    ),

    // استایل کادرهای ورودی (Input Fields)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    ),

    // استایل دکمه‌های اصلی
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    // اصلاح رنگ هایلایت و انتخاب متن (Selection Color)
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: Color(0xFFBAE6FD), // هایلایت آبی روشن برای خوانایی کامل
      selectionHandleColor: primary,
    ),
  );
}