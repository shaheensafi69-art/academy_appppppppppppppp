import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionBankItem {
  final String id;
  final String quizId;
  final String questionText;
  final int points;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? correctOption;

  QuestionBankItem({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.points,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.correctOption,
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

  // کنترلرهای فرم افزودن سوال جدید
  String selectedQuestionType = "multiple_choice"; // 'multiple_choice' یا 'descriptive'
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController(text: "10");
  final TextEditingController _optAController = TextEditingController();
  final TextEditingController _optBController = TextEditingController();
  final TextEditingController _optCController = TextEditingController();
  final TextEditingController _optDController = TextEditingController();
  String selectedCorrectOption = "A";

  // پالت رنگی لایت (سفید صدفی و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchQuizAndQuestions();
  }

  @override
  void dispose() {
    _textController.dispose();
    _pointsController.dispose();
    _optAController.dispose();
    _optBController.dispose();
    _optCController.dispose();
    _optDController.dispose();
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

      quizTitle = quizData['title'] ?? '';

      final qData = await supabase
          .from("quiz_questions")
          .select("id, quiz_id, question_text, points, option_a, option_b, option_c, option_d, correct_option")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      questions = (qData as List).map((q) => QuestionBankItem(
            id: q['id'] ?? '',
            quizId: q['quiz_id'] ?? '',
            questionText: q['question_text'] ?? '',
            points: q['points'] ?? 10,
            optionA: q['option_a'],
            optionB: q['option_b'],
            optionC: q['option_c'],
            optionD: q['option_d'],
            correctOption: q['correct_option'],
          )).toList();
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
      bool isMCQ = selectedQuestionType == 'multiple_choice';

      final data = await supabase.from("quiz_questions").insert({
        'quiz_id': widget.quizId,
        'question_text': _textController.text.trim(),
        'points': int.tryParse(_pointsController.text.trim()) ?? 10,
        'option_a': isMCQ ? _optAController.text.trim() : 'Descriptive',
        'option_b': isMCQ ? _optBController.text.trim() : 'Descriptive',
        'option_c': isMCQ ? _optCController.text.trim() : 'Descriptive',
        'option_d': isMCQ ? _optDController.text.trim() : 'Descriptive',
        'correct_option': isMCQ ? selectedCorrectOption : 'A',
      }).select("id, quiz_id, question_text, points, option_a, option_b, option_c, option_d, correct_option").single();

      setState(() {
        questions.add(QuestionBankItem(
          id: data['id'],
          quizId: data['quiz_id'],
          questionText: data['question_text'],
          points: data['points'],
          optionA: data['option_a'],
          optionB: data['option_b'],
          optionC: data['option_c'],
          optionD: data['option_d'],
          correctOption: data['correct_option'],
        ));
        _textController.clear();
        _optAController.clear();
        _optBController.clear();
        _optCController.clear();
        _optDController.clear();
      });
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
        backgroundColor: surfaceWhite,
        body: const Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    int totalPoints = questions.fold(0, (sum, q) => sum + q.points);

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: Text("$quizTitle Bank", style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // باکس آمار کلی
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Questions: ${questions.length}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text("Total Points: $totalPoints", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= فرم افزودن سوال جدید =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: lightPinkBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryPink.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add New Question", style: TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 12),

                  // انتخاب نوع سوال
                  DropdownButtonFormField<String>(
                    initialValue: selectedQuestionType,
                    dropdownColor: surfaceWhite,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'multiple_choice', child: Text("Multiple Choice (4 Options)")),
                      DropdownMenuItem(value: 'descriptive', child: Text("Descriptive (Written)")),
                    ],
                    onChanged: (val) => setState(() => selectedQuestionType = val!),
                  ),
                  const SizedBox(height: 12),

                  // متن سوال
                  TextField(
                    controller: _textController,
                    maxLines: 2,
                    style: const TextStyle(color: textDark, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Enter question text...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: surfaceWhite,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // اگر نوع سوال چهارگزینه‌ای بود، فیلد گزینه‌ها نمایش داده شود
                  if (selectedQuestionType == 'multiple_choice') ...[
                    _buildInput(_optAController, "Option A"),
                    const SizedBox(height: 8),
                    _buildInput(_optBController, "Option B"),
                    const SizedBox(height: 8),
                    _buildInput(_optCController, "Option C"),
                    const SizedBox(height: 8),
                    _buildInput(_optDController, "Option D"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text("Correct Option:", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: selectedCorrectOption,
                          dropdownColor: surfaceWhite,
                          style: const TextStyle(color: primaryPink, fontSize: 12, fontWeight: FontWeight.w900),
                          items: ['A', 'B', 'C', 'D'].map((opt) => DropdownMenuItem(value: opt, child: Text("Option $opt"))).toList(),
                          onChanged: (val) => setState(() => selectedCorrectOption = val!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // نمره سوال
                  TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Points",
                      labelStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: surfaceWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // دکمه ذخیره سوال
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
                      onPressed: isSubmitting ? null : _addQuestion,
                      child: Text(isSubmitting ? "Saving..." : "Save Question 💾", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // لیست سوالات موجود در بانک
            const Text("Current Inventory", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 12),

            questions.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: questions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      bool isMCQ = q.optionA != null && q.optionA != 'Descriptive';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${index + 1}.", style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 13)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.questionText, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(isMCQ ? "Type: Multiple Choice" : "Type: Descriptive", style: const TextStyle(color: textGrey, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  Text("${q.points} Points", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _deleteQuestion(q.id),
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
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder),
                    ),
                    child: const Text("No questions added yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: textDark, fontSize: 11),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textGrey, fontSize: 10),
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
      ),
    );
  }
}