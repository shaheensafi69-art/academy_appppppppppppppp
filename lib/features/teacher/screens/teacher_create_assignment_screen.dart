import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherCreateAssignmentScreen extends StatefulWidget {
  const TeacherCreateAssignmentScreen({super.key});

  @override
  State<TeacherCreateAssignmentScreen> createState() => _TeacherCreateAssignmentScreenState();
}

class _TeacherCreateAssignmentScreenState extends State<TeacherCreateAssignmentScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;

  List<Map<String, dynamic>> classes = [];
  String? selectedClassId;
  String? resolvedCourseId;
  String selectedClassName = "Select a target classroom...";

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController(text: "100");

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
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
    _descController.dispose();
    _deadlineController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // واکشی کلاس‌ها به همراه نام دوره مربوطه (courses -> title)
      final data = await supabase
          .from("class_groups")
          .select("id, class_name, course_id, courses(title)")
          .eq("teacher_id", user.id);

      if ((data as List).isNotEmpty) {
        setState(() {
          classes = List<Map<String, dynamic>>.from(data);
          selectedClassId = classes[0]['id'].toString();
          resolvedCourseId = classes[0]['course_id']?.toString();
          
          final courseObj = classes[0]['courses'];
          final courseTitle = courseObj is Map ? (courseObj['title'] ?? 'General Course') : 'General Course';
          selectedClassName = "${classes[0]['class_name']} ($courseTitle)";
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // دیالوگ فوق‌العاده زیبا و حرفه‌ای برای انتخاب کلاس و دوره
  void _showClassPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Target Classroom", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: textGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text("Choose the class and its associated course for this task.", style: TextStyle(color: textGrey, fontSize: 11)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: classes.length,
                  separatorBuilder: (_, _) => const Divider(color: cardBorder),
                  itemBuilder: (context, index) {
                    final c = classes[index];
                    final cId = c['id'].toString();
                    final cName = c['class_name'] ?? 'Class';
                    
                    final courseObj = c['courses'];
                    final courseTitle = courseObj is Map ? (courseObj['title'] ?? 'General Course') : 'General Course';
                    bool isSelected = selectedClassId == cId;

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: isSelected ? lightPinkBg.withOpacity(0.5) : Colors.transparent,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryPink : cardBorder,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.class_rounded, color: isSelected ? Colors.white : textDark, size: 20),
                      ),
                      title: Text(cName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isSelected ? primaryPink : textDark)),
                      subtitle: Text("Course: $courseTitle", style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w600)),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: primaryPink, size: 20) : null,
                      onTap: () {
                        setState(() {
                          selectedClassId = cId;
                          resolvedCourseId = c['course_id']?.toString();
                          selectedClassName = "$cName ($courseTitle)";
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (selectedClassId == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a class and enter a title."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await supabase.from("assignments").insert({
        'class_group_id': selectedClassId,
        'course_id': resolvedCourseId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'deadline': _deadlineController.text.trim().isEmpty ? null : _deadlineController.text.trim(),
        'max_score': int.tryParse(_scoreController.text.trim()) ?? 100,
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Failed to create assignment: $e");
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

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: const Text("Create Assignment", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // انتخاب کلاس مرجع (با طراحی بسیار شیک و لیبل دوره)
                  const Text("Target Classroom & Course *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  classes.isNotEmpty
                      ? InkWell(
                          onTap: _showClassPickerModal,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: cardBorder.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.class_rounded, color: primaryPink, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedClassName,
                                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: textGrey),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                          child: const Text("No classes found. Please create a class first.", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                  const SizedBox(height: 16),

                  // عنوان تکلیف
                  const Text("Assignment Title *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "e.g. Chapter 4 Reflection",
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

                  // توضیحات دستورالعمل
                  const Text("Task Description / Instructions", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    style: const TextStyle(color: textDark, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Provide clear instructions for students...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // مهلت انجام (Deadline)
                  const Text("Deadline Date & Time", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _deadlineController,
                    style: const TextStyle(color: textDark, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "YYYY-MM-DDTHH:MM (e.g. 2026-12-31T23:59)",
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

                  // حداکثر نمره
                  const Text("Maximum Score (Points)", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 30),

                  // دکمه انتشار نهایی
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
                      onPressed: isSubmitting || classes.isEmpty ? null : _handleSubmit,
                      child: Text(isSubmitting ? "Deploying..." : "Deploy Assignment 🚀", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}