import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_quiz_detail_screen.dart';

class QuizItem {
  final String id;
  final String courseName;
  final String title;
  final String quizType; // 'regular' or 'chance'
  final int passingScore;
  final String status; // "pending", "pending_review", "graded"
  final double? score;
  final String? letterGrade;
  final bool? isPassed;
  final String? attemptedAt;

  QuizItem({
    required this.id,
    required this.courseName,
    required this.title,
    required this.quizType,
    required this.passingScore,
    required this.status,
    this.score,
    this.letterGrade,
    this.isPassed,
    this.attemptedAt,
  });
}

class StudentQuizzesScreen extends StatefulWidget {
  const StudentQuizzesScreen({super.key});

  @override
  State<StudentQuizzesScreen> createState() => _StudentQuizzesScreenState();
}

class _StudentQuizzesScreenState extends State<StudentQuizzesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<QuizItem> quizzes = [];
  String filter = "all"; // "all", "pending", "completed"

  Map<String, int> stats = {
    'total': 0,
    'passed': 0,
  };

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
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final classStudents = await supabase
          .from("class_students")
          .select("class_group_id")
          .eq("student_id", userId);

      if ((classStudents as List).isEmpty) {
        setState(() => isLoading = false);
        return;
      }
      final classIds = classStudents.map((cs) => cs['class_group_id']).toList();

      final classGroups = await supabase
          .from("class_groups")
          .select("id, class_name, course_id")
          .inFilter("id", classIds);

      final courseIds = (classGroups as List?)?.map((cg) => cg['course_id']).toList() ?? [];
      final courses = await supabase
          .from("courses")
          .select("id, title")
          .inFilter("id", courseIds);

      final allQuizzes = await supabase
          .from("quizzes")
          .select("id, title, passing_score, quiz_type, class_group_id")
          .inFilter("class_group_id", classIds)
          .eq("is_active", true) 
          .order("created_at", ascending: false);

      final attempts = await supabase
          .from("quiz_attempts")
          .select("quiz_id, score, is_passed, status, letter_grade, attempted_at")
          .eq("student_id", userId);

      int passedCount = 0;
      List<QuizItem> formatted = [];

      for (var quiz in (allQuizzes as List)) {
        final cg = (classGroups as List?)?.firstWhere((c) => c['id'] == quiz['class_group_id'], orElse: () => null);
        final crs = (courses as List?)?.firstWhere((c) => c['id'] == cg?['course_id'], orElse: () => null);
        final courseName = crs?['title'] ?? cg?['class_name'] ?? "Premium Course";

        final attempt = (attempts as List?)?.firstWhere((a) => a['quiz_id'] == quiz['id'], orElse: () => null);

        String currentStatus = "pending";
        if (attempt != null) {
          currentStatus = attempt['status'] == "graded" ? "graded" : "pending_review";
          if (attempt['status'] == "graded" && (attempt['is_passed'] ?? false)) {
            passedCount++;
          }
        }

        formatted.add(QuizItem(
          id: quiz['id'],
          courseName: courseName,
          title: quiz['title'] ?? '',
          quizType: quiz['quiz_type'] ?? 'regular',
          passingScore: quiz['passing_score'] ?? 50,
          status: currentStatus,
          score: attempt?['score']?.toDouble(),
          letterGrade: attempt?['letter_grade'],
          isPassed: attempt?['is_passed'],
          attemptedAt: attempt?['attempted_at'],
        ));
      }

      setState(() {
        quizzes = formatted;
        stats = {
          'total': formatted.length,
          'passed': passedCount,
        };
      });
    } catch (e) {
      debugPrint("Error fetching quizzes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<QuizItem> get filteredQuizzes {
    return quizzes.where((quiz) {
      if (filter == "pending") return quiz.status == "pending";
      if (filter == "completed") return quiz.status != "pending";
      return true;
    }).toList();
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
              Text("LOADING EXAMS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= هدر صفحه =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightPinkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: primaryPink, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Examination Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        const SizedBox(height: 3),
                        const Text("Take your academic descriptive exams and track your official grades.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= باکس‌های آمار =================
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.assignment_rounded, color: primaryPink, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TOTAL EXAMS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text("${stats['total']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("PASSED", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text("${stats['passed']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ================= تب‌های فیلتر =================
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterTab("all", "All Exams", Icons.list_alt_rounded),
                  const SizedBox(width: 10),
                  _buildFilterTab("pending", "To Do", Icons.hourglass_top_rounded),
                  const SizedBox(width: 10),
                  _buildFilterTab("completed", "Attempted", Icons.done_all_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= لیست کویزها =================
            filteredQuizzes.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredQuizzes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final quiz = filteredQuizzes[index];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: quiz.status == "graded" && (quiz.isPassed ?? false)
                                ? Colors.green.withOpacity(0.3)
                                : quiz.status == "graded" && !(quiz.isPassed ?? true)
                                    ? Colors.red.withOpacity(0.3)
                                    : cardBorder,
                            width: 1.5,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                  child: Text(quiz.courseName, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: quiz.quizType == 'chance' ? Colors.red.withOpacity(0.12) : lightPinkBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text("${quiz.quizType.toUpperCase()} EXAM", style: TextStyle(color: quiz.quizType == 'chance' ? Colors.redAccent : primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(quiz.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                quiz.status == "graded"
                                    ? Row(
                                        children: [
                                          Text("Score: ${quiz.score ?? 0}", style: TextStyle(color: (quiz.isPassed ?? false) ? Colors.green.shade700 : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                                          const SizedBox(width: 8),
                                          if (quiz.letterGrade != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(6)),
                                              child: Text("Grade ${quiz.letterGrade}", style: const TextStyle(color: textDark, fontSize: 9, fontWeight: FontWeight.w900)),
                                            ),
                                        ],
                                      )
                                    : quiz.status == "pending_review"
                                        ? const Text("Awaiting Instructor Grading", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900))
                                        : Text("Pass Mark: ${quiz.passingScore} / 100", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),

                                quiz.status == "pending"
                                    ? ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: lightPinkBg,
                                          foregroundColor: primaryPink,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => StudentQuizDetailScreen(quizId: quiz.id)),
                                          ).then((_) => _fetchQuizzes());
                                        },
                                        child: const Text("Start Exam", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cardBorder,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text("Locked", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
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
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No quizzes found matching this filter.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, IconData icon) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryPink : lightPinkBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryPink : cardBorder, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: primaryPink.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : primaryPink),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : textDark, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}