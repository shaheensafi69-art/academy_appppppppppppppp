import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool isLoading = true;
  bool isSubmitting = false;
  bool isUploadingThumbnail = false;
  List<Map<String, dynamic>> teachersFullData = [];
  List<String> availableCategories = [];
  Map<String, String>? message;

  // Controllers مطابق با جدول دیتابیس courses
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: "0");
  final thumbCtrl = TextEditingController();

  // Instructor 1 (Lead) Data
  String? selectedInst1Id;
  String? inst1FullName;
  String? inst1Bio;
  String? inst1ImgUrl;

  // Instructor 2 (Co-Instructor) Data
  String? selectedInst2Id;
  String? inst2FullName;
  String? inst2Bio;
  String? inst2ImgUrl;

  String selectedLanguage = 'English';
  String? selectedCategory;
  bool isPublished = false;

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
    _fetchTeachersAndMetadata();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    thumbCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTeachersAndMetadata() async {
    try {
      final teacherProfilesRes = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url, bio")
          .inFilter("role", ["teacher", "super_admin", "mentor"])
          .order("first_name", ascending: true);

      List<Map<String, dynamic>> finalTeachersList = [];

      if (teacherProfilesRes != null) {
        for (var profile in (teacherProfilesRes as List)) {
          final tId = profile['id'];

          final teacherInfoMatch = await supabase
              .from("teacher_info")
              .select("id, bio")
              .eq("id", tId)
              .maybeSingle();

          List<String> specialties = [];
          if (teacherInfoMatch != null) {
            final specRes = await supabase
                .from("teacher_info_courses")
                .select("course:courses(title, category)")
                .eq("teacher_info_id", teacherInfoMatch['id']);

            if (specRes != null) {
              for (var item in (specRes as List)) {
                final cat = item['course']?['category'];
                if (cat != null) specialties.add(cat.toString());
              }
            }
          }

          finalTeachersList.add({
            ...profile,
            'bio': teacherInfoMatch?['bio'] ?? profile['bio'] ?? '',
            'specialties': specialties.toSet().toList(),
          });
        }
      }

      final courseRes = await supabase.from("courses").select("category");
      Set<String> categoriesSet = {};
      for (var c in (courseRes as List)) {
        if (c['category'] != null && c['category'].toString().trim().isNotEmpty) {
          categoriesSet.add(c['category'].toString().trim());
        }
      }

      if (categoriesSet.isEmpty) {
        categoriesSet = {"Finance & Trading", "Software Engineering", "Digital Business", "Artificial Intelligence"};
      }

      if (mounted) {
        setState(() {
          teachersFullData = finalTeachersList;
          availableCategories = categoriesSet.toList();
          if (availableCategories.isNotEmpty) {
            selectedCategory = availableCategories.first;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching metadata: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadThumbnail() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => isUploadingThumbnail = true);
      File file = File(pickedFile.path);
      final fileExt = pickedFile.path.split('.').last;
      final fileName = 'course-thumb-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('avatars').upload(fileName, file);
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      setState(() {
        thumbCtrl.text = publicUrl;
        isUploadingThumbnail = false;
      });
    } catch (e) {
      setState(() => isUploadingThumbnail = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    }
  }

  void _onLeadTeacherSelected(Map<String, dynamic>? teacher) {
    if (teacher == null) return;
    setState(() {
      selectedInst1Id = teacher['id'];
      inst1FullName = "${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}";
      inst1Bio = teacher['bio'] ?? '';
      inst1ImgUrl = teacher['avatar_url'] ?? '';

      List<String> specs = (teacher['specialties'] as List?)?.cast<String>() ?? [];
      if (specs.isNotEmpty) {
        if (availableCategories.contains(specs.first)) {
          selectedCategory = specs.first;
        } else {
          availableCategories.add(specs.first);
          selectedCategory = specs.first;
        }
      }
    });
  }

  void _onCoTeacherSelected(Map<String, dynamic>? teacher) {
    if (teacher == null) return;
    setState(() {
      selectedInst2Id = teacher['id'];
      inst2FullName = "${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}";
      inst2Bio = teacher['bio'] ?? '';
      inst2ImgUrl = teacher['avatar_url'] ?? '';
    });
  }

  Future<void> handleCreate() async {
    if (titleCtrl.text.trim().isEmpty || selectedCategory == null || selectedInst1Id == null) {
      setState(() {
        message = {'type': 'error', 'text': 'Title, Category, and Lead Instructor are required.'};
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      message = null;
    });

    try {
      double price = double.tryParse(priceCtrl.text.trim()) ?? 0;

      await supabase.from("courses").insert({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'category': selectedCategory,
        'price': price,
        'language': selectedLanguage,
        'teacher_id': selectedInst1Id,
        'instructor_name': inst1FullName,
        'instructor_bio': inst1Bio,
        'instructor_image_url': inst1ImgUrl,
        'instructor_2_name': inst2FullName,
        'instructor_2_bio': inst2Bio,
        'instructor_2_image_url': inst2ImgUrl,
        'thumbnail_url': thumbCtrl.text.trim().isNotEmpty ? thumbCtrl.text.trim() : null,
        'is_published': isPublished,
      });

      setState(() {
        message = {'type': 'success', 'text': 'Course successfully deployed to database! 🚀'};
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to create course: ${e.toString()}'};
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING INSTRUCTORS & METADATA...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBorder,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, color: textDark, size: 14),
                        SizedBox(width: 6),
                        Text("Back to Library", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Banner
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "COURSE DEPLOYMENT DASHBOARD",
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                            ),
                          ),
                          const Icon(Icons.auto_stories_rounded, color: primaryPink, size: 22),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Publish New Course", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark)),
                      const SizedBox(height: 4),
                      const Text("Select instructors from the system directory to auto-sync details.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message!['type'] == 'success' ? Colors.green.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: message!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          message!['type'] == 'success' ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message!['text']!,
                            style: TextStyle(color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 1. Lead Instructor Selection
                _buildSection(
                  title: "1. Lead Instructor Selection *",
                  subtitle: "Select the primary professor from the live system directory",
                  children: [
                    const Text("SELECT LEAD INSTRUCTOR", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _buildTeacherDropdown(
                      hint: "Choose primary instructor...",
                      onChanged: _onLeadTeacherSelected,
                    ),
                    if (inst1FullName != null) ...[
                      const SizedBox(height: 10),
                      Text("Selected: $inst1FullName", style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Course Information & Category (شامل گزینه ۵ ادغام‌شده)
                _buildSection(
                  title: "2. Course Information, Category & Assets",
                  subtitle: "Define curriculum, pricing and upload course thumbnail",
                  children: [
                    _buildTextField("COURSE TITLE *", titleCtrl, "e.g. Masterclass in Advanced AI"),
                    const SizedBox(height: 16),
                    
                    const Text("CATEGORY (AUTO-MATCHED) *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      dropdownColor: surfaceWhite,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _inputFieldDecoration("Select category"),
                      items: availableCategories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("LANGUAGE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedLanguage,
                                dropdownColor: surfaceWhite,
                                style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                decoration: _inputFieldDecoration("Language"),
                                items: ['English', 'Persian', 'Pashto'].map((String lang) {
                                  return DropdownMenuItem(value: lang, child: Text(lang));
                                }).toList(),
                                onChanged: (val) => setState(() => selectedLanguage = val ?? 'English'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("STATUS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<bool>(
                                value: isPublished,
                                dropdownColor: surfaceWhite,
                                style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                decoration: _inputFieldDecoration("Status"),
                                items: const [
                                  DropdownMenuItem(value: true, child: Text("Published")),
                                  DropdownMenuItem(value: false, child: Text("Draft")),
                                ],
                                onChanged: (val) => setState(() => isPublished = val ?? false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField("CURRICULUM DESCRIPTION", descCtrl, "Detailed syllabus summary...", maxLines: 3),
                    const SizedBox(height: 16),
                    _buildTextField("PRICE (USD)", priceCtrl, "0", isNumber: true),
                    const SizedBox(height: 16),

                    // بخش دکمه آپلود Thumbnail (گزینه ۵ سابق)
                    const Text("THUMBNAIL IMAGE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: thumbCtrl,
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: _inputFieldDecoration("https://... or click upload"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: isUploadingThumbnail ? null : _pickAndUploadThumbnail,
                            icon: isUploadingThumbnail
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.cloud_upload_rounded, size: 18),
                            label: const Text("Upload", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Co-Instructor Selection (اکنون کاملاً انتخابی و کشویی است)
                _buildSection(
                  title: "3. Co-Instructor (Optional)",
                  subtitle: "Select a secondary instructor from the system directory if applicable",
                  children: [
                    const Text("SELECT CO-INSTRUCTOR", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _buildTeacherDropdown(
                      hint: "Choose secondary instructor (optional)...",
                      onChanged: _onCoTeacherSelected,
                    ),
                    if (inst2FullName != null) ...[
                      const SizedBox(height: 10),
                      Text("Selected Co-Instructor: $inst2FullName", style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
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
                    onPressed: isSubmitting ? null : handleCreate,
                    child: isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("CREATE & DEPLOY COURSE 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherDropdown({required String hint, required Function(Map<String, dynamic>?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          hint: Text(hint, style: const TextStyle(color: textGrey, fontSize: 11)),
          dropdownColor: surfaceWhite,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink),
          items: teachersFullData.map((t) {
            String name = "${t['first_name'] ?? ''} ${t['last_name'] ?? ''}";
            List specs = (t['specialties'] as List?) ?? [];
            String specText = specs.isNotEmpty ? " • Specialties: ${specs.join(', ')}" : "";

            return DropdownMenuItem<Map<String, dynamic>>(
              value: t,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: lightPinkBg,
                      backgroundImage: t['avatar_url'] != null && t['avatar_url'].toString().isNotEmpty
                          ? NetworkImage(t['avatar_url'])
                          : null,
                      child: (t['avatar_url'] == null || t['avatar_url'].toString().isEmpty)
                          ? Text(name.isNotEmpty ? name[0] : 'T', style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("${t['email']}$specText", style: const TextStyle(color: textGrey, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSection({required String title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          cursorColor: primaryPink,
          decoration: _inputFieldDecoration(hint),
        ),
      ],
    );
  }

  InputDecoration _inputFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
      filled: true,
      fillColor: cardBorder.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
    );
  }
}