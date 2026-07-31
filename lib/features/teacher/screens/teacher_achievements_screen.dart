import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // 👈 استفاده از پکیج image_picker

class StudentItem {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;

  StudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
  });
}

class CourseItem {
  final String id;
  final String title;

  CourseItem({required this.id, required this.title});
}

class AwardItem {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final int pointsRequired;

  AwardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.pointsRequired,
  });

  factory AwardItem.fromJson(Map<String, dynamic> json) {
    return AwardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'] ?? '🏆',
      pointsRequired: json['points_required'] ?? 0,
    );
  }
}

class TeacherAchievementsScreen extends StatefulWidget {
  const TeacherAchievementsScreen({super.key});

  @override
  State<TeacherAchievementsScreen> createState() => _TeacherAchievementsScreenState();
}

class _TeacherAchievementsScreenState extends State<TeacherAchievementsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  List<StudentItem> students = [];
  List<CourseItem> courses = [];
  List<AwardItem> awards = [];

  // فرم صدور گواهینامه
  String? selectedStudentId;
  String? selectedCourseId;
  final TextEditingController _certCodeController = TextEditingController();
  final TextEditingController _certUrlController = TextEditingControllerX();
  
  // متغیر برای نگهداری عکس انتخاب شده با image_picker
  XFile? selectedImageFile; 
  bool isSubmittingCert = false;
  String studentSearchQuery = "";

  // فرم اعطای نشان
  String? selectedAwardStudentId;
  String? selectedAwardId;
  bool isSubmittingAward = false;

  String? messageText;
  bool isSuccessMessage = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _certCodeController.dispose();
    _certUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // ۱. دریافت کلاس‌های استاد
      final myClasses = await supabase
          .from("class_groups")
          .select("id, course_id")
          .eq("teacher_id", userId);

      if (myClasses != null && (myClasses as List).isNotEmpty) {
        final classIds = myClasses.map((c) => c['class_group_id'] ?? c['id']).toList();
        final courseIds = myClasses.map((c) => c['course_id']).where((id) => id != null).toSet().toList();

        // ۲. دریافت دوره‌ها
        if (courseIds.isNotEmpty) {
          final coursesData = await supabase
              .from("courses")
              .select("id, title")
              .inFilter("id", courseIds);

          if (coursesData != null) {
            courses = (coursesData as List).map((c) => CourseItem(id: c['id'], title: c['title'])).toList();
            if (courses.isNotEmpty) selectedCourseId = courses[0].id;
          }
        }

        // ۳. دریافت شاگردان این استاد
        final classStudents = await supabase
            .from("class_students")
            .select("student_id")
            .inFilter("class_group_id", classIds);

        if (classStudents != null && (classStudents as List).isNotEmpty) {
          final studentIds = classStudents.map((cs) => cs['student_id']).toSet().toList();
          final profiles = await supabase
              .from("profiles")
              .select("id, first_name, last_name, email, avatar_url")
              .inFilter("id", studentIds);

          if (profiles != null) {
            students = (profiles as List).map((p) => StudentItem(
                  id: p['id'],
                  firstName: p['first_name'] ?? '',
                  lastName: p['last_name'] ?? '',
                  email: p['email'] ?? '',
                  avatarUrl: p['avatar_url'],
                )).toList();

            if (students.isNotEmpty) {
              selectedStudentId = students[0].id;
              selectedAwardStudentId = students[0].id;
            }
          }
        }
      }

      // ۴. دریافت لیست تمام نشان‌ها (Awards)
      final awardsData = await supabase
          .from("awards")
          .select()
          .order("points_required", ascending: true);

      if (awardsData != null) {
        awards = (awardsData as List).map((a) => AwardItem.fromJson(a)).toList();
        if (awards.isNotEmpty) selectedAwardId = awards[0].id;
      }
    } catch (e) {
      debugPrint("Error fetching achievements data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _generateAutoCode() {
    if (selectedCourseId == null) {
      _showMessage("Please select a course first.", false);
      return;
    }
    final year = DateTime.now().year;
    final coursePrefix = selectedCourseId!.substring(0, min(4, selectedCourseId!.length)).toUpperCase();
    final randomHex = Random().nextInt(999999).toString().padLeft(6, '0');
    setState(() {
      _certCodeController.text = "SAFI-$year-$coursePrefix-$randomHex";
    });
  }

  // انتخاب عکس گواهینامه با استفاده از ImagePicker
  Future<void> _pickImageFile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImageFile = image;
        _certUrlController.clear(); // پاک کردن لینک دستی اگر عکسی انتخاب شد
      });
    }
  }

  Future<void> _handleIssueCertificate() async {
    if (selectedStudentId == null || selectedCourseId == null || _certCodeController.text.trim().isEmpty) {
      _showMessage("Please fill in all required fields.", false);
      return;
    }

    setState(() => isSubmittingCert = true);
    try {
      String finalUrl = _certUrlController.text.trim();

      // آپلود فایل عکس در باکت certificates در صورت انتخاب
      if (selectedImageFile != null) {
        final fileBytes = await selectedImageFile!.readAsBytes();
        final fileExt = selectedImageFile!.name.split('.').lastOrNull ?? 'jpg';
        final fileName = '${selectedStudentId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'certificates/$fileName';

        await supabase.storage.from("certificates").uploadBinary(
              filePath,
              fileBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrlData = supabase.storage.from("certificates").getPublicUrl(filePath);
        finalUrl = publicUrlData;
      }

      await supabase.from("certificates").insert({
        'student_id': selectedStudentId,
        'course_id': selectedCourseId,
        'certificate_code': _certCodeController.text.trim(),
        'certificate_url': finalUrl.isEmpty ? null : finalUrl,
        'issue_date': DateTime.now().toIso8601String(),
      });

      _showMessage("Certificate issued successfully!", true);
      _certCodeController.clear();
      _certUrlController.clear();
      setState(() => selectedImageFile = null);
    } catch (e) {
      _showMessage("Failed to issue certificate: $e", false);
    } finally {
      if (mounted) setState(() => isSubmittingCert = false);
    }
  }

  Future<void> _handleGrantAward() async {
    if (selectedAwardStudentId == null || selectedAwardId == null) {
      _showMessage("Please select a student and an award.", false);
      return;
    }

    setState(() => isSubmittingAward = true);
    try {
      await supabase.from("student_awards").insert({
        'student_id': selectedAwardStudentId,
        'award_id': selectedAwardId,
      });

      _showMessage("Award granted successfully!", true);
    } catch (e) {
      _showMessage("Failed to grant award: $e", false);
    } finally {
      if (mounted) setState(() => isSubmittingAward = false);
    }
  }

  void _showMessage(String text, bool success) {
    setState(() {
      messageText = text;
      isSuccessMessage = success;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => messageText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
    }

    final filteredStudents = students.where((s) {
      final query = studentSearchQuery.toLowerCase();
      return s.firstName.toLowerCase().contains(query) || s.lastName.toLowerCase().contains(query) || s.email.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Text("🏆", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Honors & Awards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Issue official certificates and grant special awards to your top students.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // پیام سیستم (Toast)
          if (messageText != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isSuccessMessage ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSuccessMessage ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(isSuccessMessage ? Icons.check_circle : Icons.error, color: isSuccessMessage ? Colors.greenAccent : Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

          // ================= ۱. فرم صدور گواهینامه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f).withOpacity(0.8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Issue Certificate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 14),

                // انتخاب شاگرد با جستجو
                const Text("Select Student *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  onChanged: (val) => setState(() => studentSearchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Search student by name or email...",
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStudentId,
                  dropdownColor: const Color(0xFF161622),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  items: filteredStudents.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.firstName} ${s.lastName} (${s.email})"))).toList(),
                  onChanged: (val) => setState(() => selectedStudentId = val),
                ),
                const SizedBox(height: 12),

                // انتخاب دوره
                const Text("Related Course *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedCourseId,
                  dropdownColor: const Color(0xFF161622),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  items: courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))).toList(),
                  onChanged: (val) => setState(() => selectedCourseId = val),
                ),
                const SizedBox(height: 12),

                // کد گواهینامه با دکمه تولید خودکار
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Certificate Code (ID) *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: _generateAutoCode,
                      child: const Text("✨ Auto Generate", style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _certCodeController,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: "e.g. SAFI-2026-X89",
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 12),

                // انتخاب عکس گواهینامه با ImagePicker
                const Text("Upload Certificate Image", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _pickImageFile,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.indigoAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedImageFile != null ? selectedImageFile!.name : "Tap to pick image from gallery...",
                            style: TextStyle(color: selectedImageFile != null ? Colors.white : Colors.grey, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmittingCert ? null : _handleIssueCertificate,
                    child: Text(isSubmittingCert ? "Issuing..." : "Issue Certificate 🚀", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= ۲. فرم اعطای نشان (Grant Special Award) =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f).withOpacity(0.8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Grant Special Award", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 14),

                const Text("Select Student *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedAwardStudentId,
                  dropdownColor: const Color(0xFF161622),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  items: students.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.firstName} ${s.lastName}"))).toList(),
                  onChanged: (val) => setState(() => selectedAwardStudentId = val),
                ),
                const SizedBox(height: 12),

                const Text("Select Badge / Award *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                awards.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: awards.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final award = awards[index];
                          bool isSelected = selectedAwardId == award.id;

                          return GestureDetector(
                            onTap: () => setState(() => selectedAwardId = award.id),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.amber.withOpacity(0.15) : Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  Text(award.iconUrl, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(award.title, style: TextStyle(color: isSelected ? Colors.amberAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text(award.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                  if (isSelected) const Icon(Icons.check_circle, color: Colors.amberAccent, size: 16),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : const Text("No awards configured in database.", style: TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmittingAward ? null : _handleGrantAward,
                    child: Text(isSubmittingAward ? "Granting..." : "Grant Award 🏆", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// کلاس کمکی برای کنترلر متنی URL گواهینامه
class TextEditingControllerX extends TextEditingController {}