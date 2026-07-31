import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SubmissionItem {
  final String submissionId;
  final String studentId;
  final String? fileUrl;
  final double? grade;
  final String? feedback;
  final String submittedAt;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;

  SubmissionItem({
    required this.submissionId,
    required this.studentId,
    this.fileUrl,
    this.grade,
    this.feedback,
    required this.submittedAt,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
  });
}

class TeacherSubmissionsScreen extends StatefulWidget {
  final String assignmentId;
  const TeacherSubmissionsScreen({super.key, required this.assignmentId});

  @override
  State<TeacherSubmissionsScreen> createState() => _TeacherSubmissionsScreenState();
}

class _TeacherSubmissionsScreenState extends State<TeacherSubmissionsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  Map<String, dynamic>? assignmentInfo;
  List<SubmissionItem> submissions = [];

  // مودال نمره‌دهی
  SubmissionItem? selectedSubmission;
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  bool isSavingGrade = false;

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => isLoading = true);
    try {
      final assignData = await supabase
          .from("assignments")
          .select("title, description, deadline, max_score")
          .eq("id", widget.assignmentId)
          .single();

      if (assignData != null) {
        assignmentInfo = assignData;
      }

      final subData = await supabase
          .from("assignment_submissions")
          .select("id, student_id, file_url, grade, feedback, submitted_at")
          .eq("assignment_id", widget.assignmentId)
          .order("submitted_at", ascending: false);

      if (subData != null && (subData as List).isNotEmpty) {
        final studentIds = subData.map((s) => s['student_id']).toList();

        final profilesData = await supabase
            .from("profiles")
            .select("id, first_name, last_name, email, avatar_url")
            .inFilter("id", studentIds);

        submissions = subData.map((sub) {
          final p = (profilesData as List?)?.firstWhere(
            (prof) => prof['id'] == sub['student_id'],
            orElse: () => null,
          );

          return SubmissionItem(
            submissionId: sub['id'] ?? '',
            studentId: sub['student_id'] ?? '',
            fileUrl: sub['file_url'],
            grade: sub['grade']?.toDouble(),
            feedback: sub['feedback'],
            submittedAt: sub['submitted_at'] ?? '',
            firstName: p?['first_name'] ?? 'Unknown',
            lastName: p?['last_name'] ?? 'Student',
            email: p?['email'] ?? '',
            avatarUrl: p?['avatar_url'],
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error loading submissions: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openGradeModal(SubmissionItem sub) {
    setState(() {
      selectedSubmission = sub;
      _gradeController.text = sub.grade != null ? sub.grade.toString() : "";
      _feedbackController.text = sub.feedback ?? "";
    });
  }

  Future<void> _saveGrade() async {
    if (selectedSubmission == null || assignmentInfo == null) return;

    final score = double.tryParse(_gradeController.text.trim());
    final maxScore = (assignmentInfo?['max_score'] ?? 100).toDouble();

    if (score == null || score < 0 || score > maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid grade. Must be between 0 and $maxScore"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSavingGrade = true);
    try {
      await supabase
          .from("assignment_submissions")
          .update({
            'grade': score,
            'feedback': _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
          })
          .eq("id", selectedSubmission!.submissionId);

      setState(() {
        submissions = submissions.map((item) {
          if (item.submissionId == selectedSubmission!.submissionId) {
            return SubmissionItem(
              submissionId: item.submissionId,
              studentId: item.studentId,
              fileUrl: item.fileUrl,
              grade: score,
              feedback: _feedbackController.text.trim(),
              submittedAt: item.submittedAt,
              firstName: item.firstName,
              lastName: item.lastName,
              email: item.email,
              avatarUrl: item.avatarUrl,
            );
          }
          return item;
        }).toList();
        selectedSubmission = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Grade and feedback submitted successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Failed to submit grade: $e");
    } finally {
      if (mounted) setState(() => isSavingGrade = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
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
        title: Text(assignmentInfo?['title'] ?? 'Submissions', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اطلاعات تکلیف
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(assignmentInfo?['description'] ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Max Score: ${assignmentInfo?['max_score'] ?? 100} Pts", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                          Text("Due: ${assignmentInfo?['deadline']?.toString().split('T')[0] ?? 'No Deadline'}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text("Received Submissions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 10),

                submissions.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: submissions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sub = submissions[index];
                          bool isGraded = sub.grade != null;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0f),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: isGraded ? Colors.green.withOpacity(0.2) : Colors.pink.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.pink.withOpacity(0.2),
                                          backgroundImage: sub.avatarUrl != null ? NetworkImage(sub.avatarUrl!) : null,
                                          child: sub.avatarUrl == null ? Text(sub.firstName[0], style: const TextStyle(color: Colors.pinkAccent, fontSize: 12)) : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("${sub.firstName} ${sub.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                            Text(sub.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 8)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isGraded ? Colors.green.withOpacity(0.15) : Colors.pink.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(isGraded ? "Graded (${sub.grade})" : "Pending Review", style: TextStyle(color: isGraded ? Colors.greenAccent : Colors.pinkAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    sub.fileUrl != null
                                        ? GestureDetector(
                                            onTap: () => _launchURL(sub.fileUrl!),
                                            child: const Text("📁 View Attached File", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        : const Text("No file attached", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.pink,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _openGradeModal(sub),
                                      child: const Text("Evaluate", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0a0a0f),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text("No student submissions received yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ),
              ],
            ),
          ),

          // مودال نمره‌دهی
          if (selectedSubmission != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d0d14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Evaluate Work: ${selectedSubmission!.firstName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    const Text("Award Points *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _gradeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Score (e.g. 95)",
                        hintStyle: TextStyle(color: Colors.grey.shade700),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Teacher Feedback", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Constructive comments...",
                        hintStyle: TextStyle(color: Colors.grey.shade700),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.5),
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => selectedSubmission = null),
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                            onPressed: isSavingGrade ? null : _saveGrade,
                            child: Text(isSavingGrade ? "Saving..." : "Save Grade", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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