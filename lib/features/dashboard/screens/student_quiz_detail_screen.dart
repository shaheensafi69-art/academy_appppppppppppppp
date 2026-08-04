import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionItem {
  final String id;
  final String questionText;
  final int points;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;

  QuestionItem({
    required this.id,
    required this.questionText,
    required this.points,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      id: json['id']?.toString() ?? '',
      questionText: json['question_text'] ?? '',
      points: json['points'] ?? 10,
      optionA: json['option_a'],
      optionB: json['option_b'],
      optionC: json['option_c'],
      optionD: json['option_d'],
    );
  }

  // تشخیص دقیق نوع سوال بر اساس منطق دیتابیس شما
  bool get isDescriptive {
    // اگر متن سوال شامل کلمه Descriptive باشد یا تمام گزینه‌ها خالی یا حاوی کلمه Descriptive باشند
    bool textHasDescriptive = questionText.toLowerCase().contains('descriptive');
    bool optionsAreEmptyOrDescriptive = 
        (optionA == null || optionA!.trim().isEmpty || optionA!.toLowerCase().contains('descriptive')) &&
        (optionB == null || optionB!.trim().isEmpty || optionB!.toLowerCase().contains('descriptive')) &&
        (optionC == null || optionC!.trim().isEmpty || optionC!.toLowerCase().contains('descriptive')) &&
        (optionD == null || optionD!.trim().isEmpty || optionD!.toLowerCase().contains('descriptive'));

    return textHasDescriptive || optionsAreEmptyOrDescriptive;
  }

  bool get isMultipleChoice => !isDescriptive;

  List<String> get availableOptions {
    if (isDescriptive) return [];
    List<String> opts = [];
    if (optionA != null && optionA!.trim().isNotEmpty) opts.add(optionA!);
    if (optionB != null && optionB!.trim().isNotEmpty) opts.add(optionB!);
    if (optionC != null && optionC!.trim().isNotEmpty) opts.add(optionC!);
    if (optionD != null && optionD!.trim().isNotEmpty) opts.add(optionD!);
    return opts;
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
  
  // نگهداری پاسخ‌های دانشجو (هم تستی و هم تشریحی)
  final Map<String, String> _selectedAnswers = {};
  
  // تایمر معکوس آزمون (۱۵ دقیقه)
  Timer? _examTimer;
  int _secondsLeft = 15 * 60;

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
    _startTimer();
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _examTimer?.cancel();
        _handleSubmitExam(isAutoSubmit: true);
      }
    });
  }

  String get _formattedTime {
    int minutes = _secondsLeft ~/ 60;
    int seconds = _secondsLeft % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
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
          .select("id, question_text, points, option_a, option_b, option_c, option_d")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      questions = (questionsData as List).map((q) => QuestionItem.fromJson(q)).toList();
    } catch (e) {
      debugPrint("Failed to load exam paper: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSubmitExam({bool isAutoSubmit = false}) async {
    final user = supabase.auth.currentUser;
    if (user == null || quizInfo == null) return;

    if (!isAutoSubmit) {
      int unanswered = questions.where((q) => !_selectedAnswers.containsKey(q.id) || _selectedAnswers[q.id]!.trim().isEmpty).length;
      if (unanswered > 0) {
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: cardBorder, width: 1.5)),
            title: const Text("Unanswered Questions", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
            content: Text("You have $unanswered skipped questions! Are you sure you want to submit?", style: const TextStyle(color: textGrey, fontSize: 11)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Review", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Submit", style: TextStyle(color: primaryPink, fontWeight: FontWeight.w900))),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }

    setState(() => isSubmitting = true);
    _examTimer?.cancel();

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
        return {
          'attempt_id': attemptId,
          'question_id': q.id,
          'student_answer_text': _selectedAnswers[q.id]?.trim().isNotEmpty == true ? _selectedAnswers[q.id]! : "Skipped / No answer",
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
              Text("PREPARING EXAM PAPER...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (isSubmittedSuccessfully) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: SafeArea(
          child: Center(
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
                  const Text("Paper Submitted Successfully!", style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text("Your answers for ${quizInfo?['title']} have been saved. Your instructor will grade your exam soon.", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
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
        ),
      );
    }

    int answeredCount = _selectedAnswers.values.where((v) => v.trim().isNotEmpty).length;
    double progressValue = questions.isNotEmpty ? answeredCount / questions.length : 0.0;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: Column(
          children: [
            // هدر بالای صفحه شامل عنوان امتحان، تایمر و نوار پیشرفت
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceWhite,
                border: Border(bottom: BorderSide(color: cardBorder, width: 1.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.close_rounded, color: textDark, size: 18),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            quizInfo?['title'] ?? 'Exam Paper',
                            style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_rounded, color: primaryPink, size: 14),
                            const SizedBox(width: 4),
                            Text(_formattedTime, style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Answered: $answeredCount / ${questions.length}", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                      const Text("Auto Saved • Smart Exam", style: TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: cardBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(primaryPink),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // لیست سوالات آزمون با تشخیص هوشمند تستی یا تشریحی
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                itemCount: questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final q = questions[index];
                  bool isDescriptive = q.isDescriptive;
                  List<String> options = q.availableOptions;

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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDescriptive ? Colors.orange.withOpacity(0.1) : Colors.indigo.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isDescriptive ? "Descriptive" : "Multiple Choice",
                                    style: TextStyle(
                                      color: isDescriptive ? Colors.orange[800] : Colors.indigo,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                  child: Text("${q.points} Pts", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(q.questionText, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13, height: 1.3)),
                        const SizedBox(height: 14),

                        // رندر کردن تکست‌باکس تشریحی یا گزینه‌های تستی بر اساس نوع سوال
                        if (isDescriptive) ...[
                          TextField(
                            onChanged: (val) => _selectedAnswers[q.id] = val,
                            maxLines: 5,
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: "Write your descriptive answer here...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                              filled: true,
                              fillColor: cardBorder.withOpacity(0.5),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: cardBorder, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: primaryPink, width: 1.5),
                              ),
                            ),
                          ),
                        ] else ...[
                          ...options.map((option) {
                            bool isSelected = _selectedAnswers[q.id] == option;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAnswers[q.id] = option),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? lightPinkBg : cardBorder.withOpacity(0.4),
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
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // دکمه نهایی‌سازی امتحان در پایین صفحه
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceWhite,
                border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isSubmitting ? null : () => _handleSubmitExam(),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("SUBMIT EXAM PAPER 🚀", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}