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

  /// واکشی اطلاعات کامل کلاس، دوره، استاد، جدول class_students و جدول enrollments
  Future<void> _fetchClassDetails() async {
    setState(() => isLoading = true);
    try {
      // 1. دریافت اطلاعات گروه کلاسی همراه با دوره و استاد
      final clsData = await supabase
          .from("class_groups")
          .select("*, course:courses(id, title, price, category), teacher:profiles!teacher_id(id, first_name, last_name, email, avatar_url)")
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
        'schedule_time': clsData['class_time'] ?? clsData['schedule_info'] ?? '18:00 - 20:00',
        'schedule_days': clsData['schedule_days'] ?? 'Saturday, Monday, Wednesday',
      };

      // 2. دریافت لیست دانشجویان این کلاس از جدول class_students
      final classStudents = await supabase
          .from("class_students")
          .select("student_id, joined_at, is_paid")
          .eq("class_group_id", widget.classId)
          .order('joined_at', ascending: false);

      if ((classStudents as List).isNotEmpty) {
        List studentIds = classStudents.map((cs) => cs['student_id']).toList();
        
        // 3. دریافت اطلاعات پروفایل دانشجویان از جدول profiles
        final profiles = await supabase
            .from("profiles")
            .select("id, first_name, last_name, email, avatar_url, total_score, wallet_balance")
            .inFilter("id", studentIds);

        // 4. دریافت وضعیت جدول enrollments برای این دانشجویان و این دوره
        List<Map<String, dynamic>> enrollmentsList = [];
        if (formattedCourse != null && formattedCourse['id'] != null) {
          final enRes = await supabase
              .from("enrollments")
              .select("student_id, progress_percentage, enrolled_at")
              .eq("course_id", formattedCourse['id'])
              .inFilter("student_id", studentIds);
          enrollmentsList = (enRes as List?)?.cast<Map<String, dynamic>>() ?? [];
        }

        List<Map<String, dynamic>> formattedStudents = [];
        for (var profile in (profiles as List)) {
          final joinedData = classStudents.firstWhereOrNull((cs) => cs['student_id'] == profile['id']);
          final enrollData = enrollmentsList.firstWhereOrNull((en) => en['student_id'] == profile['id']);

          formattedStudents.add({
            ...profile,
            'joined_at': joinedData?['joined_at'] ?? DateTime.now().toIso8601String(),
            'is_paid': joinedData?['is_paid'] ?? false,
            'progress_percentage': enrollData?['progress_percentage'] ?? 0,
          });
        }

        // مرتب‌سازی بر اساس وضعیت پرداخت
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

  /// تغییر وضعیت پرداخت شهریه در جدول class_students
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
      debugPrint("Failed to update payment status: $e");
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
              Text("LOADING COHORT DETAILS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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

    final teacher = classData!['teacher'];
    final course = classData!['course'];

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
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

                // Header Info Card (ریسپانسیو و فیکس شده برای جلوگیری از اورفلو)
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
                              classData!['is_active'] == true ? "ACTIVE COHORT" : "ARCHIVED",
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                            ),
                          ),
                          Icon(
                            classData!['is_active'] == true ? Icons.verified_rounded : Icons.history_rounded,
                            color: classData!['is_active'] == true ? Colors.green.shade700 : textGrey,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(classData!['class_name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(course?['title'] ?? 'General Academic Program', style: const TextStyle(color: primaryPink, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      if (teacher != null) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: lightPinkBg,
                              backgroundImage: teacher['avatar_url'] != null ? NetworkImage(teacher['avatar_url']) : null,
                              child: teacher['avatar_url'] == null ? Text(teacher['first_name'][0], style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Instructor: ${teacher['first_name']} ${teacher['last_name']}",
                                style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWide = constraints.maxWidth > 450;
                          return Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            children: [
                              Expanded(flex: isWide ? 1 : 0, child: _buildMiniStat("Enrolled Students", students.length.toString(), Icons.group_rounded)),
                              SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                              Expanded(flex: isWide ? 1 : 0, child: _buildMiniStat("Class Schedule", classData!['schedule_time'], Icons.access_time_rounded)),
                            ],
                          );
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Roster Header & Enroll Button (حل مشکل اورفلو با استفاده از Wrap)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "STUDENT ROSTER & ENROLLMENTS",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 16),
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
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1.5),
                        ),
                        child: const Text("No students enrolled in this cohort yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final s = students[index];
                          bool isPaid = s['is_paid'];
                          int progress = s['progress_percentage'] ?? 0;

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
                                  child: s['avatar_url'] == null ? Text(s['first_name'] != null ? s['first_name'][0] : 'S', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 12)) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${s['first_name'] ?? ''} ${s['last_name'] ?? ''}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text("${s['email'] ?? ''} • Progress: $progress%", style: const TextStyle(color: textGrey, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => togglePayment(s['id'], isPaid),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isPaid ? Colors.green.withOpacity(0.12) : lightPinkBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isPaid ? Colors.green.withOpacity(0.3) : primaryPink.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      isPaid ? "PAID" : "PENDING",
                                      style: TextStyle(
                                        color: isPaid ? Colors.green.shade700 : primaryPink,
                                        fontSize: 10,
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
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}