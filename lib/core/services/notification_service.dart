import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("Handling background notification: ${message.messageId}");
  } catch (e) {
    debugPrint("Error handling background message: $e");
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final supabase = Supabase.instance.client;

  /// مقداردهی اولیه سیستم push notifications و فایربیس
  Future<void> initPushNotifications() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // دریافت مجوز نوتیفیکیشن از کاربر
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint("User notification permission status: ${settings.authorizationStatus}");

      // ذخیره توکن فایربیس هنگام شروع اپلیکیشن
      await saveFCMTokenToDatabase();

      // گوش دادن به تغییرات توکن دستگاه
      messaging.onTokenRefresh.listen((newToken) {
        _updateTokenInSupabase(newToken);
      });

      // دریافت نوتیفیکیشن زمانی که برنامه باز است (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground Message received: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint("Push notification initialization error: $e");
    }
  }

  /// گرفتن و ذخیره توکن FCM در جدول profiles کاربران در Supabase
  Future<void> saveFCMTokenToDatabase() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();

      if (token != null && token.isNotEmpty) {
        await _updateTokenInSupabase(token);
      }
    } catch (e) {
      debugPrint("Error saving FCM Token to Supabase: $e");
    }
  }

  Future<void> _updateTokenInSupabase(String token) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
      
      debugPrint("Successfully saved FCM token to Supabase profile for user: ${user.id}");
    } catch (e) {
      debugPrint("Error updating fcm_token in profiles table: $e");
    }
  }

  /// تابع کمکی برای ثبت اعلان جدید در دیتابیس (که Webhook/Trigger آن را فوری به FCM ارسال می‌کند)
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String message,
    required String notificationType, // 'like_comment', 'chat', 'class_reminder', 'admin_announcement', 'scheduled'
    String? linkUrl,
    String? senderId,
  }) async {
    try {
      await supabase.from("user_notifications").insert({
        'user_id': targetUserId,
        'sender_id': senderId,
        'title': title,
        'message': message,
        'notification_type': notificationType,
        'link_url': linkUrl,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error creating notification record in Supabase: $e");
    }
  }
}
