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

  final List<Map<String, dynamic>> questions = [
    {'text': '', 'points': 10}
  ];

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill required fields.")));
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final selectedClass = classes.firstWhere((c) => c['id'].toString() == selectedClassGroupId);

      final newQuiz = await supabase.from("quizzes").insert({
        'class_group_id': selectedClassGroupId,
        'course_id': selectedClass['course_id'],
        'title': _titleController.text.trim(),
        'passing_score': int.tryParse(_scoreController.text.trim()) ?? 70,
        'is_active': isActive,
        'quiz_type': quizType,
      }).select("id").single();

      final quizId = newQuiz['id'];

      final questionsToInsert = questions.map((q) => {
            'quiz_id': quizId,
            'question_text': q['text'],
            'option_a': 'Descriptive',
            'option_b': 'Descriptive',
            'option_c': 'Descriptive',
            'option_d': 'Descriptive',
            'correct_option': 'A',
            'points': q['points'],
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
        backgroundColor: const Color(0xFF030305),
        body: const Center(child: CircularProgressIndicator(color: Colors.pink)),
      );
    }

    int totalPoints = questions.fold(0, (sum, q) => sum + (q['points'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Deploy Assessment", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Target Cohort *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: selectedClassGroupId,
              dropdownColor: const Color(0xFF161622),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              items: classes.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['class_name']))).toList(),
              onChanged: (val) => setState(() => selectedClassGroupId = val),
            ),
            const SizedBox(height: 12),

            const Text("Exam Type *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("Regular", style: TextStyle(color: Colors.white, fontSize: 11)),
                    value: "regular",
                    groupValue: quizType,
                    activeColor: Colors.pink,
                    onChanged: (val) => setState(() => quizType = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("Chance", style: TextStyle(color: Colors.white, fontSize: 11)),
                    value: "chance",
                    groupValue: quizType,
                    activeColor: Colors.pink,
                    onChanged: (val) => setState(() => quizType = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text("Paper Title *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "e.g. Mid-Term Evaluation",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Passing Threshold Score (%) *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _scoreController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Descriptive Questions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                Text("Total Points: $totalPoints", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text("Q${index + 1}", style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (questions.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                              onPressed: () => setState(() => questions.removeAt(index)),
                            ),
                        ],
                      ),
                      TextField(
                        onChanged: (val) => questions[index]['text'] = val,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: "Question text...",
                          hintStyle: TextStyle(color: Colors.grey.shade700),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        onChanged: (val) => questions[index]['points'] = int.tryParse(val) ?? 10,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          labelText: "Points",
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add Another Question", style: TextStyle(fontSize: 10)),
              onPressed: () => setState(() => questions.add({'text': '', 'points': 10})),
            ),
            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text("Status: Online / Live", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              value: isActive,
              activeColor: Colors.pink,
              onChanged: (val) => setState(() => isActive = val),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting ? null : _handleSubmit,
                child: Text(isSubmitting ? "Deploying..." : "Deploy Descriptive Exam 🚀", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}