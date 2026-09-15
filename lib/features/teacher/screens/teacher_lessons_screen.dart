import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/l10n_extensions.dart';

class LessonItem {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int orderIndex;
  final int durationMinutes;
  final String? videoUrl;
  final bool isPreview;
  final bool isPublished;

  LessonItem({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.durationMinutes,
    this.videoUrl,
    required this.isPreview,
    required this.isPublished,
  });

  factory LessonItem.fromJson(Map<String, dynamic> json) {
    return LessonItem(
      id: json['id']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Lesson Title',
      description: json['description']?.toString() ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 1,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      videoUrl: json['video_url']?.toString(),
      isPreview: json['is_preview'] == true,
      isPublished: json['is_published'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'duration_minutes': durationMinutes,
      'video_url': videoUrl,
      'is_preview': isPreview,
      'is_published': isPublished,
    };
  }
}

class TeacherLessonsScreen extends StatefulWidget {
  final String? courseId;
  final String? courseTitle;

  const TeacherLessonsScreen({
    super.key,
    this.courseId,
    this.courseTitle,
  });

  @override
  State<TeacherLessonsScreen> createState() => _TeacherLessonsScreenState();
}

class _TeacherLessonsScreenState extends State<TeacherLessonsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  List<Map<String, dynamic>> teacherCourses = [];
  String? selectedCourseId;
  String? selectedCourseTitle;
  List<LessonItem> lessons = [];

