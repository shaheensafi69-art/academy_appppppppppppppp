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

  // پالت رنگی لایت و مدرن همگام با سایر صفحات
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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

      // ۱. دریافت لاگ‌های حاضری امروز از جدول attendance_logs
      final myLogs = await supabase
          .from("attendance_logs")
          .select("class_group_id")
          .eq("student_id", userId)
          .eq("session_date", todayDate);

      final signedClassIds = (myLogs as List?)?.map((log) => log['class_group_id'] as String).toList() ?? [];

      // ۲. دریافت کلاس‌های ثبت‌نام شده شاگرد از جدول class_students و class_groups
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
    
      // ۳. دریافت تکالیف متصل به دوره‌های شاگرد از جدول enrollments و assignments
      final assignmentEnrollments = await supabase
          .from("enrollments")
          .select("course_id, courses(title)")
          .eq("student_id", userId);

      if ((assignmentEnrollments as List).isNotEmpty) {
        final courseIds = assignmentEnrollments.map((e) => e['course_id']).toList();

        final allAssignments = await supabase
            .from("assignments")
            .select("*")
            .inFilter("course_id", courseIds)
            .order("deadline", ascending: true);

        final submissions = await supabase
            .from("assignment_submissions")
            .select("*")
            .eq("student_id", userId);

        assignments = (allAssignments as List).map((task) {
          final enrollment = assignmentEnrollments.firstWhere((e) => e['course_id'] == task['course_id'], orElse: () => <String, dynamic>{});
          final coursesObj = enrollment['courses'];
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

  Color _getStatusColor(String status) {
    switch (status) {
      case "overdue":
        return Colors.redAccent;
      case "submitted":
        return Colors.blueAccent;
      case "graded":
        return Colors.green;
      default:
        return primaryPink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر صفحه
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightPinkBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: primaryPink, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Student Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                      SizedBox(height: 3),
                      Text("Sign today's attendance, submit homework, and track academic progress.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= ۱. بخش حاضری امروز =================
          const Text("Today's Check-in", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5))
              : todayClasses.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: todayClasses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cls = todayClasses[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(cls.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                  ),
                                  cls.alreadySigned
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("Signed ✅", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: lightPinkBg,
                                            foregroundColor: primaryPink,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: signingId == cls.id ? null : () => _handleSignAttendance(cls.id),
                                          child: Text(signingId == cls.id ? "Signing..." : "Sign Now", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                                        ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (cls.meetingLink != null)
                                    GestureDetector(
                                      onTap: () => _launchURL(cls.meetingLink!),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.video_call_rounded, color: primaryPink, size: 14),
                                          SizedBox(width: 4),
                                          Text("Teams Room", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  if (cls.meetingLink != null && cls.signalGroupLink != null) const SizedBox(width: 16),
                                  if (cls.signalGroupLink != null)
                                    GestureDetector(
                                      onTap: () => _launchURL(cls.signalGroupLink!),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.chat_bubble_rounded, color: Colors.indigo, size: 14),
                                          SizedBox(width: 4),
                                          Text("Signal Chat", style: TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.w900)),
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
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: const Text("No live classes scheduled for today.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
          const SizedBox(height: 24),

          // ================= ۲. بخش تکالیف و پروژه‌ها =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Homework", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cardBorder,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(child: _buildFilterTab("pending", "To Do")),
                        Flexible(child: _buildFilterTab("submitted", "Review")),
                        Flexible(child: _buildFilterTab("graded", "Graded")),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          filteredAssignments.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredAssignments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = filteredAssignments[index];
                    final color = _getStatusColor(task.status);

                    return GestureDetector(
                      onTap: () {
                        // انتقال به صفحه جدید جزئیات تکلیف
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentAssignmentDetailScreen(assignment: task),
                          ),
                        ).then((_) => _fetchAllData());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                    child: Text(task.courseName, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(task.status.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(task.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(task.description, style: const TextStyle(color: textGrey, fontSize: 10, height: 1.3, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Deadline: ${task.deadline.split('T')[0]}", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                                const Text("View Details ➔", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.5),
                  ),
                  child: const Text("No assignments found for this filter.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryPink : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textDark,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ================= صفحه جدید: جزئیات و ارسال تکلیف (StudentAssignmentDetailScreen) =================
class StudentAssignmentDetailScreen extends StatefulWidget {
  final AssignmentItem assignment;
  const StudentAssignmentDetailScreen({super.key, required this.assignment});

  @override
  State<StudentAssignmentDetailScreen> createState() => _StudentAssignmentDetailScreenState();
}

class _StudentAssignmentDetailScreenState extends State<StudentAssignmentDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isUploading = false;
  XFile? selectedFile;
  final ImagePicker _picker = ImagePicker();

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  Future<void> _pickFile() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedFile = image;
      });
    }
  }

  Future<void> _submitAssignment() async {
    if (selectedFile == null) return;

    setState(() => isUploading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = selectedFile!.name.split('.').last;
      final fileName = '${user.id}-${widget.assignment.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final bytes = await selectedFile!.readAsBytes();

      await supabase.storage.from('assignments').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from('assignments').getPublicUrl(fileName);

      await supabase.from('assignment_submissions').insert({
        'assignment_id': widget.assignment.id,
        'student_id': user.id,
        'file_url': publicUrl,
      });

      setState(() {
        widget.assignment.status = "submitted";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assignment submitted successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_rounded, color: textDark, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text("Assignment Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                          child: Text(widget.assignment.courseName, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(widget.assignment.status.toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(widget.assignment.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 10),
                    const Text("Description:", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.assignment.description, style: const TextStyle(color: textDark, fontSize: 12, height: 1.4, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: textGrey),
                        const SizedBox(width: 6),
                        Text("Deadline: ${widget.assignment.deadline.split('T')[0]}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.assignment.status == "pending" || widget.assignment.status == "overdue") ...[
                const Text("Submit Your Work", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_rounded, color: primaryPink, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFile != null ? selectedFile!.name : "Upload Document / Screenshot / PDF",
                            style: TextStyle(color: selectedFile != null ? textDark : textGrey, fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: selectedFile == null || isUploading ? null : _submitAssignment,
                    child: isUploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("SUBMIT ASSIGNMENT 🚀", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ] else if (widget.assignment.status == "submitted") ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: const Text("Assignment submitted successfully. Waiting for instructor's review and grading.", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                ),
              ] else if (widget.assignment.status == "graded") ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text("Grade: ${widget.assignment.grade} / 100", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Instructor Feedback:", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(widget.assignment.feedback ?? 'No feedback provided.', style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}