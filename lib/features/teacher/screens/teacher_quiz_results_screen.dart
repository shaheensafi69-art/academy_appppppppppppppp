import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizAttemptItem {
  final String id;
  final String studentId;
  final double score;
  final bool isPassed;
  final String status;
  final String? letterGrade;
  final String attemptedAt;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;

  QuizAttemptItem({
    required this.id,
    required this.studentId,
    required this.score,
    required this.isPassed,
    required this.status,
    this.letterGrade,
    required this.attemptedAt,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
  });
}

class TeacherQuizResultsScreen extends StatefulWidget {
  final String quizId;
  const TeacherQuizResultsScreen({super.key, required this.quizId});

  @override
  State<TeacherQuizResultsScreen> createState() => _TeacherQuizResultsScreenState();
}

class _TeacherQuizResultsScreenState extends State<TeacherQuizResultsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? quizInfo;
  List<QuizAttemptItem> attempts = [];

  // مودال تصحیح
  QuizAttemptItem? selectedAttempt;
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> studentAnswers = [];
  final Map<String, int> gradingScores = {};
  bool isLoadingDetails = false;
  bool isSubmittingGrade = false;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchResultsData();
  }

  Future<void> _fetchResultsData() async {
    setState(() => isLoading = true);
    try {
      final quizData = await supabase
          .from("quizzes")
          .select("title, passing_score, quiz_type")
          .eq("id", widget.quizId)
          .single();

      quizInfo = quizData;

      final qData = await supabase
          .from("quiz_questions")
          .select("*")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      questions = List<Map<String, dynamic>>.from(qData);

      // 🛠 اصلاح کوئری برای دریافت مستقیم اطلاعات پروفایل دانشجو از طریق رابطه (Join)
      final attemptsData = await supabase
          .from("quiz_attempts")
          .select("id, student_id, score, is_passed, status, letter_grade, attempted_at, profiles(first_name, last_name, email, avatar_url)")
          .eq("quiz_id", widget.quizId)
          .order("attempted_at", ascending: false);

      if ((attemptsData as List).isNotEmpty) {
        attempts = attemptsData.map((attempt) {
          final profileObj = attempt['profiles'];
          final firstName = profileObj is Map ? (profileObj['first_name'] ?? 'Unknown') : 'Unknown';
          final lastName = profileObj is Map ? (profileObj['last_name'] ?? 'Student') : 'Student';
          final email = profileObj is Map ? (profileObj['email'] ?? '') : '';
          final avatarUrl = profileObj is Map ? profileObj['avatar_url'] : null;

          return QuizAttemptItem(
            id: attempt['id'] ?? '',
            studentId: attempt['student_id'] ?? '',
            score: (attempt['score'] ?? 0).toDouble(),
            isPassed: attempt['is_passed'] ?? false,
            status: attempt['status'] ?? 'pending_review',
            letterGrade: attempt['letter_grade'],
            attemptedAt: attempt['attempted_at'] ?? '',
            firstName: firstName,
            lastName: lastName,
            email: email,
            avatarUrl: avatarUrl,
          );
        }).toList();
      } else {
        attempts = [];
      }
    } catch (e) {
      debugPrint("Error loading results: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _openGradingModal(QuizAttemptItem attempt) async {
    setState(() {
      selectedAttempt = attempt;
      isLoadingDetails = true;
      gradingScores.clear();
    });

    try {
      final answersData = await supabase
          .from("quiz_student_answers")
          .select("*")
          .eq("attempt_id", attempt.id);

      studentAnswers = List<Map<String, dynamic>>.from(answersData);
      for (var ans in studentAnswers) {
        gradingScores[ans['question_id']] = ans['points_earned'] ?? 0;
      }
    } catch (e) {
      debugPrint("Failed to load student answers: $e");
    } finally {
      if (mounted) setState(() => isLoadingDetails = false);
    }
  }

  String _calculateLetterGrade(double score) {
    if (score >= 95 && score <= 100) return "A+";
    if (score >= 85 && score < 95) return "A";
    if (score >= 75 && score < 85) return "B";
    if (score >= 70 && score < 75) return "C";
    return "Chance";
  }

  Future<void> _saveGrades() async {
    if (selectedAttempt == null || quizInfo == null) return;

    int totalScore = 0;
    gradingScores.forEach((_, val) => totalScore += val);

    final passingScore = quizInfo?['passing_score'] ?? 70;
    final bool isPassed = totalScore >= passingScore;
    final String letterGrade = _calculateLetterGrade(totalScore.toDouble());

    setState(() => isSubmittingGrade = true);
    try {
      for (var ans in studentAnswers) {
        final earned = gradingScores[ans['question_id']] ?? 0;
        await supabase.from("quiz_student_answers").update({
          'points_earned': earned,
          'is_correct': earned > 0,
        }).eq("id", ans['id']);
      }

      await supabase.from("quiz_attempts").update({
        'score': totalScore,
        'is_passed': isPassed,
        'status': 'graded',
        'letter_grade': letterGrade,
      }).eq("id", selectedAttempt!.id);

      setState(() {
        attempts = attempts.map((a) {
          if (a.id == selectedAttempt!.id) {
            return QuizAttemptItem(
              id: a.id, studentId: a.studentId, score: totalScore.toDouble(),
              isPassed: isPassed, status: 'graded', letterGrade: letterGrade,
              attemptedAt: a.attemptedAt, firstName: a.firstName, lastName: a.lastName,
              email: a.email, avatarUrl: a.avatarUrl,
            );
          }
          return a;
        }).toList();
        selectedAttempt = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Grades and feedback submitted successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Failed to save grade: $e");
    } finally {
      if (mounted) setState(() => isSubmittingGrade = false);
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
        title: Text(quizInfo?['title'] ?? 'Results', style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Student Submissions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 12),

                      attempts.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attempts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final att = attempts[index];
                                bool isGraded = att.status == 'graded';

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isGraded ? Colors.green.withOpacity(0.3) : Colors.amber.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: lightPinkBg,
                                              backgroundImage: att.avatarUrl != null ? NetworkImage(att.avatarUrl!) : null,
                                              child: att.avatarUrl == null ? Text(att.firstName.isNotEmpty ? att.firstName[0] : 'S', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold)) : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("${att.firstName} ${att.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    isGraded ? "Score: ${att.score} | Grade: ${att.letterGrade}" : "Pending Review",
                                                    style: TextStyle(
                                                      color: isGraded ? Colors.green.shade700 : Colors.amber.shade800,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isGraded ? cardBorder : primaryPink,
                                          foregroundColor: isGraded ? textDark : Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: () => _openGradingModal(att),
                                        child: Text(isGraded ? "Review" : "Evaluate", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
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
                              child: const Text("No submissions found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                    ],
                  ),
                ),
              ),
            ),

            // ================= مودال تصحیح برگه آزمون (ریسپانسیو و فیکس‌شده) =================
            if (selectedAttempt != null)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text("Evaluate: ${selectedAttempt!.firstName} ${selectedAttempt!.lastName}",
                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                              onPressed: () => setState(() => selectedAttempt = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        isLoadingDetails
                            ? const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: primaryPink)))
                            : SizedBox(
                                height: 320,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: questions.length,
                                  itemBuilder: (context, idx) {
                                    final q = questions[idx];
                                    final ans = studentAnswers.firstWhere((a) => a['question_id'] == q['id'], orElse: () => {});
                                    int maxPts = q['points'] ?? 10;
                                    int currentScore = gradingScores[q['id']] ?? 0;
                                    bool isDescriptive = q['option_a'] == 'Descriptive';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: cardBorder.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: cardBorder, width: 1.5),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text("Q${idx + 1}: ${q['question_text']}",
                                                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(6)),
                                                child: Text("Max: $maxPts pts", style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text("Student Answer: ${ans['student_answer_text'] ?? 'No Answer'}",
                                              style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 10),

                                          // اگر تشریحی باشد دکمه تیک و ضربدر، اگر چهارجوبه‌ای باشد سیستم اتوماتیک
                                          isDescriptive
                                              ? Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text("Teacher Evaluation:", style: TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    Row(
                                                      children: [
                                                        // دکمه غلط / ضربدر ❌
                                                        InkWell(
                                                          onTap: () => setState(() => gradingScores[q['id']] = 0),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: currentScore == 0 ? Colors.red.withOpacity(0.2) : surfaceWhite,
                                                              borderRadius: BorderRadius.circular(10),
                                                              border: Border.all(color: currentScore == 0 ? Colors.red : cardBorder, width: 1.5),
                                                            ),
                                                            child: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        // دکمه درست / تیک ✔️
                                                        InkWell(
                                                          onTap: () => setState(() => gradingScores[q['id']] = maxPts),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: currentScore > 0 ? Colors.green.withOpacity(0.2) : surfaceWhite,
                                                              borderRadius: BorderRadius.circular(10),
                                                              border: Border.all(color: currentScore > 0 ? Colors.green : cardBorder, width: 1.5),
                                                            ),
                                                            child: const Icon(Icons.check_rounded, color: Colors.green, size: 18),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text("Auto Graded (MCQ):", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    Text("$currentScore / $maxPts Pts", style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900)),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(foregroundColor: textGrey),
                                onPressed: () => setState(() => selectedAttempt = null),
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
                                onPressed: isSubmittingGrade ? null : _saveGrades,
                                child: Text(isSubmittingGrade ? "Saving..." : "Submit Grade", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}