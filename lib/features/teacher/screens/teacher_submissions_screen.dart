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

  SubmissionItem? selectedSubmission;
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  bool isSavingGrade = false;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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

      assignmentInfo = assignData;
    
      final subData = await supabase
          .from("assignment_submissions")
          .select("id, student_id, file_url, grade, feedback, submitted_at")
          .eq("assignment_id", widget.assignmentId)
          .order("submitted_at", ascending: false);

      if ((subData as List).isNotEmpty) {
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
        title: Text(assignmentInfo?['title'] ?? 'Submissions', style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= اطلاعات تکلیف (ریسپانسیو) =================
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(assignmentInfo?['description'] ?? 'No instructions provided.', style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 16),
                            const Divider(color: cardBorder),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text("Max Score: ${assignmentInfo?['max_score'] ?? 100} Pts", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 10)),
                                ),
                                Text("Due: ${assignmentInfo?['deadline']?.toString().split('T')[0] ?? 'No Deadline'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text("Received Submissions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 12),

                      submissions.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: submissions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final sub = submissions[index];
                                bool isGraded = sub.grade != null;

                                return Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isGraded ? Colors.green.withValues(alpha: 0.3) : primaryPink.withValues(alpha: 0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: lightPinkBg,
                                                  backgroundImage: sub.avatarUrl != null ? NetworkImage(sub.avatarUrl!) : null,
                                                  child: sub.avatarUrl == null ? Text(sub.firstName[0], style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 12)) : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text("${sub.firstName} ${sub.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 2),
                                                      Text(sub.email, style: const TextStyle(color: textGrey, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isGraded ? Colors.green.withValues(alpha: 0.12) : lightPinkBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isGraded ? "Graded (${sub.grade})" : "● Pending",
                                              style: TextStyle(
                                                color: isGraded ? Colors.green.shade700 : primaryPink,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      const Divider(color: cardBorder, height: 1),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          sub.fileUrl != null
                                              ? GestureDetector(
                                                  onTap: () => _launchURL(sub.fileUrl!),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.folder_open_rounded, size: 14, color: Colors.blueAccent),
                                                      SizedBox(width: 5),
                                                      Text("View Attached File", style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                                                    ],
                                                  ),
                                                )
                                              : const Text("No file attached", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryPink,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            onPressed: () => _openGradeModal(sub),
                                            child: const Text("Evaluate", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
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
                                  Icon(Icons.folder_off_rounded, size: 36, color: textGrey),
                                  SizedBox(height: 10),
                                  Text("No Submissions", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(height: 4),
                                  Text("No student submissions received yet.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ================= مودال نمره‌دهی (ریسپانسیو و فیکس‌شده) =================
          if (selectedSubmission != null)
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
                    border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: primaryPink.withValues(alpha: 0.1), blurRadius: 25, offset: const Offset(0, 10))],
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
                              child: Text("Evaluate Work: ${selectedSubmission!.firstName}",
                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                              onPressed: () => setState(() => selectedSubmission = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text("Award Points *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _gradeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Score (e.g. 95)",
                            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                            filled: true,
                            fillColor: cardBorder.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text("Teacher Feedback", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _feedbackController,
                          maxLines: 3,
                          style: const TextStyle(color: textDark, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Constructive comments...",
                            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                            filled: true,
                            fillColor: cardBorder.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(foregroundColor: textGrey),
                                onPressed: () => setState(() => selectedSubmission = null),
                                child: const Text("Cancel", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryPink,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: isSavingGrade ? null : _saveGrade,
                                child: Text(isSavingGrade ? "Saving..." : "Save Grade", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
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