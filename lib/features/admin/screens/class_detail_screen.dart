import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart'; // Required for firstWhereOrNull
import 'add_student_to_class_screen.dart'; // در ادامه این صفحه را هم می‌سازیم

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
          .eq("class_group_id", widget.classId) // Fix: Use named argument for ascending
          .order('created_at', ascending: false);

      if ((classStudents as List).isNotEmpty) {
        List studentIds = classStudents.map((cs) => cs['student_id']).toList();
        final profiles = await supabase
            .from("profiles")
            .select("id, first_name, last_name, email, avatar_url")
            .inFilter("id", studentIds);

        List<Map<String, dynamic>> formattedStudents = [];
        for (var profile in (profiles as List)) { // Keep original cast for minimal diff, though `for (var profile in profiles)` would be better.
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
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING CLASS INFO...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (classData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Cohort Not Found", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              physics: const BouncingScrollPhysics(),
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
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                          SizedBox(width: 6),
                          Text("Back to Cohorts", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Info Card
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(classData!['class_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(classData!['course']?['title'] ?? 'General Course', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _buildMiniStat("Enrolled", students.length.toString(), Icons.group)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMiniStat("Status", classData!['is_active'] == true ? "Live" : "Done", Icons.radio)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Roster Header & Enroll Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("STUDENT ROSTER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text("Enroll Student", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddStudentToClassScreen(classId: widget.classId)),
                          ).then((_) => _fetchClassDetails());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Students List
                  students.isEmpty
                      ? Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, child: const Text("No students enrolled yet.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = students[index];
                            bool isPaid = s['is_paid'];
                            return _buildGlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.black,
                                    backgroundImage: s['avatar_url'] != null ? NetworkImage(s['avatar_url']) : null,
                                    child: s['avatar_url'] == null ? Text(s['first_name'][0], style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${s['first_name']} ${s['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text(s['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => togglePayment(s['id'], isPaid),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isPaid ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isPaid ? Colors.green.withOpacity(0.3) : Colors.amber.withOpacity(0.3)),
                                      ),
                                      child: Text(isPaid ? "PAID" : "PENDING", style: TextStyle(color: isPaid ? Colors.greenAccent : Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900)),
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
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}