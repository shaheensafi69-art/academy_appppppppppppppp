import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogEntry {
  final String id;
  final String deviceModel;
  final String osName;
  final String location;
  final String ipAddress;
  final DateTime timestamp;
  final bool isCurrent;

  ActivityLogEntry({
    required this.id,
    required this.deviceModel,
    required this.osName,
    required this.location,
    required this.ipAddress,
    required this.timestamp,
    this.isCurrent = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_model': deviceModel,
        'os_name': osName,
        'location': location,
        'ip_address': ipAddress,
        'timestamp': timestamp.toIso8601String(),
        'is_current': isCurrent,
      };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json, {bool isCurrent = false}) {
    return ActivityLogEntry(
      id: json['id']?.toString() ?? '',
      deviceModel: json['device_model']?.toString() ?? 'Mobile Device',
      osName: json['os_name']?.toString() ?? '',
      location: json['location']?.toString() ?? 'Unknown Location',
      ipAddress: json['ip_address']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isCurrent: isCurrent,
    );
  }
}

class ActivityLogService {
  static final ActivityLogService _instance = ActivityLogService._internal();
  factory ActivityLogService() => _instance;
  ActivityLogService._internal();

  static ActivityLogService get instance => _instance;

  final supabase = Supabase.instance.client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  String? _currentSessionId;

  String get currentSessionId {
    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    return _currentSessionId!;
  }

  /// دریافت نام مدل دستگاه
  Future<Map<String, String>> getDeviceDetails() async {
    String deviceModel = "Smartphone";
    String osName = "Mobile";

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceModel = webInfo.browserName.name.toUpperCase();
        osName = webInfo.platform ?? "Web";
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final brand = androidInfo.brand.toUpperCase();
        final model = androidInfo.model;
        deviceModel = "$brand $model";
        osName = "Android ${androidInfo.version.release}";
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceModel = iosInfo.name;
        osName = "iOS ${iosInfo.systemVersion}";
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        deviceModel = macInfo.model;
        osName = "macOS ${macInfo.osRelease}";
      } else if (Platform.isWindows) {
        deviceModel = "Windows PC";
        osName = "Windows";
      }
    } catch (e) {
      debugPrint("Error detecting device info: $e");
    }

    return {
      "model": deviceModel,
      "os": osName,
    };
  }

  /// دریافت موقعیت تقریبی بر اساس آی‌پی با لایه Fallback سریع
  Future<Map<String, String>> getApproximateLocation() async {
    String location = "Online";
    String ip = "—";

    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['city']?.toString();
        final country = data['country_name']?.toString();
        ip = data['ip']?.toString() ?? "—";

        if (city != null && country != null) {
          location = "$city, $country";
        } else if (country != null) {
          location = country;
        }
      }
    } catch (_) {
      // اگر ارتباط به هر دلیلی قطع بود
      location = "Secured Session";
    }

    return {
      "location": location,
      "ip": ip,
    };
  }

  /// ثبت لاگ ورود کاربر به سیستم
  Future<void> recordLogin(String userId) async {
    try {
      final device = await getDeviceDetails();
      final loc = await getApproximateLocation();
      final sessionId = currentSessionId;

      final newEntry = ActivityLogEntry(
        id: sessionId,
        deviceModel: device["model"] ?? "Mobile Device",
        osName: device["os"] ?? "OS",
        location: loc["location"] ?? "Online",
        ipAddress: loc["ip"] ?? "—",
        timestamp: DateTime.now(),
        isCurrent: true,
      );

      // ذخیره در SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = "activity_logs_$userId";
      final rawList = prefs.getStringList(key) ?? [];

      // تبدیل و افزودن آیتم جدید به اول لیست
      List<Map<String, dynamic>> list = rawList
          .map((item) {
            try {
              return jsonDecode(item) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      list.insert(0, newEntry.toJson());
      if (list.length > 20) {
        list = list.sublist(0, 20); // نگهداری ۲۰ لاگ اخیر
      }

      await prefs.setStringList(
        key,
        list.map((m) => jsonEncode(m)).toList(),
      );

      // تلاش برای ثبت در سوپابیس در صورت وجود جدول
      try {
        await supabase.from('user_login_activities').insert({
          'user_id': userId,
          'session_id': sessionId,
          'device_model': newEntry.deviceModel,
          'os_name': newEntry.osName,
          'location': newEntry.location,
          'ip_address': newEntry.ipAddress,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    } catch (e) {
      debugPrint("Failed to record activity log: $e");
    }
  }

  /// دریافت سوابق ورود کاربر
  Future<List<ActivityLogEntry>> getLogs(String userId) async {
    final List<ActivityLogEntry> logs = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "activity_logs_$userId";
      final rawList = prefs.getStringList(key) ?? [];

      for (var item in rawList) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          final isCurr = map['id'] == _currentSessionId;
          logs.add(ActivityLogEntry.fromJson(map, isCurrent: isCurr));
        } catch (_) {}
      }

      // اگر هنوز هیچ لاگی برای این سشن نیست، لاگ دستگاه فعلی را فوری بسازد
      if (logs.isEmpty) {
        final device = await getDeviceDetails();
        final loc = await getApproximateLocation();
        final currentEntry = ActivityLogEntry(
          id: currentSessionId,
          deviceModel: device["model"] ?? "Mobile Device",
          osName: device["os"] ?? "OS",
          location: loc["location"] ?? "Online",
          ipAddress: loc["ip"] ?? "—",
          timestamp: DateTime.now(),
          isCurrent: true,
        );
        logs.add(currentEntry);
        await prefs.setStringList(key, [jsonEncode(currentEntry.toJson())]);
      }
    } catch (e) {
      debugPrint("Error fetching activity logs: $e");
    }

    return logs;
  }

  /// پاک کردن تاریخچه لاگین‌ها (به جز نشست فعلی)
  Future<void> clearLogs(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "activity_logs_$userId";
      final logs = await getLogs(userId);
      final currentOnly = logs.where((l) => l.isCurrent).toList();
      await prefs.setStringList(
        key,
        currentOnly.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {}
  }
}
