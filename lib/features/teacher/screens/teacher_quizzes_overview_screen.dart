import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_quiz_screen.dart';
import 'teacher_quiz_results_screen.dart';
import 'teacher_quiz_questions_screen.dart';

class QuizOverviewItem {
  final String id;
  final String title;
  final String courseName;
  final int passingScore;
  final bool isActive;
  final String quizType;
  final int totalAttempts;
  final int pendingReviews;

  QuizOverviewItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.passingScore,
    required this.isActive,
    required this.quizType,
    required this.totalAttempts,
    required this.pendingReviews,
  });
}

class TeacherQuizzesOverviewScreen extends StatefulWidget {
  const TeacherQuizzesOverviewScreen({super.key});

  @override
  State<TeacherQuizzesOverviewScreen> createState() => _TeacherQuizzesOverviewScreenState();
}

class _TeacherQuizzesOverviewScreenState extends State<TeacherQuizzesOverviewScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<QuizOverviewItem> quizzes = [];
  String filterType = "all"; // "all" | "regular" | "chance"

  @override
  void initState() {
    super.initState();
    _fetchTeacherQuizzes();
  }

  Future<void> _fetchTeacherQuizzes() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final myClasses = await supabase
          .from("class_groups")
          .select("id, class_name, course_id")
          .eq("teacher_id", user.id);

      if (myClasses == null || (myClasses as List).isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final classIds = myClasses.map((c) => c['id']).toList();
      final courseIds = myClasses.map((c) => c['course_id']).where((id) => id != null).toSet().toList();

      final courses = await supabase
          .from("courses")
          .select("id, title")
          .inFilter("id", courseIds);

      final allQuizzes = await supabase
          .from("quizzes")
          .select("*")
          .inFilter("class_group_id", classIds)
          .order("created_at", ascending: false);

      final quizIds = (allQuizzes as List?)?.map((q) => q['id']).toList() ?? [];
      final allAttempts = quizIds.isNotEmpty
          ? await supabase.from("quiz_attempts").select("quiz_id, status").inFilter("quiz_id", quizIds)
          : [];

      if (allQuizzes != null) {
        quizzes = allQuizzes.map((quiz) {
          final classData = (myClasses as List).firstWhere((c) => c['id'] == quiz['class_group_id'], orElse: () => null);
          final courseData = (courses as List?)?.firstWhere((c) => c['id'] == classData?['course_id'], orElse: () => null);

          final quizAttempts = (allAttempts as List).where((a) => a['quiz_id'] == quiz['id']).toList();
          final pendingCount = quizAttempts.where((a) => a['status'] == "pending_review").length;

          return QuizOverviewItem(
            id: quiz['id'] ?? '',
            title: quiz['title'] ?? '',
            courseName: courseData?['title'] ?? classData?['class_name'] ?? 'Unknown Course',
            passingScore: quiz['passing_score'] ?? 70,
            isActive: quiz['is_active'] ?? false,
            quizType: quiz['quiz_type'] ?? 'regular',
            totalAttempts: quizAttempts.length,
            pendingReviews: pendingCount,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching exams: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    try {
      await supabase.from("quizzes").update({'is_active': !currentStatus}).eq("id", id);
      setState(() {
        quizzes = quizzes.map((q) => q.id == id ? QuizOverviewItem(
          id: q.id, title: q.title, courseName: q.courseName, passingScore: q.passingScore,
          isActive: !currentStatus, quizType: q.quizType, totalAttempts: q.totalAttempts, pendingReviews: q.pendingReviews,
        ) : q).toList();
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to toggle status.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = quizzes.where((q) => filterType == "all" ? true : q.quizType == filterType).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر صفحه
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.pink.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Text("🎯", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Exam Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        SizedBox(height: 2),
                        Text("Design exams, manage tests, and grade papers.", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Deploy", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateQuizScreen()))
                        .then((_) => _fetchTeacherQuizzes());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // فیلتر تب‌ها
          Row(
            children: ['all', 'regular', 'chance'].map((tab) {
              bool isSel = filterType == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => filterType = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tab.toUpperCase(), style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : filtered.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        quizOverviewItem(quiz) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(quiz.courseName, style: const TextStyle(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                  GestureDetector(
                                    onTap: () => _toggleStatus(quiz.id, quiz.isActive),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: quiz.isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(quiz.isActive ? "Live" : "Draft", style: TextStyle(color: quiz.isActive ? Colors.greenAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(quiz.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text("Pass Mark: ${quiz.passingScore}% | Type: ${quiz.quizType.toUpperCase()}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                              if (quiz.pendingReviews > 0) ...[
                                const SizedBox(height: 6),
                                Text("⏳ ${quiz.pendingReviews} Papers to Grade", style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherQuizQuestionsScreen(quizId: quiz.id)));
                                      },
                                      child: const Text("Questions", style: TextStyle(fontSize: 10)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: quiz.pendingReviews > 0 ? Colors.amber : Colors.pink,
                                        foregroundColor: quiz.pendingReviews > 0 ? Colors.black : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherQuizResultsScreen(quizId: quiz.id)))
                                            .then((_) => _fetchTeacherQuizzes());
                                      },
                                      child: Text(quiz.pendingReviews > 0 ? "Grade Papers" : "Results", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                        return quizOverviewItem(filtered[index]);
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF0a0a0f), borderRadius: BorderRadius.circular(18)),
                      child: const Text("No exams deployed yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}