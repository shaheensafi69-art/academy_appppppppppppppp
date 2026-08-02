import 'dart:ui';
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

  // پالت رنگی لایت (سفید صدفی و صورتی غلیظ خالص)
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
          .select("id, question_text, points")
          .eq("quiz_id", widget.quizId)
          .order("created_at", ascending: true);

      questions = List<Map<String, dynamic>>.from(qData);

      final attemptsData = await supabase
          .from("quiz_attempts")
          .select("id, student_id, score, is_passed, status, letter_grade, attempted_at")
          .eq("quiz_id", widget.quizId)
          .order("attempted_at", ascending: false);

      if ((attemptsData as List).isNotEmpty) {
        final studentIds = attemptsData.map((a) => a['student_id']).toList();
        final profilesData = await supabase
            .from("profiles")
            .select("id, first_name, last_name, email, avatar_url")
            .inFilter("id", studentIds);

        attempts = attemptsData.map((attempt) {
          final p = (profilesData as List?)?.firstWhere(
            (prof) => prof['id'] == attempt['student_id'],
            orElse: () => null,
          );

          return QuizAttemptItem(
            id: attempt['id'] ?? '',
            studentId: attempt['student_id'] ?? '',
            score: (attempt['score'] ?? 0).toDouble(),
            isPassed: attempt['is_passed'] ?? false,
            status: attempt['status'] ?? 'pending_review',
            letterGrade: attempt['letter_grade'],
            attemptedAt: attempt['attempted_at'] ?? '',
            firstName: p?['first_name'] ?? 'Unknown',
            lastName: p?['last_name'] ?? 'Student',
            email: p?['email'] ?? '',
            avatarUrl: p?['avatar_url'],
          );
        }).toList();
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
    if (score == 100) return "A+";
    if (score >= 90) return "A";
    if (score >= 80) return "B";
    if (score >= 70) return "C";
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            physics: const BouncingScrollPhysics(),
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
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: lightPinkBg,
                                      backgroundImage: att.avatarUrl != null ? NetworkImage(att.avatarUrl!) : null,
                                      child: att.avatarUrl == null ? Text(att.firstName[0], style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold)) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${att.firstName} ${att.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
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
                                  ],
                                ),
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

          // ================= مودال تصحیح برگه آزمون =================
          if (selectedAttempt != null)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
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
                    Text("Evaluate: ${selectedAttempt!.firstName} ${selectedAttempt!.lastName}",
                        style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 14),
                    isLoadingDetails
                        ? const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: primaryPink)))
                        : SizedBox(
                            height: 280,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: questions.length,
                              itemBuilder: (context, idx) {
                                final q = questions[idx];
                                final ans = studentAnswers.firstWhere((a) => a['question_id'] == q['id'], orElse: () => {});
                                int currentScore = gradingScores[q['id']] ?? 0;

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
                                      Text("Q${idx + 1}: ${q['question_text']}",
                                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 6),
                                      Text("Answer: ${ans['student_answer_text'] ?? 'No Answer'}",
                                          style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text("Points (Max ${q['points']}): ", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                          SizedBox(
                                            width: 70,
                                            height: 36,
                                            child: TextField(
                                              keyboardType: TextInputType.number,
                                              controller: TextEditingController(text: currentScore.toString()),
                                              onChanged: (val) {
                                                int v = int.tryParse(val) ?? 0;
                                                if (v > (q['points'] as int)) v = q['points'];
                                                gradingScores[q['id']] = v;
                                              },
                                              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: surfaceWhite,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                                              ),
                                            ),
                                          ),
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
        ],
      ),
    );
  }
}