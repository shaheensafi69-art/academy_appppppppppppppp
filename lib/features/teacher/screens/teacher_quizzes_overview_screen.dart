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

      // ۱. واکشی کلاس‌های متعلق به این استاد از جدول class_groups
      final myClasses = await supabase
          .from("class_groups")
          .select("id, class_name, course_id")
          .eq("teacher_id", user.id);

      if ((myClasses as List).isEmpty) {
        setState(() {
          quizzes = [];
          isLoading = false;
        });
        return;
      }

      final classIds = myClasses.map((c) => c['id']).toList();

      // ۲. واکشی کوئیزهای متعلق به این کلاس‌ها از جدول quizzes به همراه اطلاعات کلاس و دوره
      final allQuizzes = await supabase
          .from("quizzes")
          .select("*, class_groups(class_name, course_id, courses(title))")
          .inFilter("class_group_id", classIds)
          .order("created_at", ascending: false);

      if ((allQuizzes as List).isEmpty) {
        setState(() {
          quizzes = [];
          isLoading = false;
        });
        return;
      }

      final quizIds = allQuizzes.map((q) => q['id']).toList();

      // ۳. واکشی تلاش‌های دانشجویان از جدول quiz_attempts برای بررسی اوراق
      final allAttempts = quizIds.isNotEmpty
          ? await supabase.from("quiz_attempts").select("quiz_id, status").inFilter("quiz_id", quizIds)
          : <dynamic>[];

      quizzes = allQuizzes.map((quiz) {
        final classGroup = quiz['class_groups'];
        final courseObj = classGroup is Map ? classGroup['courses'] : null;
        
        String headerName = 'General Exam';
        if (courseObj is Map && courseObj['title'] != null) {
          headerName = courseObj['title'];
        } else if (classGroup is Map && classGroup['class_name'] != null) {
          headerName = classGroup['class_name'];
        }

        final quizAttempts = allAttempts.where((a) => a['quiz_id'] == quiz['id']).toList();
        final pendingCount = quizAttempts.where((a) => a['status'] == "pending_review").length;

        return QuizOverviewItem(
          id: quiz['id'] ?? '',
          title: quiz['title'] ?? 'Untitled Exam',
          courseName: headerName,
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= هدر صفحه ریسپانسیو =================
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 450;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Exam Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                                  SizedBox(height: 3),
                                  Text("Design exams, manage tests, and grade papers.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isWide ? 0 : 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text("Deploy", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCreateQuizScreen()))
                                .then((_) => _fetchTeacherQuizzes());
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ================= فیلتر تب‌ها (ریسپانسیو) =================
              Row(
                children: ['all', 'regular', 'chance'].map((tab) {
                  bool isSel = filterType == tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => filterType = tab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSel ? primaryPink : cardBorder.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
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
                                  
                                  // دکمه‌های پایینی کارت (ریسپانسیو کامل)
                                  LayoutBuilder(
                                    builder: (context, cardConstraints) {
                                      bool isCardWide = cardConstraints.maxWidth > 350;
                                      return Flex(
                                        direction: isCardWide ? Axis.horizontal : Axis.vertical,
                                        children: [
                                          Expanded(
                                            flex: isCardWide ? 1 : 0,
                                            child: SizedBox(
                                              width: double.infinity,
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
                                          ),
                                          SizedBox(width: isCardWide ? 10 : 0, height: isCardWide ? 0 : 8),
                                          Expanded(
                                            flex: isCardWide ? 1 : 0,
                                            child: SizedBox(
                                              width: double.infinity,
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
                                          ),
                                        ],
                                      );
                                    },
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
        ),
      ),
    );
  }
}