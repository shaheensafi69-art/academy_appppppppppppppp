import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseDetailScreen({super.key, required this.courseId, required this.courseTitle});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? courseData;
  List<Map<String, dynamic>> classGroups = [];
  List<Map<String, dynamic>> enrolledStudents = [];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchCompleteCourseData();
  }

  Future<void> _fetchCompleteCourseData() async {
    setState(() => isLoading = true);
    try {
      // ۱. واکشی اطلاعات کامل دوره
      final courseRes = await supabase
          .from("courses")
          .select("*")
          .eq("id", widget.courseId)
          .maybeSingle();

      // ۲. واکشی گروه‌های کلاسی مرتبط با این دوره (از جدول class_groups)
      final classesRes = await supabase
          .from("class_groups")
          .select("id, class_name, schedule_info, is_active, start_date")
          .eq("course_id", widget.courseId);

      List<Map<String, dynamic>> fetchedClasses = List<Map<String, dynamic>>.from(classesRes);

      // ۳. برای هر گروه کلاسی، دانشجویان داخل جدول class_students را به صورت جداگانه واکشی می‌کنیم تا پالیسی‌های RLS تداخل ایجاد نکنند
      for (var cls in fetchedClasses) {
        try {
          final studentsRes = await supabase
              .from("class_students")
              .select("student_id, profiles(first_name, last_name, email, avatar_url)")
              .eq("class_group_id", cls['id']);
          cls['students_list'] = studentsRes;
        } catch (e) {
          debugPrint("Error fetching class students for group ${cls['id']}: $e");
          cls['students_list'] = [];
        }
      }

      // ۴. واکشی دانشجویان ثبت‌نام شده از جدول enrollments
      final enrollmentsRes = await supabase
          .from("enrollments")
          .select("id, progress_percentage, enrolled_at, student_id, profiles(first_name, last_name, email, avatar_url)")
          .eq("course_id", widget.courseId);

      setState(() {
        courseData = courseRes;
        classGroups = fetchedClasses;
        enrolledStudents = List<Map<String, dynamic>>.from(enrollmentsRes);
      });
    } catch (e) {
      debugPrint("Error fetching complete course data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        title: Text(widget.courseTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
        iconTheme: const IconThemeData(color: primaryPink),
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
                      // ================= هدر اطلاعات دوره =================
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                  child: Text((courseData?['category'] ?? 'GENERAL').toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                                Text("\$${(courseData?['price'] ?? 0).toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(courseData?['title'] ?? widget.courseTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 6),
                            Text(courseData?['description'] ?? 'No description provided for this course.', style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4)),
                            const SizedBox(height: 16),
                            const Divider(color: cardBorder),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Language: ${courseData?['language'] ?? 'English'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text("Status: ${courseData?['is_published'] == true ? 'Published ✅' : 'Draft 📌'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= بخش کلاس‌ها و کوهورت‌ها (Class Groups & Students) =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Associated Class Groups & Students", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                            child: Text("${classGroups.length} Groups", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      classGroups.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: classGroups.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final group = classGroups[index];
                                final studentsList = group['students_list'] as List? ?? [];
                                final isActive = group['is_active'] ?? false;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isActive ? primaryPink : cardBorder, width: isActive ? 1.5 : 1),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(group['class_name'] ?? 'Class Group', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                            child: Text(isActive ? "● Active" : "○ Standby", style: TextStyle(color: isActive ? Colors.green.shade700 : textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text("Schedule: ${group['schedule_info'] ?? 'Not set'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 12),
                                      const Divider(color: cardBorder),
                                      const SizedBox(height: 8),
                                      Text("Students in this group (${studentsList.length}):", style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 11)),
                                      const SizedBox(height: 8),
                                      studentsList.isNotEmpty
                                          ? ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: studentsList.length,
                                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                                              itemBuilder: (context, sIndex) {
                                                final studentEntry = studentsList[sIndex];
                                                final profile = studentEntry['profiles'] as Map<String, dynamic>?;
                                                final sName = profile != null ? "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim() : "Student";
                                                final sEmail = profile?['email'] ?? '';
                                                final sAvatar = profile?['avatar_url'];

                                                return Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: lightPinkBg,
                                                      backgroundImage: sAvatar != null && sAvatar.isNotEmpty ? NetworkImage(sAvatar) : null,
                                                      child: sAvatar == null || sAvatar.isEmpty ? const Icon(Icons.person, color: primaryPink, size: 12) : null,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(sName.isNotEmpty ? sName : "Student", style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                                                    ),
                                                    Text(sEmail, style: const TextStyle(color: textGrey, fontSize: 9)),
                                                  ],
                                                );
                                              },
                                            )
                                          : const Text("No students in this group yet.", style: TextStyle(color: textGrey, fontSize: 10)),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: surfaceWhite, borderRadius: BorderRadius.circular(18), border: Border.all(color: cardBorder)),
                              child: const Text("No class groups assigned to this course yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                      const SizedBox(height: 24),

                      // ================= لیست کل دانشجویان ثبت‌نام‌شده در دوره (Enrollments) =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("All Enrolled Students (Enrollments)", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                            child: Text("${enrolledStudents.length} Students", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      enrolledStudents.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: enrolledStudents.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final enrollment = enrolledStudents[index];
                                final profile = enrollment['profiles'] as Map<String, dynamic>?;
                                final studentName = profile != null ? "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim() : "Student";
                                final studentEmail = profile?['email'] ?? 'No email';
                                final avatarUrl = profile?['avatar_url'];
                                final progress = enrollment['progress_percentage'] ?? 0;

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: cardBorder, width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: lightPinkBg,
                                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: primaryPink, size: 18) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(studentName.isNotEmpty ? studentName : "Enrolled Student", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(studentEmail, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text("$progress% Done", style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(30),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder),
                              ),
                              child: const Text("No students enrolled in this course yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}