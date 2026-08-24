import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentContext {
  final String studentName;
  final List<String> enrolledCourses;
  final List<String> enrolledClassGroups;
  final List<String> availableAcademyCourses;
  final List<String> availableTeachers;

  StudentContext({
    required this.studentName,
    required this.enrolledCourses,
    required this.enrolledClassGroups,
    required this.availableAcademyCourses,
    required this.availableTeachers,
  });
}

class GeminiAiService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _apiKey {
    final key = dotenv.env['GOOGLE_GEMINI_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'] ?? '';
    return key.trim();
  }

  /// دریافت تمامی اطلاعات متنی دانش‌آموز و کاتالوگ دوره‌های آکادمی از دیتابیس
  Future<StudentContext> fetchStudentContext(String studentId) async {
    String studentName = "دانش‌آموز";
    List<String> enrolledCourses = [];
    List<String> enrolledClassGroups = [];
    List<String> availableAcademyCourses = [];
    List<String> availableTeachers = [];

    try {
      // 1. دریافت نام دانشجو از profiles
      final profile = await _supabase
          .from("profiles")
          .select("first_name, last_name")
          .eq("id", studentId)
          .maybeSingle();

      if (profile != null) {
        final fName = profile['first_name'] ?? '';
        final lName = profile['last_name'] ?? '';
        studentName = "$fName $lName".trim();
        if (studentName.isEmpty) studentName = "دانش‌آموز";
      }

      // 2. دریافت دوره‌های ثبت‌نام شده (enrollments -> courses)
      final enrollments = await _supabase
          .from("enrollments")
          .select("courses(title, category)")
          .eq("student_id", studentId);

      for (var item in (enrollments as List)) {
        if (item['courses'] != null && item['courses']['title'] != null) {
          enrolledCourses.add(item['courses']['title'].toString());
        }
      }

      // 3. دریافت کلاس‌های زنده ثبت‌نام شده (class_students -> class_groups)
      final classStudents = await _supabase
          .from("class_students")
          .select("class_groups(class_name, schedule_info)")
          .eq("student_id", studentId);

      for (var item in (classStudents as List)) {
        if (item['class_groups'] != null && item['class_groups']['class_name'] != null) {
          enrolledClassGroups.add(item['class_groups']['class_name'].toString());
        }
      }

      // 4. دریافت کلیه دوره‌های موجود در سافی آکادمی (جهت پاسخ به سوالات معرفی آکادمی)
      final allCourses = await _supabase
          .from("courses")
          .select("title, category, instructor_name, price")
          .limit(20);

      for (var c in (allCourses as List)) {
        final title = c['title'] ?? '';
        final instructor = c['instructor_name'] ?? '';
        if (title.isNotEmpty) {
          availableAcademyCourses.add("$title ${instructor.isNotEmpty ? "(مدرس: $instructor)" : ""}");
        }
      }

      // 5. دریافت لیست اساتید
      final teachers = await _supabase
          .from("teacher_info")
          .select("first_name, last_name, bio")
          .limit(10);

      for (var t in (teachers as List)) {
        final name = "${t['first_name'] ?? ''} ${t['last_name'] ?? ''}".trim();
        if (name.isNotEmpty) availableTeachers.add(name);
      }
    } catch (e) {
      debugPrint("GeminiAiService: Error fetching student context: $e");
    }

    return StudentContext(
      studentName: studentName,
      enrolledCourses: enrolledCourses,
      enrolledClassGroups: enrolledClassGroups,
      availableAcademyCourses: availableAcademyCourses,
      availableTeachers: availableTeachers,
    );
  }

  /// ساخت پرامپت سیستمی دقیق و هوشمند
  String _buildSystemPrompt(StudentContext ctx) {
    final enrolledCoursesStr = ctx.enrolledCourses.isNotEmpty
        ? ctx.enrolledCourses.join("، ")
        : "هنوز در هیچ دوره‌ای ثبت‌نام نکرده است";

    final enrolledClassesStr = ctx.enrolledClassGroups.isNotEmpty
        ? ctx.enrolledClassGroups.join("، ")
        : "عضو هیچ کلاس گروهی زنده نیست";

    final availableCoursesStr = ctx.availableAcademyCourses.isNotEmpty
        ? ctx.availableAcademyCourses.join("\n- ")
        : "دوره‌های دیجیتال مارکتینگ، شاپیفای (Shopify)، ترید و بازارهای مالی، برنامه‌نویسی و وب";

    final availableTeachersStr = ctx.availableTeachers.isNotEmpty
        ? ctx.availableTeachers.join("، ")
        : "اساتید مجرب آکادمی سافی";

    return '''
شما دستیار هوشمند اختصاصی و رسمی آکادمی آموزش عالی "سافی آکادمی" (Safi Academy) هستید.

اطلاعات دانش‌آموز فعلی (کاربر):
- نام دانش‌آموز: ${ctx.studentName}
- دوره‌های ثبت‌نام شده فعلی: $enrolledCoursesStr
- کلاس‌های زنده فعلی: $enrolledClassesStr

لیست دوره‌های فعال و موجود در سافی آکادمی:
- $availableCoursesStr

اساتید سافی آکادمی:
$availableTeachersStr

قوانین حتمی و الزامی پاسخ‌دهی (قوانین دامنه و دسترسی):
1. **سوالات تخصصی مربوط به دوره‌های ثبت‌نام‌شده کاربر**:
   اگر کاربر سوالی درباره موضوعات درسی دوره‌ها یا کلاس‌هایی که در آن ثبت‌نام کرده (مانند $enrolledCoursesStr) پرسید، با تمام جزئیات، کدنویسی، پاسخ عمیق آموزشی، راهنمایی گام‌به‌گام و تخصص کامل پاسخ دهید.

2. **سوالات تخصصی مربوط به سایر دوره‌های آکادمی (ثبت‌نام نشده)**:
   اگر کاربر سوال تخصصی و عمیق درباره موضوعی پرسید که مربوط به دوره‌های دیگر آکادمی است اما خودش هنوز در آن ثبت‌نام نکرده (مثلاً سوال تریدینگ یا شاپیفای بپرسد در حالی که فقط در دوره دیگر ثبت‌نام کرده)، **پاسخ عمیق و آموزش کامل ندهید**. فقط یک توضیح بسیار کوتاه و خلاصه بدهید و محترمانه بگویید برای دسترسی به آموزش کامل و تخصصی این بخش، باید در دوره مربوطه در سافی آکادمی ثبت‌نام کند.

3. **سوالات عمومی درباره آکادمی، دوره‌ها و اساتید**:
   اگر کاربر پرسید چه دوره‌هایی وجود دارد، اساتید کیستند یا چطور ثبت‌نام کند، بر اساس لیست دوره‌ها و اساتید آکادمی، آنها را با گرمی و دقت تشریح کنید و به ثبت‌نام راهنمایی کنید.

4. **سوالات کاملاً غیرمرتبط با آکادمی و آموزش (خارج از موضوع)**:
   اگر کاربر سوالی غیرمرتبط با برنامه‌نویسی، ترید، شاپیفای، کسب‌وکار، دروس آکادمی یا امور آموزشی پرسید (مثلاً آشپزی، اخبار سیاسی، سرگرمی متفرقه)، حتماً و محترمانه بفرمایید:
   "من دستیار هوشمند اختصاصی سافی آکادمی هستم و تنها امکان پاسخگویی به سوالات آموزشی، دوره‌ها و دروس آکادمی را دارم. چطور می‌توانم در زمینه دروس یا ثبت‌نام دوره‌ها به شما کمک کنم؟"

لحن پاسخگویی: صمیمی، حرفه‌ای، تشویق‌کننده و با زبان فارسی/دری روان.
''';
  }

  /// ارسال درخواست به AI و دریافت پاسخ
  Future<String> generateResponse({
    required String studentId,
    required String userPrompt,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final key = _apiKey;
    if (key.isEmpty) {
      return "⚠️ کلید Gemini API یافت نشد. لطفاً فایل .env را بررسی نمایید.";
    }

    // 1. استخراج اطلاعات دانش‌آموز از دیتابیس
    final context = await fetchStudentContext(studentId);
    final systemPrompt = _buildSystemPrompt(context);

    // 2. ساخت پرامپت محتوا برای Gemini API
    final List<Map<String, dynamic>> contents = [];

    // اضافه کردن تاریخچه کوتاه
    for (var msg in conversationHistory) {
      contents.add({
        "role": msg['role'] == 'user' ? 'user' : 'model',
        "parts": [
          {"text": msg['content']}
        ]
      });
    }

    // پرامپت فعلی کاربر
    contents.add({
      "role": "user",
      "parts": [
        {"text": userPrompt}
      ]
    });

    final requestBody = jsonEncode({
      "system_instruction": {
        "parts": [
          {"text": systemPrompt}
        ]
      },
      "contents": contents,
      "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 1500,
      }
    });

    // 3. فراخوانی API
    final endpoints = [
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key",
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key",
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$key",
    ];

    String aiText = "";

    for (var endpoint in endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {"Content-Type": "application/json"},
          body: requestBody,
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              aiText = parts[0]['text'] ?? "";
              if (aiText.isNotEmpty) break;
            }
          }
        } else {
          debugPrint("Gemini Endpoint ($endpoint) Error Status: ${response.statusCode} Body: ${response.body}");
        }
      } catch (e) {
        debugPrint("Gemini Endpoint Call Exception: $e");
      }
    }

    if (aiText.isEmpty) {
      aiText = "متأسفانه مشکلی در ارتباط با هوش مصنوعی رخ داد. لطفاً دوباره تلاش کنید.";
    }

    return aiText;
  }
}
