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
    final key =
        dotenv.env['GOOGLE_GEMINI_API_KEY'] ??
        dotenv.env['GEMINI_API_KEY'] ??
        '';
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
        if (item['class_groups'] != null &&
            item['class_groups']['class_name'] != null) {
          enrolledClassGroups.add(
            item['class_groups']['class_name'].toString(),
          );
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
          availableAcademyCourses.add(
            "$title ${instructor.isNotEmpty ? "(مدرس: $instructor)" : ""}",
          );
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
        : "هیچ دوره‌ای";

    final enrolledClassesStr = ctx.enrolledClassGroups.isNotEmpty
        ? ctx.enrolledClassGroups.join("، ")
        : "هیچ کلاسی";

    final availableCoursesStr = ctx.availableAcademyCourses.isNotEmpty
        ? ctx.availableAcademyCourses.map((c) => "- $c").join("\n")
        : "دوره‌های فعال آکادمی";

    final availableTeachersStr = ctx.availableTeachers.isNotEmpty
        ? ctx.availableTeachers.join("، ")
        : "اساتید مجرب آکادمی سافی";

    return '''
شما دستیار هوش مصنوعی اختصاصی و رسمی آکادمی آموزش عالی "سافی آکادمی" (Safi Academy) هستید. شما باید به شدت و بدون استثنا قوانین زیر را رعایت کنید:

اطلاعات کاربر فعلی (${ctx.studentName}):
- دوره‌های ثبت‌نام شده کاربر: $enrolledCoursesStr
- کلاس‌های زنده فعلی کاربر: $enrolledClassesStr

کاتالوگ کامل دوره‌های آکادمی سافی:
$availableCoursesStr

لیست اساتید آکادمی سافی:
$availableTeachersStr

قوانین حیاتی پاسخ‌دهی (سیاست دسترسی محتوا):
1. **فقط سوالات مربوط به دوره‌های ثبت‌نام شده کاربر**:
   شما مجاز هستید به سوالات علمی، فنی، تخصصی، تمرین‌ها، نوشتن کد و جزئیات عمیق فقط و فقط برای دوره‌هایی پاسخ دهید که کاربر در آنها ثبت‌نام کرده است (یعنی: $enrolledCoursesStr).
   - برای مثال، اگر کاربر در دوره پایتون ثبت‌نام کرده و سوالی درباره پایتون بپرسد، پاسخ کامل، عمیق و فنی همراه با کد ارائه دهید.

2. **عدم پاسخ‌دهی تخصصی به دوره‌های ثبت‌نام نشده**:
   اگر کاربر سوال تخصصی یا فنی (مانند نوشتن کد، تحلیل ترید، تنظیمات شاپیفای و غیره) درباره دوره‌هایی بپرسد که در آنها ثبت‌نام نکرده است:
   - به هیچ وجه پاسخ عمیق، فنی یا آموزشی ندهید.
   - فقط یک توضیح بسیار خلاصه، کلی و سطحی (در حد معرفی ابتدایی) بدهید تا کاربر ترغیب شود.
   - صراحتاً و محترمانه اعلام کنید: "برای دسترسی به آموزش‌های تخصصی، کدنویسی، پاسخ‌های عمیق و پشتیبانی علمی این دوره، باید ابتدا در دوره مربوطه در سافی آکادمی ثبت‌نام کنید."

3. **محدودیت مطلق به دامنه آکادمی (عدم پاسخ به سوالات عمومی و متفرقه)**:
   شما اجازه ندارید به عنوان یک هوش مصنوعی عمومی کار کنید. هر سوالی که خارج از مباحث آموزشی دوره‌های سافی آکادمی باشد (مانند سوالات آشپزی، اخبار، بیوگرافی افراد غیرمرتبط، سرگرمی، اطلاعات عمومی جهان و غیره) را باید قاطعانه و محترمانه رد کنید.
   - پاسخ شما در این حالت باید دقیقاً اینگونه باشد:
   "من دستیار هوشمند اختصاصی سافی آکادمی هستم و تنها امکان پاسخگویی به سوالات مرتبط با دوره‌ها و دروس آکادمی را دارم. چطور می‌توانم در زمینه دروس ثبت‌نام شده یا معرفی دوره‌های آکادمی به شما کمک کنم؟"

4. **لحن و زبان**:
   پاسخ‌های خود را با لحنی صمیمی، دلسوزانه و حرفه‌ای بنویسید. زبان پاسخ شما باید دقیقاً و بدون استثنا همان زبانی باشد که کاربر پیام خود را ارسال کرده است (اگر کاربر به انگلیسی پرسید به انگلیسی، اگر به فارسی/دری پرسید به فارسی/دری، و به همین ترتیب برای هر زبان دیگری). حتماً از زبان کاربر پیروی کنید تا دستیار زبان‌های مختلف را پشتیبانی کند.
   Write your responses in a friendly, compassionate, and professional tone. The language of your response MUST match the language of the user's prompt (if they ask in English, reply in English; if in Persian/Dari, reply in Persian/Dari; if in Pashto, reply in Pashto, etc.). You must follow the user's language choice.
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
          {"text": msg['content']},
        ],
      });
    }

    // پرامپت فعلی کاربر
    contents.add({
      "role": "user",
      "parts": [
        {"text": userPrompt},
      ],
    });

    final requestBody = jsonEncode({
      "systemInstruction": {
        "parts": [
          {"text": systemPrompt},
        ],
      },
      "contents": contents,
      "generationConfig": {"temperature": 0.7, "maxOutputTokens": 1500},
    });

    // 3. فراخوانی API با مدل‌های جدید و استاندارد
    final endpoints = [
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$key",
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$key",
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$key",
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$key",
    ];

    String aiText = "";
    List<String> errorDetails = [];

    for (var endpoint in endpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {"Content-Type": "application/json"},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 25));

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
          final errBody = response.body;
          final modelName = Uri.parse(
            endpoint,
          ).pathSegments.reversed.skip(1).first;
          errorDetails.add("$modelName: HTTP ${response.statusCode}");
          debugPrint(
            "Gemini Endpoint ($endpoint) Error Status: ${response.statusCode} Body: $errBody",
          );
        }
      } catch (e) {
        errorDetails.add("Exception: $e");
        debugPrint("Gemini Endpoint Call Exception: $e");
      }
    }

    if (aiText.isEmpty) {
      aiText = "سیستم قط است لطفا بعدا تلاش کنید";
    }

    return aiText;
  }

  /// تولید صدا با استفاده از قابلیت‌های متنی به صدای Gemini (TTS)
  /// این تابع یا از مدل‌های اختصاصی TTS استفاده می‌کند یا از API تعاملی interactions
  Future<String?> generateSpeech(String text, {String voice = 'Kore'}) async {
    final key = _apiKey;
    if (key.isEmpty) {
      debugPrint("Gemini TTS Error: API key is empty.");
      return null;
    }

    // پاکسازی متن از کاراکترها و فرمت‌های مارک‌داون مزاحم برای خروجی صوتی روان‌تر
    final cleanText = text
        .replaceAll(RegExp(r'\*\*?'), '') // حذف ستاره‌ها
        .replaceAll(RegExp(r'#+'), '') // حذف هش‌های هدر
        .replaceAll(RegExp(r'`'), '') // حذف بک‌تیک‌ها
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // حذف لینک‌ها
        .trim();

    if (cleanText.isEmpty) return null;

    // ۱. متد اول: فراخوانی مستقیم مدل gemini-3.1-flash-tts-preview با responseModalities
    final generateContentUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-tts-preview:generateContent?key=$key";
    try {
      final response = await http
          .post(
            Uri.parse(generateContentUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": cleanText},
                  ],
                },
              ],
              "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                  "voiceConfig": {
                    "prebuiltVoiceConfig": {"voiceName": voice},
                  },
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final inlineData = parts[0]['inlineData'];
            if (inlineData != null && inlineData['data'] != null) {
              return inlineData['data'].toString();
            }
          }
        }
      }
      debugPrint(
        "TTS Model API returned HTTP ${response.statusCode}: ${response.body}",
      );
    } catch (e) {
      debugPrint("TTS Model generateContent Call Exception: $e");
    }

    // ۲. متد دوم (بک‌آپ): فراخوانی endpoint بتا interactions مطابق با راهنمای کاربر
    final interactionsUrl =
        "https://generativelanguage.googleapis.com/v1beta/interactions?key=$key";
    try {
      final response = await http
          .post(
            Uri.parse(interactionsUrl),
            headers: {
              "Content-Type": "application/json",
              "Api-Revision": "2026-05-20",
            },
            body: jsonEncode({
              "model": "gemini-3.1-flash-tts-preview",
              "input": cleanText,
              "response_format": {"type": "audio"},
              "generation_config": {
                "speech_config": [
                  {"voice": voice},
                ],
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['interaction'] != null &&
            data['interaction']['output_audio'] != null) {
          return data['interaction']['output_audio'].toString();
        } else if (data['outputAudio'] != null) {
          return data['outputAudio'].toString();
        } else if (data['audioContent'] != null) {
          return data['audioContent'].toString();
        }
      }
      debugPrint(
        "TTS Interactions API returned HTTP ${response.statusCode}: ${response.body}",
      );
    } catch (e) {
      debugPrint("TTS Interactions API Call Exception: $e");
    }

    // ۳. متد سوم (بک‌آپ نهایی): مدل دیگر gemini-2.5-flash-preview-tts
    final backupTtsUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$key";
    try {
      final response = await http
          .post(
            Uri.parse(backupTtsUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": cleanText},
                  ],
                },
              ],
              "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                  "voiceConfig": {
                    "prebuiltVoiceConfig": {"voiceName": voice},
                  },
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final inlineData = parts[0]['inlineData'];
            if (inlineData != null && inlineData['data'] != null) {
              return inlineData['data'].toString();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Backup TTS Model generateContent Exception: $e");
    }

    return null;
  }
}
