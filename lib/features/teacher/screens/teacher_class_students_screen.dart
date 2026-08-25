import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_add_student_screen.dart';

class EnrolledStudentItem {
  final String recordId;
  final String studentId;
  final String joinedAt;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String country;
  final String? avatarUrl;
  final int totalScore;
  final double walletBalance;
  final String bio;

  EnrolledStudentItem({
    required this.recordId,
    required this.studentId,
    required this.joinedAt,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.country,
    this.avatarUrl,
    required this.totalScore,
    required this.walletBalance,
    required this.bio,
  });
}

class TeacherClassStudentsScreen extends StatefulWidget {
  final String classId;
  const TeacherClassStudentsScreen({super.key, required this.classId});

  @override
  State<TeacherClassStudentsScreen> createState() => _TeacherClassStudentsScreenState();
}

class _TeacherClassStudentsScreenState extends State<TeacherClassStudentsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String className = "Loading...";
  List<EnrolledStudentItem> enrolledStudents = [];

  EnrolledStudentItem? selectedStudent;
  final TextEditingController _scoreController = TextEditingController();
  bool isScoring = false;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchClassAndStudentsData();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassAndStudentsData() async {
    setState(() => isLoading = true);
    try {
      // ۱. واکشی اطلاعات کلاس (class_groups) و شناسه دوره مربوطه (course_id)
      final classData = await supabase
          .from("class_groups")
          .select("class_name, course_id")
          .eq("id", widget.classId)
          .maybeSingle();

      if (classData != null) {
        className = classData['class_name'] ?? 'Classroom';
        final courseId = classData['course_id'];

        // ۲. واکشی مستقیم از جدول class_students برای این کلاس
        final classStudentsRes = await supabase
            .from("class_students")
            .select("id, student_id, joined_at")
            .eq("class_group_id", widget.classId);

        final studentIdsSet = <String>{};
        final studentRecordsMap = <String, Map<String, dynamic>>{};

        for (var cs in (classStudentsRes as List)) {
          final sId = cs['student_id']?.toString();
          if (sId != null) {
            studentIdsSet.add(sId);
            studentRecordsMap[sId] = {
              'recordId': cs['id'] ?? '',
              'joinedAt': cs['joined_at'] ?? '',
            };
          }
        }

        // ۳. اگر دوره (course_id) وجود داشت، شاگردان جدول enrollments را هم بررسی می‌کنیم تا لیست کامل باشد
        if (courseId != null) {
          final enrollmentsRes = await supabase
              .from("enrollments")
              .select("student_id, enrolled_at")
              .eq("course_id", courseId);

          for (var en in (enrollmentsRes as List)) {
            final sId = en['student_id']?.toString();
            if (sId != null) {
              studentIdsSet.add(sId);
              if (!studentRecordsMap.containsKey(sId)) {
                studentRecordsMap[sId] = {
                  'recordId': 'enrolled_${en['student_id']}', // شناسه مجازی برای ان‌رول‌ها
                  'joinedAt': en['enrolled_at'] ?? '',
                };
              }
            }
          }
        }

        if (studentIdsSet.isNotEmpty) {
          // ۴. خواندن پروفایل کامل شاگردان از جدول profiles
          final profilesData = await supabase
              .from("profiles")
              .select("id, first_name, last_name, email, phone_number, country, avatar_url, total_score, wallet_balance, bio")
              .inFilter("id", studentIdsSet.toList());

          enrolledStudents = (profilesData as List).map((p) {
            final pId = p['id'].toString();
            final recInfo = studentRecordsMap[pId] ?? {'recordId': '', 'joinedAt': ''};

            return EnrolledStudentItem(
              recordId: recInfo['recordId'],
              studentId: pId,
              joinedAt: recInfo['joinedAt'],
              firstName: p['first_name'] ?? 'Unknown',
              lastName: p['last_name'] ?? '',
              email: p['email'] ?? '',
              phoneNumber: p['phone_number'] ?? '',
              country: p['country'] ?? '',
              avatarUrl: p['avatar_url'],
              totalScore: p['total_score'] ?? 0,
              walletBalance: (p['wallet_balance'] ?? 0).toDouble(),
              bio: p['bio'] ?? '',
            );
          }).toList();
        } else {
          enrolledStudents = [];
        }
      }
    } catch (e) {
      debugPrint("Error fetching class students data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _removeStudent(EnrolledStudentItem student) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Student", style: TextStyle(color: textDark, fontSize: 15, fontWeight: FontWeight.w900)),
        content: Text("Remove ${student.firstName} from this classroom?", style: const TextStyle(color: textGrey, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (!student.recordId.startsWith('enrolled_')) {
        await supabase.from("class_students").delete().eq("id", student.recordId);
      }
      setState(() {
        enrolledStudents.removeWhere((s) => s.studentId == student.studentId);
        selectedStudent = null;
      });
    } catch (e) {
      debugPrint("Failed to remove student: $e");
    }
  }

  Future<void> _addScore() async {
    if (selectedStudent == null || _scoreController.text.trim().isEmpty) return;

    final addVal = int.tryParse(_scoreController.text.trim()) ?? 0;
    final newScore = selectedStudent!.totalScore + addVal;

    setState(() => isScoring = true);
    try {
      await supabase
          .from("profiles")
          .update({'total_score': newScore})
          .eq("id", selectedStudent!.studentId);

      setState(() {
        enrolledStudents = enrolledStudents.map((s) {
          if (s.studentId == selectedStudent!.studentId) {
            return EnrolledStudentItem(
              recordId: s.recordId,
              studentId: s.studentId,
              joinedAt: s.joinedAt,
              firstName: s.firstName,
              lastName: s.lastName,
              email: s.email,
              phoneNumber: s.phoneNumber,
              country: s.country,
              avatarUrl: s.avatarUrl,
              totalScore: newScore,
              walletBalance: s.walletBalance,
              bio: s.bio,
            );
          }
          return s;
        }).toList();
        selectedStudent = enrolledStudents.firstWhere((s) => s.studentId == selectedStudent!.studentId);
        _scoreController.clear();
      });
    } catch (e) {
      debugPrint("Failed to update score: $e");
    } finally {
      if (mounted) setState(() => isScoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: const Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(
          "Roster: $className",
          style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= هدر صفحه با دکمه Add Student =================
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: primaryPink.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWide = constraints.maxWidth > 400;
                          return Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryPink.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.people_alt_rounded, color: primaryPink, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Class Roster", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                                      const SizedBox(height: 3),
                                      Text("${enrolledStudents.length} Students Enrolled", style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: isWide ? 0 : 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryPink,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.person_add_rounded, size: 18),
                                label: const Text("Add Student", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => TeacherAddStudentScreen(classId: widget.classId)),
                                  ).then((_) => _fetchClassAndStudentsData());
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text("Enrolled Students Directory", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 12),

                    enrolledStudents.isNotEmpty
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: enrolledStudents.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final student = enrolledStudents[index];
                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: cardBorder, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: lightPinkBg,
                                            backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                            child: student.avatarUrl == null
                                                ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S',
                                                    style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900))
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("${student.firstName} ${student.lastName}",
                                                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                                const SizedBox(height: 2),
                                                Text(student.email, style: const TextStyle(color: textGrey, fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryPink.withOpacity(0.1),
                                        foregroundColor: primaryPink,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () => setState(() => selectedStudent = student),
                                      child: const Text("Manage", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
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
                                Icon(Icons.group_off_rounded, size: 36, color: textGrey),
                                SizedBox(height: 10),
                                Text("No Students Enrolled", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 4),
                                Text("No students are currently enrolled in this classroom.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // مودال مدیریت پروفایل و امتیازات شاگرد
          if (selectedStudent != null)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text("${selectedStudent!.firstName} ${selectedStudent!.lastName}",
                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                              onPressed: () => setState(() => selectedStudent = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text("Email: ${selectedStudent!.email}", style: const TextStyle(color: textGrey, fontSize: 11)),
                        Text("Phone: ${selectedStudent!.phoneNumber}", style: const TextStyle(color: textGrey, fontSize: 11)),
                        Text("Country: ${selectedStudent!.country}", style: const TextStyle(color: textGrey, fontSize: 11)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text("Total Score: ${selectedStudent!.totalScore} Pts",
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 16),
                        const Text("Add Points", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _scoreController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: textDark, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: "Enter points...",
                                  hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                                  filled: true,
                                  fillColor: cardBorder.withOpacity(0.5),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isScoring ? null : _addScore,
                              child: const Text("Add", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.person_remove_rounded, size: 16),
                            label: const Text("Remove from Class", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            onPressed: () => _removeStudent(selectedStudent!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}