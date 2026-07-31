import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ClassGroupForAttendance {
  final String id;
  final String className;
  final String? meetingLink;
  final String? signalGroupLink;
  bool alreadySigned;

  ClassGroupForAttendance({
    required this.id,
    required this.className,
    this.meetingLink,
    this.signalGroupLink,
    required this.alreadySigned,
  });
}

class AssignmentItem {
  final String id;
  final String courseName;
  final String title;
  final String description;
  final String deadline;
  String status; // "pending", "submitted", "graded", "overdue"
  final String? fileUrl;
  final dynamic grade;
  final String? feedback;

  AssignmentItem({
    required this.id,
    required this.courseName,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
    this.fileUrl,
    this.grade,
    this.feedback,
  });
}

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<AssignmentItem> assignments = [];
  List<ClassGroupForAttendance> todayClasses = [];
  String filter = "pending"; // "pending", "submitted", "graded"

  String? signingId;
  String? uploadingId;
  final Map<String, XFile?> selectedFiles = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final todayDate = DateTime.now().toIso8601String().split('T')[0];

      // ۱. دریافت لاگ‌های حاضری امروز
      final myLogs = await supabase
          .from("attendance_logs")
          .select("class_group_id")
          .eq("student_id", userId)
          .eq("session_date", todayDate);

      final signedClassIds = (myLogs as List?)?.map((log) => log['class_group_id'] as String).toList() ?? [];

      // ۲. دریافت کلاس‌های ثبت‌نام شده شاگرد همراه با لینک‌های Teams و Signal
      final enrollments = await supabase
          .from("class_students")
          .select("class_group_id, class_groups(id, class_name, meeting_link, signal_group_link)")
          .eq("student_id", userId);

      todayClasses = (enrollments as List).map((item) {
        final cgObj = item['class_groups'];
        final cg = cgObj is List ? (cgObj.isNotEmpty ? cgObj[0] : null) : cgObj;
        return ClassGroupForAttendance(
          id: cg?['id'] ?? '',
          className: cg?['class_name'] ?? 'Unknown Class',
          meetingLink: cg?['meeting_link'],
          signalGroupLink: cg?['signal_group_link'],
          alreadySigned: signedClassIds.contains(cg?['id']),
        );
      }).toList();
    
      // ۳. دریافت تکالیف متصل به دوره‌های شاگرد
      final assignmentEnrollments = await supabase
          .from("enrollments")
          .select("course_id, courses(title)")
          .eq("student_id", userId);

      if ((assignmentEnrollments as List).isNotEmpty) {
        final courseIds = assignmentEnrollments.map((e) => e['course_id']).toList();

        final allAssignments = await supabase
            .from("assignments")
            .select("*")
            .inFilter("course_id", courseIds) // Fix: Removed extra positional argument for order
            .order("deadline", ascending: true);

        final submissions = await supabase
            .from("assignment_submissions")
            .select("*")
            .eq("student_id", userId);

        assignments = (allAssignments as List).map((task) {
          final enrollment = assignmentEnrollments.firstWhere((e) => e['course_id'] == task['course_id'], orElse: () => <String, dynamic>{});
          final coursesObj = enrollment?['courses'];
          final courseData = coursesObj is List ? (coursesObj.isNotEmpty ? coursesObj[0] : null) : coursesObj;
          final courseName = courseData?['title'] ?? 'Unknown Course';

          final submission = (submissions as List?)?.firstWhere((sub) => sub['assignment_id'] == task['id'], orElse: () => null);

          String status = "pending";
          DateTime deadlineDate = DateTime.parse(task['deadline']);
          if (submission != null) {
            status = submission['grade'] != null ? "graded" : "submitted";
          } else if (deadlineDate.isBefore(DateTime.now())) {
            status = "overdue";
          }

          return AssignmentItem(
            id: task['id'],
            courseName: courseName,
            title: task['title'] ?? '',
            description: task['description'] ?? '',
            deadline: task['deadline'] ?? '',
            status: status,
            fileUrl: submission?['file_url'],
            grade: submission?['grade'],
            feedback: submission?['feedback'],
          );
        }).toList();
            }
    } catch (e) {
      debugPrint("Database Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSignAttendance(String classGroupId) async {
    setState(() => signingId = classGroupId);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from("attendance_logs").insert({
        'class_group_id': classGroupId,
        'student_id': user.id,
        'status': 'present',
        'session_date': DateTime.now().toIso8601String(),
      });

      setState(() {
        final cls = todayClasses.firstWhere((c) => c.id == classGroupId);
        cls.alreadySigned = true;
      });
    } catch (e) {
      debugPrint("Attendance error: $e");
    } finally {
      if (mounted) setState(() => signingId = null);
    }
  }

  Future<void> _pickImage(String assignmentId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedFiles[assignmentId] = image;
      });
    }
  }

  Future<void> _handleSubmitAssignment(String assignmentId) async {
    final file = selectedFiles[assignmentId];
    if (file == null) return;

    setState(() => uploadingId = assignmentId);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = file.name.split('.').last;
      final fileName = '${user.id}-$assignmentId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final bytes = await file.readAsBytes();

      // آپلود به باکت assignments در Supabase Storage
      await supabase.storage.from('assignments').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from('assignments').getPublicUrl(fileName);

      await supabase.from('assignment_submissions').insert({
        'assignment_id': assignmentId,
        'student_id': user.id,
        'file_url': publicUrl,
      });

      await _fetchAllData();
      setState(() {
        selectedFiles[assignmentId] = null;
      });
    } catch (e) {
      debugPrint("Upload failed: $e");
    } finally {
      if (mounted) setState(() => uploadingId = null);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  List<AssignmentItem> get filteredAssignments {
    return assignments.where((task) {
      if (filter == "pending") return task.status == "pending" || task.status == "overdue";
      return task.status == filter;
    }).toList();
  }
  
  Null get ascending => null;

  Color _getStatusColor(String status) {
    switch (status) {
      case "overdue":
        return Colors.redAccent;
      case "submitted":
        return Colors.blueAccent;
      case "graded":
        return Colors.greenAccent;
      default:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("🎓", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Student Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Sign today's attendance, submit homework, and track your academic progress.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= ۱. بخش حاضری امروز =================
          const Text("Today's Check-in", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.yellowAccent))
              : todayClasses.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: todayClasses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cls = todayClasses[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(cls.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  cls.alreadySigned
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("Signed", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: signingId == cls.id ? null : () => _handleSignAttendance(cls.id),
                                          child: Text(signingId == cls.id ? "Signing..." : "Sign Now", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (cls.meetingLink != null)
                                    GestureDetector(
                                      onTap: () => _launchURL(cls.meetingLink!),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.video_call, color: Colors.redAccent, size: 14),
                                          SizedBox(width: 4),
                                          Text("Teams Room", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  if (cls.meetingLink != null && cls.signalGroupLink != null) const SizedBox(width: 16),
                                  if (cls.signalGroupLink != null)
                                    GestureDetector(
                                      onTap: () => _launchURL(cls.signalGroupLink!),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.message, color: Colors.indigoAccent, size: 14),
                                          SizedBox(width: 4),
                                          Text("Signal Chat", style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: const Text("No live classes scheduled for today.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 24),

          // ================= ۲. بخش تکالیف و پروژه‌ها =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Homework & Projects", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildFilterTab("pending", "To Do"),
                    _buildFilterTab("submitted", "Review"),
                    _buildFilterTab("graded", "Graded"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          filteredAssignments.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredAssignments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = filteredAssignments[index];
                    final color = _getStatusColor(task.status);
                    final file = selectedFiles[task.id];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                                child: Text(task.courseName, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(task.status.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(task.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(task.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, height: 1.3)),
                          const SizedBox(height: 10),
                          Text("Deadline: ${task.deadline.split('T')[0]}", style: const TextStyle(color: Colors.grey, fontSize: 8)),
                          const SizedBox(height: 12),

                          if (task.status == "pending" || task.status == "overdue") ...[
                            GestureDetector(
                              onTap: () => _pickImage(task.id),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file, color: Colors.grey, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file != null ? file.name : "Tap to select image/screenshot",
                                        style: TextStyle(color: file != null ? Colors.white : Colors.grey, fontSize: 10),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: file == null || uploadingId == task.id ? null : () => _handleSubmitAssignment(task.id),
                                child: Text(uploadingId == task.id ? "Uploading..." : "Submit Assignment", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else if (task.status == "submitted") ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Text("Submitted. Waiting for instructor's grade...", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ] else if (task.status == "graded") ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Text("Grade: ${task.grade}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text("Feedback: ${task.feedback ?? 'No feedback'}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text("No assignments found for this filter.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}