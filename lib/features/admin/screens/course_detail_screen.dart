import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  Map<String, dynamic>? course;
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    _fetchCourseData();
  }

  Future<void> _fetchCourseData() async {
    setState(() => isLoading = true);
    try {
      final courseData = await supabase
          .from("courses")
          .select("*, teacher:profiles!teacher_id(id, first_name, last_name, email, avatar_url)")
          .eq("id", widget.courseId)
          .single();

      final teacherObj = courseData['teacher'];
      Map<String, dynamic>? formattedTeacher = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;

      // یافتن کلاس‌های مرتبط و دانشجویان
      final classesData = await supabase.from("class_groups").select("id").eq("course_id", widget.courseId);

      List<Map<String, dynamic>>? finalStudentsList = [];
      if ((classesData as List).isNotEmpty) {
        List classIds = classesData.map((c) => c['id']).toList();
        final classStudents = await supabase.from("class_students").select("student_id, created_at").inFilter("class_group_id", classIds);

        if ((classStudents as List).isNotEmpty) {
          Map<String, String> uniqueMap = {};
          for (var cs in (classStudents as List)) {
            uniqueMap[cs['student_id']] = cs['created_at'];
          }

          final profiles = await supabase.from("profiles").select("id, first_name, last_name, email, avatar_url").inFilter("id", uniqueMap.keys.toList());

          finalStudentsList = (profiles as List).map((p) => {
            ...p,
            'enrolled_at': uniqueMap[p['id']] ?? DateTime.now().toIso8601String(),
            'status': 'Active',
          }).cast<Map<String, dynamic>>().toList();
                }
      }

      if (mounted) {
        setState(() {
          course = {
            ...courseData,
            'teacher': formattedTeacher,
          };
          students = finalStudentsList!;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching course details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2.5),
        ),
      );
    }

    if (course == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(child: Text("Course not found", style: TextStyle(color: Colors.white))),
      );
    }

    double price = (course!['price'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text("Back to Library", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Course Banner Card
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
                    Text(course!['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(course!['description'] ?? 'No description', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // ignore: unnecessary_brace_in_string_interps
                        Text(price > 0 ? "\$${price}" : "Free", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 10),
                        Text("Enrolled Students: ${students.length}", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("ENROLLED COHORT ROSTER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 10),

              students.isEmpty
                  ? Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, child: const Text("No students enrolled.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final s = students[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black,
                                backgroundImage: s['avatar_url'] != null ? NetworkImage(s['avatar_url']) : null,
                                child: s['avatar_url'] == null ? Text(s['first_name'][0], style: TextStyle(color: Colors.purpleAccent, fontSize: 10)) : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${s['first_name']} ${s['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text(s['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}