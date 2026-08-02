import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'add_student_to_class_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;
  const ClassDetailScreen({super.key, required this.classId});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  Map<String, dynamic>? classData;
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
    _fetchClassDetails();
  }

  Future<void> _fetchClassDetails() async {
    setState(() => isLoading = true);
    try {
      final clsData = await supabase
          .from("class_groups")
          .select("*, course:courses(title), teacher:profiles!teacher_id(id, first_name, last_name, email, avatar_url)")
          .eq("id", widget.classId)
          .single();

      final teacherObj = clsData['teacher'];
      final courseObj = clsData['course'];

      Map<String, dynamic>? formattedTeacher = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;
      Map<String, dynamic>? formattedCourse = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;

      classData = {
        ...clsData,
        'teacher': formattedTeacher,
        'course': formattedCourse,
        'schedule_time': clsData['schedule_time'] ?? '18:00 PM - 20:00 PM',
        'schedule_days': clsData['schedule_days'] ?? 'Monday, Wednesday, Friday',
      };

      final classStudents = await supabase
          .from("class_students")
          .select("student_id, created_at, is_paid")
          .eq("class_group_id", widget.classId)
          .order('created_at', ascending: false);

      if ((classStudents as List).isNotEmpty) {
        List studentIds = classStudents.map((cs) => cs['student_id']).toList();
        final profiles = await supabase
            .from("profiles")
            .select("id, first_name, last_name, email, avatar_url")
            .inFilter("id", studentIds);

        List<Map<String, dynamic>> formattedStudents = [];
        for (var profile in (profiles as List)) {
          final joinedData = classStudents.firstWhereOrNull((cs) => cs['student_id'] == profile['id']);
          formattedStudents.add({
            ...profile,
            'joined_at': joinedData?['created_at'] ?? DateTime.now().toIso8601String(),
            'is_paid': joinedData?['is_paid'] ?? false,
          });
        }

        formattedStudents.sort((a, b) => (a['is_paid'] == b['is_paid']) ? 0 : (a['is_paid'] ? 1 : -1));
        students = formattedStudents;
      } else {
        students = [];
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error fetching class details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> togglePayment(String studentId, bool currentStatus) async {
    try {
      bool newStatus = !currentStatus;
      await supabase
          .from("class_students")
          .update({'is_paid': newStatus})
          .eq("class_group_id", widget.classId)
          .eq("student_id", studentId);

      setState(() {
        students = students.map((s) {
          if (s['id'] == studentId) s['is_paid'] = newStatus;
          return s;
        }).toList();
      });
    } catch (e) {
      debugPrint("Failed to update status: $e");
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
              Text("LOADING CLASS INFO...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (classData == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Cohort Not Found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
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
                    Text("Back to Cohorts", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Info Card
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
                  Text(classData!['class_name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(classData!['course']?['title'] ?? 'General Course', style: const TextStyle(color: primaryPink, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat("Enrolled", students.length.toString(), Icons.group_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStat("Status", classData!['is_active'] == true ? "Live" : "Done", Icons.radio_button_checked_rounded)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Roster Header & Enroll Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("STUDENT ROSTER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text("Enroll Student", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddStudentToClassScreen(classId: widget.classId)),
                    ).then((_) => _fetchClassDetails());
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Students List
            students.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No students enrolled yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = students[index];
                      bool isPaid = s['is_paid'];
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
                            GestureDetector(
                              onTap: () => togglePayment(s['id'], isPaid),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isPaid ? Colors.green.withOpacity(0.12) : lightPinkBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPaid ? Colors.green.withOpacity(0.3) : primaryPink.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  isPaid ? "PAID" : "PENDING",
                                  style: TextStyle(
                                    color: isPaid ? Colors.green.shade700 : primaryPink,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
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
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}