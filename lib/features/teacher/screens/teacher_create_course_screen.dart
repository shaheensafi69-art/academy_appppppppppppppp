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
        title: const Text("Create New Course", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
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
            // عنوان دوره
            const Text("Course Title *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g. Advanced AI Trading Masterclass",
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

            // توضیحات دوره
            const Text("Detailed Description", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "What will students learn in this course...",
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

            // دسته‌بندی و قیمت
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Category", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _categoryController,
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Price (USD)", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "0.00",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // زبان دوره
            const Text("Language", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedLanguage,
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
              items: ["English", "Persian", "Arabic", "Pashto"].map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
              onChanged: (val) => setState(() => selectedLanguage = val ?? "English"),
            ),
            const SizedBox(height: 16),

            // تامبنیل دوره
            const Text("Course Thumbnail Image", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _thumbController,
                    style: const TextStyle(color: textDark, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "https://...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isUploadingThumb ? null : () => _uploadImage('course-thumbnails', (url) => setState(() => _thumbController.text = url), (val) => setState(() => isUploadingThumb = val)),
                  child: Text(isUploadingThumb ? "..." : "Upload", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // اطلاعات مدرس اول (نمایش خودکار پروفایل استاد)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightPinkBg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: lightPinkBg,
                    backgroundImage: primaryInstructor['image_url'].isNotEmpty ? NetworkImage(primaryInstructor['image_url']) : null,
                    child: primaryInstructor['image_url'].isEmpty ? const Icon(Icons.person, color: primaryPink) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("PRIMARY INSTRUCTOR (YOU)", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(primaryInstructor['name'].isEmpty ? 'Academy Instructor' : primaryInstructor['name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(primaryInstructor['bio'], style: const TextStyle(color: textGrey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // اطلاعات مدرس دوم (اختیاری)
            const Text("Co-Instructor Details (Optional)", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _coNameController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                labelText: "Co-Instructor Name",
                labelStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coBioController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                labelText: "Co-Instructor Bio",
                labelStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _coImageController,
                    style: const TextStyle(color: textDark, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Co-Instructor Image URL",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isUploadingCo ? null : () => _uploadImage('course-thumbnails', (url) => setState(() => _coImageController.text = url), (val) => setState(() => isUploadingCo = val)),
                  child: Text(isUploadingCo ? "..." : "Upload", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // انتشار دوره
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.5),
              ),
              child: SwitchListTile(
                title: const Text("Publish Course", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
                subtitle: const Text("Make it visible to academy students.", style: TextStyle(color: textGrey, fontSize: 10)),
                value: isPublished,
                activeThumbColor: primaryPink,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => isPublished = val),
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
                child: Text(isSubmitting ? "Compiling Course..." : "Create Course 🚀", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}