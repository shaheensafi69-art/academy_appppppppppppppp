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
          students = finalStudentsList ?? [];
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING COURSE DETAILS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (course == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Course not found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    double price = (course!['price'] ?? 0).toDouble();
    final teacher = course!['teacher'];

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: textDark, size: 14),
                    SizedBox(width: 6),
                    Text("Back to Library", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Course Banner Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
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
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (course!['category'] ?? 'COURSE').toString().toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      Text(
                        price > 0 ? "\$${price.toStringAsFixed(2)}" : "FREE",
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(course!['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark)),
                  const SizedBox(height: 6),
                  Text(course!['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 18),
                  
                  // Instructor Info if available
                  if (teacher != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: lightPinkBg,
                          backgroundImage: teacher['avatar_url'] != null ? NetworkImage(teacher['avatar_url']) : null,
                          child: teacher['avatar_url'] == null ? const Text("T", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                        ),
                        const SizedBox(width: 8),
                        Text("Instructor: ${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}", style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  Row(
                    children: [
                      Expanded(child: _buildMiniStat("Enrolled Students", students.length.toString(), Icons.group_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStat("Language", course!['language'] ?? 'English', Icons.language_rounded)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("ENROLLED COHORT ROSTER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
            const SizedBox(height: 12),

            students.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No students enrolled in this course yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = students[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: lightPinkBg,
                              backgroundImage: s['avatar_url'] != null ? NetworkImage(s['avatar_url']) : null,
                              child: s['avatar_url'] == null ? Text(s['first_name'][0], style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 12)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${s['first_name']} ${s['last_name']}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(s['email'], style: const TextStyle(color: textGrey, fontSize: 10)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(s['status'], style: TextStyle(color: Colors.green.shade700, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}