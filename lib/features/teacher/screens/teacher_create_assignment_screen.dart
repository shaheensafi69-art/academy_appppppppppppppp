import 'dart:ui';
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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController(text: "100");

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

      final data = await supabase
          .from("class_groups")
          .select("id, class_name")
          .eq("teacher_id", user.id);

      if (data != null && (data as List).isNotEmpty) {
        setState(() {
          classes = List<Map<String, dynamic>>.from(data);
          selectedClassId = classes[0]['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
        backgroundColor: const Color(0xFF030305),
        body: const Center(child: CircularProgressIndicator(color: Colors.pink)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Create Assignment", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Target Classroom *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: selectedClassId,
              dropdownColor: const Color(0xFF161622),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              items: classes.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['class_name']))).toList(),
              onChanged: (val) => setState(() => selectedClassId = val),
            ),
            const SizedBox(height: 12),

            const Text("Assignment Title *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "e.g. Chapter 4 Reflection",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Task Description / Instructions", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "Provide clear instructions...",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Deadline Date & Time", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _deadlineController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "YYYY-MM-DDTHH:MM (e.g. 2026-12-31T23:59)",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Maximum Score (Points)", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),

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
                child: Text(isSubmitting ? "Deploying..." : "Deploy Assignment 🚀", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}