import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

class TeacherCreateCourseScreen extends StatefulWidget {
  const TeacherCreateCourseScreen({super.key});

  @override
  State<TeacherCreateCourseScreen> createState() => _TeacherCreateCourseScreenState();
}

class _TeacherCreateCourseScreenState extends State<TeacherCreateCourseScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;

  Map<String, dynamic> primaryInstructor = {'name': '', 'bio': '', 'image_url': ''};
  String teacherId = '';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: "Masterclass");
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _thumbController = TextEditingController();
  final TextEditingController _coNameController = TextEditingController();
  final TextEditingController _coBioController = TextEditingController();
  final TextEditingController _coImageController = TextEditingController();

  String selectedLanguage = "English";
  bool isPublished = false;
  bool isUploadingThumb = false;
  bool isUploadingCo = false;

  @override
  void initState() {
    super.initState();
    _fetchInstructorData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _thumbController.dispose();
    _coNameController.dispose();
    _coBioController.dispose();
    _coImageController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstructorData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      teacherId = user.id;

      final profile = await supabase
          .from("profiles")
          .select("first_name, last_name, avatar_url, bio")
          .eq("id", teacherId)
          .maybeSingle();

      if (profile != null) {
        setState(() {
          primaryInstructor = {
            'name': "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim(),
            'bio': profile['bio'] ?? 'Senior Academy Instructor',
            'image_url': profile['avatar_url'] ?? '',
          };
        });
      }
    } catch (e) {
      debugPrint("Error loading instructor: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _uploadImage(String bucketName, Function(String) onSuccess, Function(bool) setLoading) async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setLoading(true);
      try {
        final file = result.files.single;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.${file.extension}';
        await supabase.storage.from(bucketName).uploadBinary(fileName, file.bytes!);
        final url = supabase.storage.from(bucketName).getPublicUrl(fileName);
        onSuccess(url);
      } catch (e) {
        debugPrint("Upload error: $e");
      } finally {
        setLoading(false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Course title is required."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await supabase.from("courses").insert({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'category': _categoryController.text.trim(),
        'teacher_id': teacherId,
        'price': _priceController.text.trim().isEmpty ? 0 : double.parse(_priceController.text.trim()),
        'thumbnail_url': _thumbController.text.trim().isEmpty ? null : _thumbController.text.trim(),
        'is_published': isPublished,
        'language': selectedLanguage,
        'instructor_name': primaryInstructor['name'],
        'instructor_bio': primaryInstructor['bio'],
        'instructor_image_url': primaryInstructor['image_url'],
        'instructor_2_name': _coNameController.text.trim().isEmpty ? null : _coNameController.text.trim(),
        'instructor_2_bio': _coBioController.text.trim().isEmpty ? null : _coBioController.text.trim(),
        'instructor_2_image_url': _coImageController.text.trim().isEmpty ? null : _coImageController.text.trim(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Failed to create course: $e");
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
        title: const Text("Create New Course", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Course Title *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "e.g. Advanced AI Trading Masterclass",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Detailed Description", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "What will students learn...",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Category", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _categoryController,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Price (USD)", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: "0.00",
                          hintStyle: TextStyle(color: Colors.grey.shade700),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text("Course Thumbnail Image URL", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _thumbController,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "https://...",
                      hintStyle: TextStyle(color: Colors.grey.shade700),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                  onPressed: isUploadingThumb ? null : () => _uploadImage('course-thumbnails', (url) => setState(() => _thumbController.text = url), (val) => setState(() => isUploadingThumb = val)),
                  child: Text(isUploadingThumb ? "..." : "Upload"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("Publish Course", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              subtitle: Text("Make it visible to academy students.", style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
              value: isPublished,
              activeColor: Colors.pink,
              onChanged: (val) => setState(() => isPublished = val),
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
                child: Text(isSubmitting ? "Compiling..." : "Create Course 🚀", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}