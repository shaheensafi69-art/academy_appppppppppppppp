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

      if ((myClasses as List).isEmpty) {
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
                colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.track_changes_rounded, color: primaryPink, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Exam Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        SizedBox(height: 3),
                        Text("Design exams, manage tests, and grade papers.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Deploy", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateQuizScreen()))
                        .then((_) => _fetchTeacherQuizzes());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= فیلتر تب‌ها =================
          Row(
            children: ['all', 'regular', 'chance'].map((tab) {
              bool isSel = filterType == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => filterType = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSel ? primaryPink : cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? primaryPink : cardBorder, width: 1.5),
                    ),
                    child: Text(
                      tab.toUpperCase(),
                      style: TextStyle(
                        color: isSel ? Colors.white : textDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ================= لیست کوئیزها =================
          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : filtered.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final quiz = filtered[index];
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                    child: Text(quiz.courseName.toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                  GestureDetector(
                                    onTap: () => _toggleStatus(quiz.id, quiz.isActive),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: quiz.isActive ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        quiz.isActive ? "● Live" : "○ Draft",
                                        style: TextStyle(
                                          color: quiz.isActive ? Colors.green.shade700 : textGrey,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(quiz.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Pass Mark: ${quiz.passingScore}% | Type: ${quiz.quizType.toUpperCase()}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                              if (quiz.pendingReviews > 0) ...[
                                const SizedBox(height: 8),
                                Text("⏳ ${quiz.pendingReviews} Papers to Grade", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900)),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textDark,
                                        side: const BorderSide(color: cardBorder, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherQuizQuestionsScreen(quizId: quiz.id)));
                                      },
                                      child: const Text("Questions", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: quiz.pendingReviews > 0 ? Colors.amber : primaryPink,
                                        foregroundColor: quiz.pendingReviews > 0 ? textDark : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherQuizResultsScreen(quizId: quiz.id)))
                                            .then((_) => _fetchTeacherQuizzes());
                                      },
                                      child: Text(quiz.pendingReviews > 0 ? "Grade Papers" : "Results", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                    ),
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
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.assignment_late_rounded, size: 36, color: textGrey),
                          SizedBox(height: 10),
                          Text("No Exams Deployed", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("No exams deployed yet.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}