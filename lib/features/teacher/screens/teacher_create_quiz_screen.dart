import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherCreateQuizScreen extends StatefulWidget {
  const TeacherCreateQuizScreen({super.key});

  @override
  State<TeacherCreateQuizScreen> createState() => _TeacherCreateQuizScreenState();
}

class _TeacherCreateQuizScreenState extends State<TeacherCreateQuizScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;

  List<Map<String, dynamic>> classes = [];
  String? selectedClassGroupId;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController(text: "70");
  String quizType = "regular"; // regular or chance
  bool isActive = false;

  // ساختار کامل سوالات شامل پشتیبانی از تشریحی و چهارگزینه‌ای
  final List<Map<String, dynamic>> questions = [
    {
      'type': 'multiple_choice', // 'multiple_choice' یا 'descriptive'
      'text': '',
      'option_a': '',
      'option_b': '',
      'option_c': '',
      'option_d': '',
      'correct_option': 'A',
      'points': 10,
    }
  ];

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
    _fetchClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from("class_groups")
          .select("id, class_name, course_id")
          .eq("teacher_id", user.id);

      if (data != null && (data as List).isNotEmpty) {
        setState(() {
          classes = List<Map<String, dynamic>>.from(data);
          selectedClassGroupId = classes[0]['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (selectedClassGroupId == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final selectedClass = classes.firstWhere((c) => c['id'].toString() == selectedClassGroupId);

      // ثبت جدول اصلی کوئیز
      final newQuiz = await supabase.from("quizzes").insert({
        'class_group_id': selectedClassGroupId,
        'course_id': selectedClass['course_id'],
        'title': _titleController.text.trim(),
        'passing_score': int.tryParse(_scoreController.text.trim()) ?? 70,
        'is_active': isActive,
        'quiz_type': quizType,
      }).select("id").single();

      final quizId = newQuiz['id'];

      // آماده‌سازی سوالات برای درج در دیتابیس
      final questionsToInsert = questions.map((q) {
        bool isMCQ = q['type'] == 'multiple_choice';
        return {
          'quiz_id': quizId,
          'question_text': q['text'],
          'option_a': isMCQ ? q['option_a'] : 'Descriptive',
          'option_b': isMCQ ? q['option_b'] : 'Descriptive',
          'option_c': isMCQ ? q['option_c'] : 'Descriptive',
          'option_d': isMCQ ? q['option_d'] : 'Descriptive',
          'correct_option': isMCQ ? q['correct_option'] : 'A',
          'points': q['points'],
        };
      }).toList();

      await supabase.from("quiz_questions").insert(questionsToInsert);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error deploying exam: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
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

    int totalPoints = questions.fold(0, (sum, q) => sum + (q['points'] as int));

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: const Text("Deploy Assessment", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // انتخاب کلاس مرجع
            const Text("Target Cohort *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedClassGroupId,
              dropdownColor: surfaceWhite,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
              items: classes.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['class_name']))).toList(),
              onChanged: (val) => setState(() => selectedClassGroupId = val),
            ),
            const SizedBox(height: 16),

            // نوع آزمون
            const Text("Exam Type *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: quizType == "regular" ? lightPinkBg : cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: quizType == "regular" ? primaryPink : cardBorder, width: quizType == "regular" ? 1.5 : 1),
                    ),
                    child: RadioListTile<String>(
                      title: const Text("Regular", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900)),
                      value: "regular",
                      groupValue: quizType,
                      activeColor: primaryPink,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      onChanged: (val) => setState(() => quizType = val!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: quizType == "chance" ? lightPinkBg : cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: quizType == "chance" ? primaryPink : cardBorder, width: quizType == "chance" ? 1.5 : 1),
                    ),
                    child: RadioListTile<String>(
                      title: const Text("Chance", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900)),
                      value: "chance",
                      groupValue: quizType,
                      activeColor: primaryPink,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      onChanged: (val) => setState(() => quizType = val!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // عنوان آزمون
            const Text("Paper Title *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g. Mid-Term Evaluation",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // نمره قبولی
            const Text("Passing Threshold Score (%) *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _scoreController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            // هدر سوالات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Assessment Questions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text("Total Points: $totalPoints", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // لیست سوالات (پشتیبانی از چندگزینه‌ای و تشریحی)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final q = questions[index];
                bool isMCQ = q['type'] == 'multiple_choice';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("Q${index + 1}", style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(width: 10),
                          // انتخاب نوع سوال (چهارگزینه‌ای یا تشریحی)
                          DropdownButton<String>(
                            value: q['type'],
                            dropdownColor: surfaceWhite,
                            style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold),
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'multiple_choice', child: Text("Multiple Choice (4 Options)")),
                              DropdownMenuItem(value: 'descriptive', child: Text("Descriptive (Written)")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                q['type'] = val!;
                              });
                            },
                          ),
                          const Spacer(),
                          if (questions.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => setState(() => questions.removeAt(index)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (val) => q['text'] = val,
                        maxLines: 2,
                        style: const TextStyle(color: textDark, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Enter question text...",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.5),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // اگر سوال چهارگزینه‌ای بود، فیلد گزینه‌ها و پاسخ صحیح نمایش داده شود
                      if (isMCQ) ...[
                        const SizedBox(height: 6),
                        _buildOptionField(q, 'A', 'Option A', (val) => q['option_a'] = val),
                        const SizedBox(height: 6),
                        _buildOptionField(q, 'B', 'Option B', (val) => q['option_b'] = val),
                        const SizedBox(height: 6),
                        _buildOptionField(q, 'C', 'Option C', (val) => q['option_c'] = val),
                        const SizedBox(height: 6),
                        _buildOptionField(q, 'D', 'Option D', (val) => q['option_d'] = val),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text("Correct Option:", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            DropdownButton<String>(
                              value: q['correct_option'],
                              dropdownColor: surfaceWhite,
                              style: const TextStyle(color: primaryPink, fontSize: 12, fontWeight: FontWeight.w900),
                              items: ['A', 'B', 'C', 'D'].map((opt) => DropdownMenuItem(value: opt, child: Text("Option $opt"))).toList(),
                              onChanged: (val) => setState(() => q['correct_option'] = val!),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),
                      TextField(
                        keyboardType: TextInputType.number,
                        onChanged: (val) => q['points'] = int.tryParse(val) ?? 10,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: "Points",
                          labelStyle: const TextStyle(color: textGrey, fontSize: 11),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // دکمه افزودن سوال دیگر
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: const BorderSide(color: cardBorder, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_rounded, size: 18, color: primaryPink),
                label: const Text("Add Another Question", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                onPressed: () => setState(() => questions.add({
                      'type': 'multiple_choice',
                      'text': '',
                      'option_a': '',
                      'option_b': '',
                      'option_c': '',
                      'option_d': '',
                      'correct_option': 'A',
                      'points': 10,
                    })),
              ),
            ),
            const SizedBox(height: 20),

            // وضعیت آنلاین/لایو
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.5),
              ),
              child: SwitchListTile(
                title: const Text("Status: Online / Live", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
                subtitle: const Text("Make this assessment active for students.", style: TextStyle(color: textGrey, fontSize: 10)),
                value: isActive,
                activeColor: primaryPink,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => isActive = val),
              ),
            ),
            const SizedBox(height: 30),

            // دکمه ارسال نهایی
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
                onPressed: isSubmitting ? null : _handleSubmit,
                child: Text(isSubmitting ? "Deploying..." : "Deploy Assessment Paper 🚀", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionField(Map<String, dynamic> q, String optionKey, String hint, Function(String) onChanged) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: textDark, fontSize: 11),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textGrey, fontSize: 10),
        filled: true,
        fillColor: cardBorder.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
      ),
    );
  }
}