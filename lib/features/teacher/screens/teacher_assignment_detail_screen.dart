import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherAssignmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> submission;

  const TeacherAssignmentDetailScreen({super.key, required this.submission});

  @override
  State<TeacherAssignmentDetailScreen> createState() => _TeacherAssignmentDetailScreenState();
}

class _TeacherAssignmentDetailScreenState extends State<TeacherAssignmentDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isSaving = false;

  late final TextEditingController _gradeController;
  late final TextEditingController _feedbackController;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _gradeController = TextEditingController(text: widget.submission['grade']?.toString() ?? '');
    _feedbackController = TextEditingController(text: widget.submission['feedback'] ?? '');
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _saveGrading() async {
    final gradeText = _gradeController.text.trim();
    final feedbackText = _feedbackController.text.trim();

    if (gradeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid grade."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final submissionId = widget.submission['id'];

      await supabase.from('assignment_submissions').update({
        'grade': double.tryParse(gradeText) ?? 0.0,
        'feedback': feedbackText,
      }).eq('id', submissionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assignment graded successfully! ✅"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error grading assignment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save grade: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.submission['profiles'] as Map<String, dynamic>?;
    final assignment = widget.submission['assignments'] as Map<String, dynamic>?;

    final studentName = profile != null ? "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}" : "Student";
    final assignmentTitle = assignment?['title'] ?? 'Assignment';
    final fileUrl = widget.submission['file_url'] ?? '';
    final submittedAt = widget.submission['submitted_at'] ?? '';

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        title: const Text("Review Assignment", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
        iconTheme: const IconThemeData(color: primaryPink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Container(
                padding: const EdgeInsets.all(22),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.assignment_turned_in_rounded, color: primaryPink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(assignmentTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text("Submitted by: $studentName", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, color: cardBorder),

                    Text("Submission Date: $submittedAt", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),

                    // دکمه باز کردن فایل ارسالی دانشجو
                    if (fileUrl.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryPink,
                          side: const BorderSide(color: primaryPink, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text("Download / View Student File 📎", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        onPressed: () => _launchURL(fileUrl),
                      )
                    else
                      const Text("No attached file provided by student.", style: TextStyle(color: textGrey, fontSize: 11, fontStyle: FontStyle.italic)),

                    const SizedBox(height: 24),

                    // فیلد ثبت نمره
                    const Text("Assign Grade (e.g. 95.0)", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _gradeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Enter score...",
                        filled: true,
                        fillColor: cardBorder.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // فیلد بازخورد و فیدبک
                    const Text("Teacher Feedback", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 4,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Write your constructive feedback for the student...",
                        filled: true,
                        fillColor: cardBorder.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving ? null : _saveGrading,
                        child: isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("SUBMIT GRADE & FEEDBACK 📝", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}