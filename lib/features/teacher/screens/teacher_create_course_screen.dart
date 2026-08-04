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

  List<Map<String, dynamic>> availableCoInstructors = [];
  Map<String, dynamic>? selectedCoInstructor;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: "Masterclass");
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _thumbController = TextEditingController();

  String selectedLanguage = "English";
  bool isPublished = false;
  bool isUploadingThumb = false;

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
        primaryInstructor = {
          'name': "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim(),
          'bio': profile['bio'] ?? 'Senior Academy Instructor',
          'image_url': profile['avatar_url'] ?? '',
        };
      }

      // واکشی بدون فیلتر تمامی استادان از جدول teacher_info
      final coInstructorsRes = await supabase
          .from("teacher_info")
          .select("id, first_name, last_name, bio, avatar_url");

      availableCoInstructors = List<Map<String, dynamic>>.from(coInstructorsRes);
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

  // تابع نمایش لیست کشویی حرفه‌ای با جزئیات و پروفایل استادان
  void _showCoInstructorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Co-Instructor", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: textGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text("Choose a faculty member to co-teach this course.", style: TextStyle(color: textGrey, fontSize: 11)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: lightPinkBg,
                  child: const Icon(Icons.person_off_rounded, color: primaryPink, size: 20),
                ),
                title: const Text("None (No Co-Instructor)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                subtitle: const Text("Run course solo", style: TextStyle(fontSize: 10, color: textGrey)),
                onTap: () {
                  setState(() => selectedCoInstructor = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: cardBorder),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: availableCoInstructors.length,
                  separatorBuilder: (_, _) => const Divider(color: cardBorder),
                  itemBuilder: (context, index) {
                    final teacher = availableCoInstructors[index];
                    final name = "${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}".trim();
                    final avatar = teacher['avatar_url'];
                    final bio = teacher['bio'] ?? 'Academy Faculty Member';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: lightPinkBg,
                        backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: primaryPink) : null,
                      ),
                      title: Text(name.isNotEmpty ? name : "Instructor", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                      subtitle: Text(bio, style: const TextStyle(fontSize: 10, color: textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryPink),
                      onTap: () {
                        setState(() => selectedCoInstructor = teacher);
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
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Course title is required."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      String? coName;
      String? coBio;
      String? coImage;
      String? coId;

      if (selectedCoInstructor != null) {
        coName = "${selectedCoInstructor!['first_name'] ?? ''} ${selectedCoInstructor!['last_name'] ?? ''}".trim();
        coBio = selectedCoInstructor!['bio'];
        coImage = selectedCoInstructor!['avatar_url'];
        coId = selectedCoInstructor!['id'].toString();
      }

      final courseRes = await supabase.from("courses").insert({
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
        'instructor_2_name': coName,
        'instructor_2_bio': coBio,
        'instructor_2_image_url': coImage,
      }).select('id').single();

      final courseId = courseRes['id'];

      if (coId != null) {
        await supabase.from("teacher_info_courses").insert({
          'teacher_info_id': coId,
          'course_id': courseId,
        });
      }

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

                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWide = constraints.maxWidth > 500;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children: [
                          Expanded(
                            flex: isWide ? 1 : 0,
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
                          SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 16),
                          Expanded(
                            flex: isWide ? 1 : 0,
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
                      );
                    },
                  ),
                  const SizedBox(height: 16),

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

                  const Text("Course Thumbnail Image", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWide = constraints.maxWidth > 400;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: isWide ? 1 : 0,
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
                          SizedBox(width: isWide ? 10 : 0, height: isWide ? 0 : 8),
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
                      );
                    },
                  ),
                  const SizedBox(height: 20),

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

                  // منوی کشویی فوق‌العاده زیبا و گرافیکی برای انتخاب استاد دوم
                  const Text("Co-Instructor Selection (Optional)", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showCoInstructorPicker,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBorder.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: lightPinkBg,
                            backgroundImage: selectedCoInstructor != null && selectedCoInstructor!['avatar_url'] != null
                                ? NetworkImage(selectedCoInstructor!['avatar_url'])
                                : null,
                            child: selectedCoInstructor == null || selectedCoInstructor!['avatar_url'] == null
                                ? const Icon(Icons.person_add_alt_1_rounded, color: primaryPink, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedCoInstructor != null
                                      ? "${selectedCoInstructor!['first_name'] ?? ''} ${selectedCoInstructor!['last_name'] ?? ''}".trim()
                                      : "Select Co-Instructor (Optional)",
                                  style: TextStyle(
                                    color: selectedCoInstructor != null ? textDark : textGrey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedCoInstructor != null ? (selectedCoInstructor!['bio'] ?? 'Faculty Member') : "Tap to choose from faculty list",
                                  style: const TextStyle(color: textGrey, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: textGrey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
          ),
        ),
      ),
    );
  }
}