import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUiHelper {
  static int _androidSdkVersion = 0;

  /// Initialize the Android SDK version checks and activate full screen immersive mode immediately.
  static Future<void> init() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _androidSdkVersion = androidInfo.version.sdkInt;
      } catch (e) {
        _androidSdkVersion = 0;
        debugPrint('SystemUiHelper initialization error: $e');
      }
    }

    // پنهان کردن نوگیشن بار گوشی و حالت فول اسکرین در بدو باز شدن اپ
    await enableFullScreen();
  }

  /// Enables true fullscreen immersive sticky mode across the app.
  static Future<void> enableFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Appends appropriate system bar styles depending on device capabilities and views.
  static void setSystemStyle({required bool isReels}) {
    // در کل اپ، نوگیشن بار گوشی مخفی (immersiveSticky) باقی می‌ماند
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // On Android 15+ (API 35+), setting statusBarColor, systemNavigationBarColor,
    // and systemNavigationBarDividerColor is deprecated by Android and flagged by Play Console.
    // Edge-to-edge handles transparency automatically.
    if (Platform.isAndroid && _androidSdkVersion >= 35) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          systemNavigationBarIconBrightness: isReels ? Brightness.light : Brightness.dark,
          statusBarIconBrightness: isReels ? Brightness.light : Brightness.dark,
        ),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: isReels ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness: isReels ? Brightness.light : Brightness.dark,
          statusBarColor: Platform.isAndroid ? Colors.transparent : null,
          systemNavigationBarColor: Platform.isAndroid ? Colors.transparent : null,
        ),
      );
    }
  }
}
