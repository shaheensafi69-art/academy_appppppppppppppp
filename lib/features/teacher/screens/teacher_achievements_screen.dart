import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

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

  // پالت رنگی اختصاصی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  List<StudentItem> students = [];
  List<CourseItem> courses = [];
  List<AwardItem> awards = [];

  // فرم صدور گواهینامه
  String? selectedStudentId;
  String? selectedCourseId;
  final TextEditingController _certCodeController = TextEditingController();
  final TextEditingController _certUrlController = TextEditingController();
  
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

      final myClasses = await supabase
          .from("class_groups")
          .select("id, course_id")
          .eq("teacher_id", userId);

      if (myClasses != null && (myClasses as List).isNotEmpty) {
        final classIds = myClasses.map((c) => c['class_group_id'] ?? c['id']).toList();
        final courseIds = myClasses.map((c) => c['course_id']).where((id) => id != null).toSet().toList();

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

  Future<void> _pickImageFile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImageFile = image;
        _certUrlController.clear();
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
      return const Center(child: CircularProgressIndicator(color: primaryPink));
    }

    final filteredStudents = students.where((s) {
      final query = studentSearchQuery.toLowerCase();
      return s.firstName.toLowerCase().contains(query) || s.lastName.toLowerCase().contains(query) || s.email.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: primaryPink, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Honors & Awards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                      SizedBox(height: 3),
                      Text("Issue official certificates and grant special awards to top students.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // پیام سیستم (Toast)
          if (messageText != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isSuccessMessage ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSuccessMessage ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(isSuccessMessage ? Icons.check_circle_rounded : Icons.error_rounded, color: isSuccessMessage ? Colors.green : Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.green.shade800 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

          // ================= ۱. فرم صدور گواهینامه =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: cardBorder, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.card_membership_rounded, color: primaryPink, size: 20),
                    SizedBox(width: 8),
                    Text("Issue Certificate", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 18),

                // انتخاب شاگرد با جستجو
                const Text("Select Student *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (val) => setState(() => studentSearchQuery = val),
                  style: const TextStyle(color: textDark, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Search student by name or email...",
                    hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                    prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 18),
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStudentId,
                  dropdownColor: surfaceWhite,
                  style: const TextStyle(color: textDark, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                  items: filteredStudents.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.firstName} ${s.lastName} (${s.email})"))).toList(),
                  onChanged: (val) => setState(() => selectedStudentId = val),
                ),
                const SizedBox(height: 16),

                // انتخاب دوره
                const Text("Related Course *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedCourseId,
                  dropdownColor: surfaceWhite,
                  style: const TextStyle(color: textDark, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                  items: courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))).toList(),
                  onChanged: (val) => setState(() => selectedCourseId = val),
                ),
                const SizedBox(height: 16),

                // کد گواهینامه
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Certificate Code (ID) *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: _generateAutoCode,
                      child: const Text("✨ Auto Generate", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _certCodeController,
                  style: const TextStyle(color: textDark, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: "e.g. SAFI-2026-X89",
                    hintStyle: const TextStyle(color: textGrey),
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),

                // آپلود عکس گواهینامه
                const Text("Upload Certificate Image", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickImageFile,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded, color: primaryPink, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedImageFile != null ? selectedImageFile!.name : "Tap to pick image from gallery...",
                            style: TextStyle(color: selectedImageFile != null ? textDark : textGrey, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isSubmittingCert ? null : _handleIssueCertificate,
                    child: Text(isSubmittingCert ? "Issuing..." : "Issue Certificate 🚀", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ================= ۲. فرم اعطای نشان =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: cardBorder, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.military_tech_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text("Grant Special Award", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 18),

                const Text("Select Student *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedAwardStudentId,
                  dropdownColor: surfaceWhite,
                  style: const TextStyle(color: textDark, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                  items: students.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.firstName} ${s.lastName}"))).toList(),
                  onChanged: (val) => setState(() => selectedAwardStudentId = val),
                ),
                const SizedBox(height: 16),

                const Text("Select Badge / Award *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                awards.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: awards.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final award = awards[index];
                          bool isSelected = selectedAwardId == award.id;

                          return GestureDetector(
                            onTap: () => setState(() => selectedAwardId = award.id),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? lightPinkBg : cardBorder.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 1.5 : 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? primaryPink : primaryPink.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(award.iconUrl, style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(award.title, style: TextStyle(color: isSelected ? primaryPink : textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(award.description, style: const TextStyle(color: textGrey, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  if (isSelected) const Icon(Icons.check_circle_rounded, color: primaryPink, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : const Text("No awards configured in database.", style: TextStyle(color: textGrey, fontSize: 11)),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isSubmittingAward ? null : _handleGrantAward,
                    child: Text(isSubmittingAward ? "Granting..." : "Grant Award 🏆", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}