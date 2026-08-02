import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSubmitting = false;
  List<Map<String, dynamic>> teachers = [];
  List<String> availableCategories = [];
  Map<String, String>? message;

  // Controllers مطابق با جداول دیتابیس courses
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: "0");
  final thumbCtrl = TextEditingController();
  
  // Instructor 1 & 2 Controllers
  final inst1NameCtrl = TextEditingController();
  final inst1BioCtrl = TextEditingController();
  final inst1ImgCtrl = TextEditingController();

  final inst2NameCtrl = TextEditingController();
  final inst2BioCtrl = TextEditingController();
  final inst2ImgCtrl = TextEditingController();

  String selectedLanguage = 'English';
  String? selectedTeacherId;
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
    _fetchTeachersAndCategories();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    thumbCtrl.dispose();
    inst1NameCtrl.dispose();
    inst1BioCtrl.dispose();
    inst1ImgCtrl.dispose();
    inst2NameCtrl.dispose();
    inst2BioCtrl.dispose();
    inst2ImgCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTeachersAndCategories() async {
    try {
      // دریافت اساتید از جدول profiles (نقش teacher, super_admin)
      final teacherRes = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url, bio")
          .inFilter("role", ["teacher", "super_admin", "mentor"])
          .order("first_name", ascending: true);

      // استخراج دسته‌بندی‌هایتاپ و یکتا از دوره‌های موجود یا جدول‌های مرتبط برای پیشنهاد اولیه
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
          teachers = (teacherRes as List?)?.cast<Map<String, dynamic>>() ?? [];
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

  // وقتی استاد انتخاب می‌شود، می‌توانید تخصص‌های او را از دیتابیس (یا جدول teacher_info_courses) بررسی کنید
  Future<void> _onTeacherSelected(String? teacherId) async {
    if (teacherId == null) return;
    setState(() => selectedTeacherId = teacherId);

    try {
      // یافتن اطلاعات تکمیلی استاد از پروفایل یا جدول teacher_info
      final teacherProfile = teachers.firstWhere((t) => t['id'] == teacherId, orElse: () => {});
      if (teacherProfile.isNotEmpty) {
        setState(() {
          inst1NameCtrl.text = "${teacherProfile['first_name'] ?? ''} ${teacherProfile['last_name'] ?? ''}";
          inst1BioCtrl.text = teacherProfile['bio'] ?? '';
          inst1ImgCtrl.text = teacherProfile['avatar_url'] ?? '';
        });
      }

      // بررسی تخصص‌های استاد از جدول teacher_info_courses (در صورت وجود رابطه)
      final teacherInfoMatch = await supabase
          .from("teacher_info")
          .select("id")
          .eq("first_name", teacherProfile['first_name'] ?? '')
          .maybeSingle();

      if (teacherInfoMatch != null) {
        final specializedCourses = await supabase
            .from("teacher_info_courses")
            .select("course:courses(category, title)")
            .eq("teacher_info_id", teacherInfoMatch['id']);

        Set<String> teacherCats = {};
        for (var sc in (specializedCourses as List)) {
          final cat = sc['course']?['category'];
          if (cat != null) teacherCats.add(cat.toString());
        }

        if (teacherCats.isNotEmpty) {
          setState(() {
            availableCategories = teacherCats.toList();
            selectedCategory = availableCategories.first;
          });
        }
      }
    } catch (e) {
      debugPrint("Error auto-filling teacher sections: $e");
    }
  }

  Future<void> handleCreate() async {
    if (titleCtrl.text.trim().isEmpty || selectedCategory == null || selectedTeacherId == null) {
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

      // درج در جدول courses مطابق با ساختار دیتابیس شما
      await supabase.from("courses").insert({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'category': selectedCategory,
        'price': price,
        'language': selectedLanguage,
        'teacher_id': selectedTeacherId,
        'instructor_name': inst1NameCtrl.text.trim().isNotEmpty ? inst1NameCtrl.text.trim() : null,
        'instructor_bio': inst1BioCtrl.text.trim().isNotEmpty ? inst1BioCtrl.text.trim() : null,
        'instructor_image_url': inst1ImgCtrl.text.trim().isNotEmpty ? inst1ImgCtrl.text.trim() : null,
        'instructor_2_name': inst2NameCtrl.text.trim().isNotEmpty ? inst2NameCtrl.text.trim() : null,
        'instructor_2_bio': inst2BioCtrl.text.trim().isNotEmpty ? inst2BioCtrl.text.trim() : null,
        'instructor_2_image_url': inst2ImgCtrl.text.trim().isNotEmpty ? inst2ImgCtrl.text.trim() : null,
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
        message = {'type': 'error', 'text': 'Failed: ${e.toString()}'};
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
              Text("LOADING DATABASE RELATIONS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          "COURSE BUILDER & DB SYNC",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.auto_stories_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("Deploy New Course", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark)),
                  const SizedBox(height: 4),
                  const Text("Select instructor to auto-sync category or choose manually.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
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
                        style: TextStyle(
                          color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 1. Instructor Section (First, so category auto-selects based on instructor)
            _buildSection(
              title: "1. Lead Instructor Selection",
              subtitle: "Selecting an instructor automatically populates their specialized sections",
              children: [
                const Text("SELECT INSTRUCTOR *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedTeacherId,
                  dropdownColor: surfaceWhite,
                  style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Choose professor...",
                    hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                  items: teachers.map((t) {
                    return DropdownMenuItem<String>(
                      value: t['id'],
                      child: Text("${t['first_name']} ${t['last_name']} (${t['email']})"),
                    );
                  }).toList(),
                  onChanged: _onTeacherSelected,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Core Information & Auto Category Section
            _buildSection(
              title: "2. Course Information & Category",
              subtitle: "Category updates automatically based on instructor's domain",
              children: [
                _buildTextField("COURSE TITLE *", titleCtrl, "e.g. Masterclass in Advanced AI"),
                const SizedBox(height: 16),
                
                // Dynamic Category Dropdown (Auto-listed if multiple)
                const Text("CATEGORY (AUTO-MATCHED) *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: surfaceWhite,
                  style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
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
                            initialValue: selectedLanguage,
                            dropdownColor: surfaceWhite,
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cardBorder.withOpacity(0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                            ),
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
                            initialValue: isPublished,
                            dropdownColor: surfaceWhite,
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cardBorder.withOpacity(0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                            ),
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
              ],
            ),
            const SizedBox(height: 20),

            // 3. Instructor Details Cards
            _buildSection(
              title: "3. Instructor Card Display Details",
              subtitle: "Auto-synced from profile, editable for presentation",
              children: [
                _buildTextField("INSTRUCTOR 1 NAME", inst1NameCtrl, "e.g. Dr. Ahmad Safi"),
                const SizedBox(height: 14),
                _buildTextField("INSTRUCTOR 1 BIO", inst1BioCtrl, "Brief professional background...", maxLines: 2),
                const SizedBox(height: 14),
                _buildTextField("INSTRUCTOR 1 IMAGE URL", inst1ImgCtrl, "https://..."),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Co-Instructor (Optional)
            _buildSection(
              title: "4. Co-Instructor (Optional)",
              subtitle: "Secondary instructor details if applicable",
              children: [
                _buildTextField("INSTRUCTOR 2 NAME", inst2NameCtrl, "e.g. John Doe"),
                const SizedBox(height: 14),
                _buildTextField("INSTRUCTOR 2 BIO", inst2BioCtrl, "Brief professional background...", maxLines: 2),
                const SizedBox(height: 14),
                _buildTextField("INSTRUCTOR 2 IMAGE URL", inst2ImgCtrl, "https://..."),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Assets & Media
            _buildSection(
              title: "5. Course Asset",
              children: [
                _buildTextField("THUMBNAIL URL", thumbCtrl, "https://..."),
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
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: maxLines > 1 ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }
}