import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionBankItem {
  final String id;
  final String quizId;
  final String questionText;
  final int points;

  QuestionBankItem({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.points,
  });
}

class TeacherQuizQuestionsScreen extends StatefulWidget {
  final String quizId;
  const TeacherQuizQuestionsScreen({super.key, required this.quizId});

  @override
  State<TeacherQuizQuestionsScreen> createState() => _TeacherQuizQuestionsScreenState();
}

class _TeacherQuizQuestionsScreenState extends State<TeacherQuizQuestionsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;
  String quizTitle = "";
  List<QuestionBankItem> questions = [];

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController(text: "10");

  @override
  void initState() {
    super.initState();
    _fetchQuizAndQuestions();
  }

  @override
  void dispose() {
    _textController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuizAndQuestions() async {
    setState(() => isLoading = true);
    try {
      final quizData = await supabase
          .from("quizzes")
          .select("title")
          .eq("id", widget.quizId)
          .single();

      if (quizData != null) quizTitle = quizData['title'] ?? '';

      final qData = await supabase
          .from("quiz_questions")
          .select("id, quiz_id, question_text, points")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      if (qData != null) {
        questions = (qData as List).map((q) => QuestionBankItem(
              id: q['id'] ?? '',
              quizId: q['quiz_id'] ?? '',
              questionText: q['question_text'] ?? '',
              points: q['points'] ?? 10,
            )).toList();
      }
    } catch (e) {
      debugPrint("Error fetching question bank: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addQuestion() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => isSubmitting = true);
    try {
      final data = await supabase.from("quiz_questions").insert({
        'quiz_id': widget.quizId,
        'question_text': _textController.text.trim(),
        'points': int.tryParse(_pointsController.text.trim()) ?? 10,
        'option_a': 'Descriptive',
        'option_b': 'Descriptive',
        'option_c': 'Descriptive',
        'option_d': 'Descriptive',
        'correct_option': 'A',
      }).select("id, quiz_id, question_text, points").single();

      if (data != null) {
        setState(() {
          questions.add(QuestionBankItem(
            id: data['id'],
            quizId: data['quiz_id'],
            questionText: data['question_text'],
            points: data['points'],
          ));
          _textController.clear();
        });
      }
    } catch (e) {
      debugPrint("Failed to add question: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _deleteQuestion(String id) async {
    try {
      await supabase.from("quiz_questions").delete().eq("id", id);
      setState(() {
        questions.removeWhere((q) => q.id == id);
      });
    } catch (e) {
      debugPrint("Failed to delete question: $e");
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

    int totalPoints = questions.fold(0, (sum, q) => sum + q.points);

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("$quizTitle Bank", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
                color: const Color(0xFF0a0a0f),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Questions: ${questions.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  Text("Total Points: $totalPoints", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // فرم افزودن سوال جدید
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add Descriptive Question", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Question text...",
                      hintStyle: TextStyle(color: Colors.grey.shade700),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.4),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pointsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          decoration: InputDecoration(
                            labelText: "Points",
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.4),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                        onPressed: isSubmitting ? null : _addQuestion,
                        child: Text(isSubmitting ? "..." : "Save", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text("Current Inventory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 10),

            questions.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0a0a0f),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${index + 1}.", style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.questionText, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text("${q.points} Points", style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                              onPressed: () => _deleteQuestion(q.id),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Padding(
                    padding: EdgeInsets.all(30.0),
                    child: Text("No questions added yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
          ],
        ),
      ),
    );
  }
}