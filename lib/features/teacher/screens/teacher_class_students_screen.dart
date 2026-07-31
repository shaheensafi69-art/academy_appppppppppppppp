import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // پالت رنگی لایت (سفید صدفی و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassData() async {
    setState(() => isLoading = true);
    try {
      final classData = await supabase
          .from("class_groups")
          .select("class_name")
          .eq("id", widget.classId)
          .maybeSingle();

      if (classData != null) {
        className = classData['class_name'] ?? 'Classroom';
      }

      final studentsData = await supabase
          .from("class_students")
          .select("id, student_id, joined_at")
          .eq("class_group_id", widget.classId)
          .order("joined_at", ascending: false);

      if (studentsData != null && (studentsData as List).isNotEmpty) {
        final studentIds = studentsData.map((s) => s['student_id']).toList();

        final profilesData = await supabase
            .from("profiles")
            .select("id, first_name, last_name, email, phone_number, country, avatar_url, total_score, wallet_balance, bio")
            .inFilter("id", studentIds);

        enrolledStudents = studentsData.map((item) {
          final p = (profilesData as List?)?.firstWhere(
            (prof) => prof['id'] == item['student_id'],
            orElse: () => null,
          );

          return EnrolledStudentItem(
            recordId: item['id'] ?? '',
            studentId: item['student_id'] ?? '',
            joinedAt: item['joined_at'] ?? '',
            firstName: p?['first_name'] ?? 'Unknown',
            lastName: p?['last_name'] ?? '',
            email: p?['email'] ?? '',
            phoneNumber: p?['phone_number'] ?? '',
            country: p?['country'] ?? '',
            avatarUrl: p?['avatar_url'],
            totalScore: p?['total_score'] ?? 0,
            walletBalance: (p?['wallet_balance'] ?? 0).toDouble(),
            bio: p?['bio'] ?? '',
          );
        }).toList();
      } else {
        enrolledStudents = [];
      }
    } catch (e) {
      debugPrint("Error fetching class students: $e");
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
        content: Text("Remove ${student.firstName} from this cohort?", style: const TextStyle(color: textGrey, fontSize: 12)),
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
      await supabase.from("class_students").delete().eq("id", student.recordId);
      setState(() {
        enrolledStudents.removeWhere((s) => s.recordId == student.recordId);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Enrolled Students", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),

                enrolledStudents.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: enrolledStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final student = enrolledStudents[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: lightPinkBg,
                                      backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                      child: student.avatarUrl == null
                                          ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S',
                                              style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${student.firstName} ${student.lastName}",
                                            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(student.email, style: const TextStyle(color: textGrey, fontSize: 10)),
                                      ],
                                    ),
                                  ],
                                ),
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
              ],
            ),
          ),

          // مودال مدیریت پروفایل شاگرد (به صورت لایت و مدرن)
          if (selectedStudent != null)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${selectedStudent!.firstName} ${selectedStudent!.lastName}",
                            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
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
                    const SizedBox(height: 6),
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
        ],
      ),
    );
  }
}