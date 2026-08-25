import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_quiz_detail_screen.dart';

class QuizItem {
  final String id;
  final String courseName;
  final String title;
  final String quizType; 
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

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
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
      final userId = user?.id;

      if (userId == null) {
        setState(() => isLoading = false);
        return;
      }

      final classStudentsRes = await supabase
          .from("class_students")
          .select("class_group_id")
          .eq("student_id", userId);

      final List<dynamic> classStudents = classStudentsRes as List<dynamic>? ?? [];

      if (classStudents.isEmpty) {
        setState(() {
          quizzes = [];
          isLoading = false;
        });
        return;
      }

      final classIds = classStudents.map((cs) => cs['class_group_id']).toList();

      final classGroupsRes = await supabase
          .from("class_groups")
          .select("id, class_name, course_id")
          .inFilter("id", classIds);

      final List<dynamic> classGroups = classGroupsRes as List<dynamic>? ?? [];

      if (classGroups.isEmpty) {
        setState(() {
          quizzes = [];
          isLoading = false;
        });
        return;
      }

      final courseIds = classGroups.map((cg) => cg['course_id']).toList();

      final coursesRes = await supabase
          .from("courses")
          .select("id, title")
          .inFilter("id", courseIds);

      final List<dynamic> courses = coursesRes as List<dynamic>? ?? [];

      final quizzesRes = await supabase
          .from("quizzes")
          .select("id, title, passing_score, quiz_type, class_group_id")
          .inFilter("class_group_id", classIds)
          .order("created_at", ascending: false);

      final List<dynamic> allQuizzes = quizzesRes as List<dynamic>? ?? [];

      // واکشی نتایج دانشجو از جدول quiz_attempts برای تشخیص پاس یا چانس شدن
      final attemptsRes = await supabase
          .from("quiz_attempts")
          .select("quiz_id, score, is_passed, status, letter_grade, attempted_at")
          .eq("student_id", userId);

      final List<dynamic> attempts = attemptsRes as List<dynamic>? ?? [];

      int passedCount = 0;
      List<QuizItem> formatted = [];

      for (var quiz in allQuizzes) {
        dynamic cg;
        try {
          cg = classGroups.firstWhere((c) => c['id'] == quiz['class_group_id']);
        } catch (_) {
          cg = null;
        }

        dynamic crs;
        try {
          crs = courses.firstWhere((c) => c['id'] == cg?['course_id']);
        } catch (_) {
          crs = null;
        }

        final courseName = crs?['title'] ?? cg?['class_name'] ?? "Shopify Masterclass";

        dynamic attempt;
        try {
          attempt = attempts.firstWhere((a) => a['quiz_id'] == quiz['id']);
        } catch (_) {
          attempt = null;
        }

        String currentStatus = "pending";
        if (attempt != null) {
          currentStatus = attempt['status'] == "graded" ? "graded" : "pending_review";
          // بررسی دقیق فیلد is_passed از جدول quiz_attempts برای شمارش تعداد پاس شده‌ها بالا در بخش PASSED
          if (attempt['is_passed'] == true) {
            passedCount++;
          }
        }

        formatted.add(QuizItem(
          id: quiz['id']?.toString() ?? '',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Examination Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Take your academic exams and track official grades.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // بخش آمار بالا (Total Exams و Passed) که تعداد امتحانات پاس شده را دقیقاً نشان می‌دهد
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("TOTAL EXAMS", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                const SizedBox(height: 2),
                                Text("${stats['total']}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("PASSED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                const SizedBox(height: 2),
                                Text("${stats['passed']}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _buildFilterTab("all", "All", Icons.list_alt_rounded)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterTab("pending", "To Do", Icons.hourglass_top_rounded)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterTab("completed", "Attempted", Icons.done_all_rounded)),
                ],
              ),
              const SizedBox(height: 16),

              filteredQuizzes.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredQuizzes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                      child: Text(quiz.courseName, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: quiz.quizType == 'chance' ? Colors.red.withOpacity(0.12) : lightPinkBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text("${quiz.quizType.toUpperCase()} EXAM", style: TextStyle(color: quiz.quizType == 'chance' ? Colors.redAccent : primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(quiz.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: quiz.status == "graded"
                                        ? Row(
                                            children: [
                                              Text(
                                                (quiz.isPassed ?? false) ? "Status: Passed ✅" : "Status: Chance (Failed) ❌",
                                                style: TextStyle(
                                                  color: (quiz.isPassed ?? false) ? Colors.green.shade700 : Colors.redAccent,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (quiz.letterGrade != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(6)),
                                                  child: Text("Grade ${quiz.letterGrade}", style: const TextStyle(color: textDark, fontSize: 8, fontWeight: FontWeight.w900)),
                                                ),
                                            ],
                                          )
                                        : quiz.status == "pending_review"
                                            ? const Text("Awaiting Grading", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)
                                            : Text("Pass Mark: ${quiz.passingScore} / 100", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  quiz.status == "pending"
                                      ? ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: lightPinkBg,
                                            foregroundColor: primaryPink,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StudentQuizDetailScreen(quizId: quiz.id)),
                                            ).then((_) => _fetchQuizzes());
                                          },
                                          child: const Text("Start Exam", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: cardBorder,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("Completed", style: TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
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
                      child: const Text("No exams available right now.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, IconData icon) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryPink : lightPinkBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryPink : cardBorder, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: primaryPink.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : primaryPink),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: isSelected ? Colors.white : textDark, fontSize: 9, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}