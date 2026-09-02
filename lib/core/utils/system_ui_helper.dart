import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUiHelper {
  static int _androidSdkVersion = 0;

  /// Initialize the Android SDK version checks.
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
  }

  /// Appends appropriate system bar styles depending on device capabilities and views.
  static void setSystemStyle({required bool isReels}) {
    if (isReels) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // On Android 15+, setting status/navigation bar colors directly is deprecated.
      // We only apply icon brightness to avoid triggering warnings on SDK 35+.
      if (Platform.isAndroid && _androidSdkVersion >= 35) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.light,
          ),
        );
      } else {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      if (Platform.isAndroid && _androidSdkVersion >= 35) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );
      } else {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );
      }
    }
  }
}
