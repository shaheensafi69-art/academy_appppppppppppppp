import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_quiz_detail_screen.dart'; // صفحه‌ای که در مرحله بعد می‌سازیم

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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("🎯", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Examination Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Take your academic descriptive exams and track your official grades.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= باکس‌های آمار =================
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text("🎯", style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TOTAL EXAMS", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.indigoAccent)),
                          Text("${stats['total']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text("✅", style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("PASSED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                          Text("${stats['passed']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ================= تب‌های فیلتر =================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterTab("all", "All Exams", "📋"),
                const SizedBox(width: 8),
                _buildFilterTab("pending", "To Do", "⏳"),
                const SizedBox(width: 8),
                _buildFilterTab("completed", "Attempted", "🎓"),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= لیست کویزها =================
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
              : filteredQuizzes.isNotEmpty
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
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: quiz.status == "graded" && (quiz.isPassed ?? false)
                                  ? Colors.green.withOpacity(0.2)
                                  : quiz.status == "graded" && !(quiz.isPassed ?? true)
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.amber.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                                    child: Text(quiz.courseName, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: quiz.quizType == 'chance' ? Colors.red.withOpacity(0.15) : Colors.indigo.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text("${quiz.quizType.toUpperCase()} EXAM", style: TextStyle(color: quiz.quizType == 'chance' ? Colors.redAccent : Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(quiz.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  quiz.status == "graded"
                                      ? Row(
                                          children: [
                                            Text("Score: ${quiz.score ?? 0}", style: TextStyle(color: (quiz.isPassed ?? false) ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            if (quiz.letterGrade != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                                child: Text("Grade ${quiz.letterGrade}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        )
                                      : quiz.status == "pending_review"
                                          ? const Text("Awaiting Instructor Grading", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                          : Text("Pass Mark: ${quiz.passingScore} / 100", style: const TextStyle(color: Colors.grey, fontSize: 10)),

                                  quiz.status == "pending"
                                      ? ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StudentQuizDetailScreen(quizId: quiz.id)),
                                            ).then((_) => _fetchQuizzes());
                                          },
                                          child: const Text("Start Exam", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("Locked 🔒", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: const Text("No quizzes found matching this filter.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, String emoji) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purpleAccent : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}