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
        backgroundColor: const Color(0xFF0a0a0f),
        title: const Text("Remove Student", style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Text("Remove ${student.firstName} from this cohort?", style: const TextStyle(color: Colors.grey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remove", style: TextStyle(color: Colors.redAccent))),
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
        backgroundColor: const Color(0xFF030305),
        body: const Center(child: CircularProgressIndicator(color: Colors.pink)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Roster: $className", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Enrolled Students", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),

                enrolledStudents.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: enrolledStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = enrolledStudents[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0f),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.pink.withOpacity(0.2),
                                      backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                      child: student.avatarUrl == null ? Text(student.firstName[0], style: const TextStyle(color: Colors.pinkAccent)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${student.firstName} ${student.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(student.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                      ],
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.08),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => setState(() => selectedStudent = student),
                                  child: const Text("Manage", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text("No students enrolled in this class yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ),
                      ),
              ],
            ),
          ),

          // مودال مدیریت پروفایل شاگرد
          if (selectedStudent != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d0d14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.pink.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${selectedStudent!.firstName} ${selectedStudent!.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 18), onPressed: () => setState(() => selectedStudent = null)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Email: ${selectedStudent!.email}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Phone: ${selectedStudent!.phoneNumber}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Country: ${selectedStudent!.country}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Total Score: ${selectedStudent!.totalScore} Pts", style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),

                    const Text("Add Points", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _scoreController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              hintText: "Points...",
                              hintStyle: TextStyle(color: Colors.grey.shade700),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                          onPressed: isScoring ? null : _addScore,
                          child: const Text("Add", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                        icon: const Icon(Icons.delete, size: 14),
                        label: const Text("Remove from Class", style: TextStyle(fontSize: 10)),
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