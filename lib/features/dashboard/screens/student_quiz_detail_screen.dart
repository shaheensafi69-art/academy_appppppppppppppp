import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionItem {
  final String id;
  final String questionText;
  final int points;
  final String questionType; // "multiple_choice" یا "descriptive"
  final List<String> options; // لیست گزینه‌ها برای سوالات تستی

  QuestionItem({
    required this.id,
    required this.questionText,
    required this.points,
    required this.questionType,
    required this.options,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedOptions = [];
    if (json['options'] != null) {
      if (json['options'] is List) {
        parsedOptions = List<String>.from(json['options']);
      }
    }

    return QuestionItem(
      id: json['id'] ?? '',
      questionText: json['question_text'] ?? '',
      points: json['points'] ?? 10,
      questionType: json['question_type'] ?? 'descriptive',
      options: parsedOptions,
    );
  }
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
  
  // نگهداری پاسخ‌های دانشجو: برای تشریحی متن و برای تستی ایندکس یا متن گزینه انتخابی
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _selectedOptions = {};

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchExamData();
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
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
          .select("id, question_text, points, question_type, options")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      questions = (questionsData as List).map((q) {
        final item = QuestionItem.fromJson(q);
        if (item.questionType == 'descriptive') {
          _textControllers[item.id] = TextEditingController();
        }
        return item; // استاندارد نگاشت
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

    // بررسی تعداد سوالات بی‌پاسخ (چه تستی و چه تشریحی)
    int unanswered = questions.where((q) {
      if (q.questionType == 'multiple_choice') {
        return !_selectedOptions.containsKey(q.id) || _selectedOptions[q.id]!.isEmpty;
      } else {
        return (_textControllers[q.id]?.text.trim() ?? "").isEmpty;
      }
    }).length;

    if (unanswered > 0) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: surfaceWhite, // This line is not part of the change, but it's close to the target.
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: cardBorder, width: 1.5)),
          title: const Text("Unanswered Questions", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
          content: Text("You have $unanswered unanswered questions! Are you sure you want to submit?", style: const TextStyle(color: textGrey, fontSize: 11)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Submit", style: TextStyle(color: primaryPink, fontWeight: FontWeight.w900))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => isSubmitting = true);
    try {
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

      List<Map<String, dynamic>> answersArray = questions.map((q) {
        String answerText = "";
        if (q.questionType == 'multiple_choice') {
          answerText = _selectedOptions[q.id] ?? "No answer provided.";
        } else {
          answerText = _textControllers[q.id]?.text.trim().isNotEmpty == true ? _textControllers[q.id]!.text.trim() : "No answer provided.";
        }

        return {
          'attempt_id': attemptId,
          'question_id': q.id,
          'student_answer_text': answerText,
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("DISTRIBUTING EXAM PAPERS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (isSubmittedSuccessfully) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: lightPinkBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, size: 48, color: primaryPink),
                ),
                const SizedBox(height: 16),
                const Text("Paper Submitted!", style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("Your answers for ${quizInfo?['title']} have been securely saved. The instructor will review your paper shortly.", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Return to Exam Center", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(quizInfo?['title'] ?? 'Exam Paper', style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightPinkBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: primaryPink, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("Read each question carefully. Select the correct option for multiple-choice questions or type your detailed answer in the text boxes.", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold, height: 1.3)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final q = questions[index];
                bool isMultipleChoice = q.questionType == 'multiple_choice';

                return Container(
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
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(color: lightPinkBg, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text("${index + 1}", style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                            child: Text("${q.points} Pts", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(q.questionText, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13, height: 1.3)),
                      const SizedBox(height: 14),

                      // رندر هوشمند گزینه چهارجوابی یا فیلد متن تشریحی
                      if (isMultipleChoice && q.options.isNotEmpty) ...[
                        ...q.options.map((option) {
                          bool isSelected = _selectedOptions[q.id] == option;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOptions[q.id] = option;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? lightPinkBg : cardBorder.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 1.5 : 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? primaryPink : textGrey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: isSelected ? primaryPink : textDark,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ] else ...[
                        TextField(
                          controller: _textControllers[q.id],
                          maxLines: 4,
                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Type your detailed answer here...",
                            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                            filled: true,
                            fillColor: cardBorder.withOpacity(0.5),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                        ),
                      ],
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
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSubmitting ? null : _handleSubmitExam,
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text("SUBMIT EXAM PAPER 🚀", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}