import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class GlobalStudentItem {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String? avatarUrl;

  GlobalStudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.avatarUrl,
  });
}

class TeacherAddStudentScreen extends StatefulWidget {
  final String classId;
  const TeacherAddStudentScreen({super.key, required this.classId});

  @override
  State<TeacherAddStudentScreen> createState() => _TeacherAddStudentScreenState();
}

class _TeacherAddStudentScreenState extends State<TeacherAddStudentScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String className = "Loading...";
  String? courseId;

  List<GlobalStudentItem> allStudents = [];
  Set<String> enrolledIds = {};
  String searchQuery = "";
  String? addingId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final classData = await supabase
          .from("class_groups")
          .select("class_name, course_id")
          .eq("id", widget.classId)
          .maybeSingle();

      if (classData != null) {
        className = classData['class_name'] ?? '';
        courseId = classData['course_id'];
      }

      final profilesData = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, phone_number, avatar_url")
          .eq("role", "student");

      if (profilesData != null) {
        allStudents = (profilesData as List).map((p) => GlobalStudentItem(
              id: p['id'],
              firstName: p['first_name'] ?? '',
              lastName: p['last_name'] ?? '',
              email: p['email'] ?? '',
              phoneNumber: p['phone_number'] ?? '',
              avatarUrl: p['avatar_url'],
            )).toList();
      }

      final enrolledData = await supabase
          .from("class_students")
          .select("student_id")
          .eq("class_group_id", widget.classId);

      if (enrolledData != null) {
        enrolledIds = Set<String>.from((enrolledData as List).map((e) => e['student_id']));
      }
    } catch (e) {
      debugPrint("Error fetching global roster: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addStudent(GlobalStudentItem student) async {
    if (courseId == null) return;

    setState(() => addingId = student.id);
    try {
      final existingEnrollment = await supabase
          .from("enrollments")
          .select("id")
          .eq("course_id", courseId!)
          .eq("student_id", student.id)
          .maybeSingle();

      if (existingEnrollment == null) {
        await supabase.from("enrollments").insert({
          'course_id': courseId,
          'student_id': student.id,
          'progress_percentage': 0,
        });
      }

      await supabase.from("class_students").insert({
        'class_group_id': widget.classId,
        'student_id': student.id,
      });

      setState(() {
        enrolledIds.add(student.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${student.firstName} added to class successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error adding student: $e");
    } finally {
      if (mounted) setState(() => addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    final filtered = allStudents.where((s) {
      final q = searchQuery.toLowerCase();
      return s.firstName.toLowerCase().contains(q) || s.lastName.toLowerCase().contains(q) || s.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Add to: $className", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "Search student by name or email...",
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 16),

            filtered.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      bool isEnrolled = enrolledIds.contains(student.id);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0a0a0f),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                                  backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                  child: student.avatarUrl == null ? Text(student.firstName[0], style: const TextStyle(color: Colors.pinkAccent)) : null,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${student.firstName} ${student.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text(student.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 8)),
                                  ],
                                ),
                              ],
                            ),
                            isEnrolled
                                ? const Text("Enrolled", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.pinkAccent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: addingId == student.id ? null : () => _addStudent(student),
                                    child: Text(addingId == student.id ? "..." : "Add", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                          ],
                        ),
                      );
                    },
                  )
                : const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text("No students found.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
          ],
        ),
      ),
    );
  }
}