import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionItem {
  final String id;
  final String questionText;
  final int points;

  QuestionItem({required this.id, required this.questionText, required this.points});
}

class StudentQuizDetailScreen extends StatefulWidget {
  final String quizId;
  const StudentQuizDetailScreen({super.key, required this.quizId});

  @override
  State<StudentQuizDetailScreen> createState() => _StudentQuizDetailScreenState();
}

class _StudentQuizDetailScreenState extends State<StudentQuizDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;
  bool isSubmittedSuccessfully = false;

  Map<String, dynamic>? quizInfo;
  List<QuestionItem> questions = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _fetchExamData();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchExamData() async {
    setState(() => isLoading = true);
    try {
      final quizData = await supabase
          .from("quizzes")
          .select("id, title, passing_score, quiz_type")
          .eq("id", widget.quizId)
          .single();

      quizInfo = quizData;
    
      final questionsData = await supabase
          .from("quiz_questions")
          .select("id, question_text, points")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      questions = (questionsData as List).map((q) {
        final id = q['id'];
        _controllers[id] = TextEditingController();
        return QuestionItem(
          id: id,
          questionText: q['question_text'] ?? '',
          points: q['points'] ?? 10,
        );
      }).toList();
        } catch (e) {
      debugPrint("Failed to load exam paper: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSubmitExam() async {
    final user = supabase.auth.currentUser;
    if (user == null || quizInfo == null) return;

    // بررسی پاسخ‌دهی
    int unanswered = questions.where((q) => (_controllers[q.id]?.text.trim() ?? "").isEmpty).length;
    if (unanswered > 0) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0a0a0f),
          title: const Text("Unanswered Questions", style: TextStyle(color: Colors.white, fontSize: 14)),
          content: Text("You have $unanswered unanswered questions! Are you sure you want to submit?", style: const TextStyle(color: Colors.grey, fontSize: 11)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Submit", style: TextStyle(color: Colors.amberAccent))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => isSubmitting = true);
    try {
      // ۱. ثبت در جدول quiz_attempts با وضعیت pending_review
      final attemptData = await supabase
          .from("quiz_attempts")
          .insert({
            'quiz_id': widget.quizId,
            'student_id': user.id,
            'score': 0,
            'is_passed': false,
            'status': 'pending_review',
            'letter_grade': null,
          })
          .select("id")
          .single();

      final attemptId = attemptData['id'];

      // ۲. ثبت پاسخ‌های تشریحی شاگرد
      List<Map<String, dynamic>> answersArray = questions.map((q) {
        return {
          'attempt_id': attemptId,
          'question_id': q.id,
          'student_answer_text': _controllers[q.id]?.text.trim().isNotEmpty == true ? _controllers[q.id]!.text.trim() : "No answer provided.",
          'points_earned': 0,
          'is_correct': null,
        };
      }).toList();

      await supabase.from("quiz_student_answers").insert(answersArray);

      setState(() => isSubmittedSuccessfully = true);
    } catch (e) {
      debugPrint("Failed to submit exam paper: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.purpleAccent),
              const SizedBox(height: 12),
              Text("Distributing Exam Papers...", style: TextStyle(color: Colors.purpleAccent.shade100, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (isSubmittedSuccessfully) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("⏳", style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                const Text("Paper Submitted!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("Your answers for ${quizInfo?['title']} have been securely saved. The instructor will review your paper shortly.", style: TextStyle(color: Colors.grey.shade400, fontSize: 11), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Return to Exam Center"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(quizInfo?['title'] ?? 'Exam Paper', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Text("✍️", style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("Read each question carefully and type your descriptive answer in the provided boxes.", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final q = questions[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
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
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                            child: Text("${q.points} Pts", style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(q.questionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controllers[q.id],
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Type your detailed answer here...",
                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting ? null : _handleSubmitExam,
                child: Text(isSubmitting ? "Submitting Paper..." : "Submit Exam Paper 🚀", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}