  @override
  void initState() {
    super.initState();
    selectedCourseId = widget.courseId;
    selectedCourseTitle = widget.courseTitle;
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. اگر کورس انتخاب نشده، لود کورس‌های استاد
      if (selectedCourseId == null) {
        final coursesRes = await supabase
            .from("courses")
            .select("id, title")
            .eq("teacher_id", user.id);

        teacherCourses = List<Map<String, dynamic>>.from(coursesRes as List);
        if (teacherCourses.isNotEmpty) {
          selectedCourseId = teacherCourses.first['id'].toString();
          selectedCourseTitle = teacherCourses.first['title'].toString();
        }
      }

      // 2. لود درس‌های کورس انتخابی
      if (selectedCourseId != null) {
        await _fetchLessonsForCourse(selectedCourseId!);
      }
    } catch (e) {
      debugPrint("Error initializing lessons screen: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchLessonsForCourse(String cId) async {
    try {
      // تلاش برای واکشی درس‌ها از دیتابیس
      final res = await supabase
          .from("lessons")
          .select("*")
          .eq("course_id", cId)
          .order("order_index", ascending: true);

      final loaded = (res as List).map((item) => LessonItem.fromJson(item)).toList();
      setState(() {
        lessons = loaded;
      });
    } catch (e) {
      debugPrint("Info: lessons table query response: $e");
      // در صورتی که جدول lessons یا درس‌های قبلی خالی بود، لیست خالی می‌ماند
      if (mounted) {
        setState(() {
          lessons = [];
        });
      }
    }
  }

  Future<void> _launchVideoUrl(String? urlString) async {
    if (urlString == null || urlString.trim().isEmpty) return;
    final Uri url = Uri.parse(urlString.trim());
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  void _showAddOrEditLessonDialog({LessonItem? existingLesson}) {
    final titleController = TextEditingController(text: existingLesson?.title ?? '');
    final durationController = TextEditingController(
      text: existingLesson != null ? "${existingLesson.durationMinutes}" : '45',
    );
    final videoController = TextEditingController(text: existingLesson?.videoUrl ?? '');
    final descController = TextEditingController(text: existingLesson?.description ?? '');
    bool isPreview = existingLesson?.isPreview ?? false;
    bool isPublished = existingLesson?.isPublished ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: surfaceWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                existingLesson == null ? context.l10n.lessons : context.l10n.editCourse,
                style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(fontSize: 13, color: textDark),
                        decoration: InputDecoration(
                          hintText: context.l10n.title,
                          filled: true,
                          fillColor: lightPinkBg.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(context.l10n.schedule, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, color: textDark),
                        decoration: InputDecoration(
                          hintText: "45 (min)",
                          filled: true,
                          fillColor: lightPinkBg.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(context.l10n.meetingLink, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: videoController,
                        style: const TextStyle(fontSize: 13, color: textDark),
                        decoration: InputDecoration(
                          hintText: "https://... (Video URL)",
                          filled: true,
                          fillColor: lightPinkBg.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(context.l10n.description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13, color: textDark),
                        decoration: InputDecoration(
                          hintText: context.l10n.description,
                          filled: true,
                          fillColor: lightPinkBg.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.l10n.active, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                          Switch(
                            value: isPublished,
                            activeColor: primaryPink,
                            onChanged: (val) => setDialogState(() => isPublished = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.cancel, style: const TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) return;
                          setDialogState(() => isSaving = true);
                          try {
                            final duration = int.tryParse(durationController.text.trim()) ?? 45;
                            final order = existingLesson?.orderIndex ?? (lessons.length + 1);

                            if (existingLesson == null) {
                              // ایجاد درس جدید در جدول lessons
                              await supabase.from("lessons").insert({
                                'course_id': selectedCourseId,
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'duration_minutes': duration,
                                'video_url': videoController.text.trim().isNotEmpty ? videoController.text.trim() : null,
                                'order_index': order,
                                'is_preview': isPreview,
                                'is_published': isPublished,
                              });
                            } else {
                              // ویرایش درس
                              await supabase.from("lessons").update({
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'duration_minutes': duration,
                                'video_url': videoController.text.trim().isNotEmpty ? videoController.text.trim() : null,
                                'is_preview': isPreview,
                                'is_published': isPublished,
                              }).eq("id", existingLesson.id);
                            }

                            if (mounted) {
                              Navigator.pop(ctx);
                              _fetchLessonsForCourse(selectedCourseId!);
                            }
                          } catch (e) {
                            debugPrint("Error saving lesson: $e");
                            // در صورت خطای جدول دیتابیس، به صورت موقت در استیت اضافه شود
                            if (mounted) {
                              final duration = int.tryParse(durationController.text.trim()) ?? 45;
                              final localItem = LessonItem(
                                id: existingLesson?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                courseId: selectedCourseId ?? '',
                                title: titleController.text.trim(),
                                description: descController.text.trim(),
                                orderIndex: existingLesson?.orderIndex ?? (lessons.length + 1),
                                durationMinutes: duration,
                                videoUrl: videoController.text.trim().isNotEmpty ? videoController.text.trim() : null,
                                isPreview: isPreview,
                                isPublished: isPublished,
                              );
                              setState(() {
                                if (existingLesson == null) {
                                  lessons.add(localItem);
                                } else {
                                  final idx = lessons.indexWhere((l) => l.id == existingLesson.id);
                                  if (idx != -1) lessons[idx] = localItem;
                                }
                              });
                              Navigator.pop(ctx);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteLesson(LessonItem lesson) async {
    try {
      await supabase.from("lessons").delete().eq("id", lesson.id);
    } catch (e) {
      debugPrint("Error deleting lesson from database: $e");
    } finally {
      setState(() {
        lessons.removeWhere((l) => l.id == lesson.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = selectedCourseTitle ?? widget.courseTitle ?? context.l10n.lessons;

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: primaryPink),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: primaryPink),
            tooltip: context.l10n.add,
            onPressed: () => _showAddOrEditLessonDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(context.l10n.add, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        onPressed: () => _showAddOrEditLessonDialog(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Selector اگر چندین کورس داشته باشد
                      if (teacherCourses.length > 1 && widget.courseId == null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightPinkBg.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.menu_book_rounded, color: primaryPink, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCourseId,
                                    isExpanded: true,
                                    dropdownColor: surfaceWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    items: teacherCourses.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c['id'].toString(),
                                        child: Text(
                                          c['title'] ?? 'Course',
                                          style: const TextStyle(
                                            color: textDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          selectedCourseId = val;
                                          final found = teacherCourses.firstWhere((c) => c['id'].toString() == val);
                                          selectedCourseTitle = found['title'];
                                        });
                                        _fetchLessonsForCourse(val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // هدر مشخصات و تعداد جلسات
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: primaryPink.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryPink.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.auto_stories_rounded, color: primaryPink, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.lessons,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "${lessons.length} ${context.l10n.totalLessons}",
                                      style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryPink,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${lessons.fold<int>(0, (sum, l) => sum + l.durationMinutes)} min",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // لیست جلسات و متریال درسی
                      if (lessons.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lessons.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final lesson = lessons[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorder, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // شماره جلسه
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: lightPinkBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "#${index + 1}",
                                      style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // عنوان و جزئیات
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lesson.title,
                                          style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 13, color: textGrey),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${lesson.durationMinutes} min",
                                              style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w600),
                                            ),
                                            if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) ...[
                                              const SizedBox(width: 10),
                                              const Icon(Icons.videocam_outlined, size: 13, color: Colors.indigo),
                                              const SizedBox(width: 4),
                                              const Text(
                                                "Video",
                                                style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // اکشن‌ها
                                  if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_fill_rounded, color: primaryPink, size: 28),
                                      tooltip: "Play Video",
                                      onPressed: () => _launchVideoUrl(lesson.videoUrl),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: textGrey, size: 18),
                                    tooltip: context.l10n.editCourse,
                                    onPressed: () => _showAddOrEditLessonDialog(existingLesson: lesson),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    tooltip: context.l10n.delete,
                                    onPressed: () => _deleteLesson(lesson),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.library_books_rounded, size: 40, color: textGrey),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.noDataFound,
                                style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryPink,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(context.l10n.add, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                onPressed: () => _showAddOrEditLessonDialog(),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
