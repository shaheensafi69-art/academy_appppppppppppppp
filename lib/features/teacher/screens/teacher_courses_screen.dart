import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_class_screen.dart';
import 'teacher_create_course_screen.dart';
import 'teacher_class_students_screen.dart';
import 'teacher_add_student_screen.dart';

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

      if (classesData != null) {
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
      }
    } catch (e) {
      debugPrint("DB Sync Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر صفحه
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.pink.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Text("📚", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Class Scheduler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        SizedBox(height: 2),
                        Text("Manage class timings and cohort enrollment.", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateClassScreen()))
                              .then((_) => _fetchActiveClasses());
                        },
                        child: const Text("Create Class", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateCourseScreen()));
                        },
                        child: const Text("Create Course", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text("Active Cohorts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : classGroups.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: classGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cls = classGroups[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.pink.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text(cls.category, style: const TextStyle(color: Colors.pinkAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: cls.isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text(cls.isActive ? "Active" : "Standby", style: TextStyle(color: cls.isActive ? Colors.greenAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(cls.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text("📅 ${cls.classDays} | 🕒 ${cls.classTime}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("👥 ${cls.studentCount} Students Enrolled", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherAddStudentScreen(classId: cls.id)));
                                        },
                                        child: const Text("+ Add Student", style: TextStyle(color: Colors.pinkAccent, fontSize: 10)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherClassStudentsScreen(classId: cls.id)));
                                        },
                                        child: const Text("Manage", style: TextStyle(color: Colors.white, fontSize: 10)),
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
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text("No active classroom schedules found.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}