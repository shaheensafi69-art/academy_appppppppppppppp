import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_class_screen.dart';
import 'teacher_create_course_screen.dart';
import 'teacher_class_students_screen.dart';
import 'teacher_add_student_screen.dart';
import 'teacher_courses_curriculum_screen.dart'; // 👈 ایمپورت صفحه مدیریت دوره‌ها

class ClassGroupItem {
  final String id;
  final String className;
  final String classDays;
  final String classTime;
  final bool isActive;
  final int studentCount;
  final String? thumbnailUrl;
  final String category;

  ClassGroupItem({
    required this.id,
    required this.className,
    required this.classDays,
    required this.classTime,
    required this.isActive,
    required this.studentCount,
    this.thumbnailUrl,
    required this.category,
  });
}

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ClassGroupItem> classGroups = [];

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchActiveClasses();
  }

  Future<void> _fetchActiveClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final classesData = await supabase
          .from("class_groups")
          .select("id, class_name, class_days, class_time, is_active, class_students(student_id), courses(thumbnail_url, category)")
          .eq("teacher_id", user.id)
          .order("created_at", ascending: false);

      classGroups = (classesData as List).map((cls) {
        final courseObj = cls['courses'];
        final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;
        final students = cls['class_students'] as List?;

        return ClassGroupItem(
          id: cls['id'] ?? '',
          className: cls['class_name'] ?? '',
          classDays: cls['class_days'] ?? 'Not Set',
          classTime: cls['class_time'] ?? 'Not Set',
          isActive: cls['is_active'] ?? false,
          studentCount: students != null ? students.length : 0,
          thumbnailUrl: courseData?['thumbnail_url'],
          category: courseData?['category'] ?? 'Academy Cohort',
        );
      }).toList();
        } catch (e) {
      debugPrint("DB Sync Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.class_rounded, color: primaryPink, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Class Scheduler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Manage class timings and cohort enrollment.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // دکمه‌های عملیاتی کامل
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textDark,
                          side: const BorderSide(color: cardBorder, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateClassScreen()))
                              .then((_) => _fetchActiveClasses());
                        },
                        child: const Text("Create Class", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateCourseScreen()))
                              .then((_) => _fetchActiveClasses());
                        },
                        child: const Text("Create Course", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // دکمه میانبر برای رفتن به صفحه مدیریت لیست دوره‌ها (Curriculum)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: primaryPink),
                    icon: const Icon(Icons.library_books_rounded, size: 16),
                    label: const Text("View All Courses Curriculum ➔", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeacherCoursesCurriculumScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text("Active Cohorts", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 12),

          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : classGroups.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: classGroups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final cls = classGroups[index];
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cls.isActive ? primaryPink : cardBorder,
                              width: cls.isActive ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cls.isActive ? primaryPink.withOpacity(0.12) : Colors.black.withOpacity(0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                    child: Text(cls.category.toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cls.isActive ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cls.isActive ? "● Active" : "○ Standby",
                                      style: TextStyle(
                                        color: cls.isActive ? Colors.green.shade700 : textGrey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(cls.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: textGrey),
                                  const SizedBox(width: 6),
                                  Text("${cls.classDays} | ${cls.classTime}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people_alt_rounded, size: 14, color: textGrey),
                                      const SizedBox(width: 5),
                                      Text("${cls.studentCount} Students Enrolled", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: primaryPink),
                                        icon: const Icon(Icons.person_add_rounded, size: 14),
                                        label: const Text("Add", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherAddStudentScreen(classId: cls.id)));
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: textDark),
                                        icon: const Icon(Icons.settings_rounded, size: 14),
                                        label: const Text("Manage", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherClassStudentsScreen(classId: cls.id)));
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 36, color: textGrey),
                          SizedBox(height: 10),
                          Text("No Active Cohorts", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("No active classroom schedules found.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}