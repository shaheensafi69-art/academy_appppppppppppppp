import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/auth_gate.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;
  bool isLoggingOut = false;
  Map<String, String>? message;

  // Controllers مطابق با جداول دیتابیس (profiles و teacher_info)
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final avatarCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  final achievementsCtrl = TextEditingController();

  String role = "teacher";
  int totalScore = 0;
  double walletBalance = 0;
  String userId = "";

  List<Map<String, dynamic>> teacherCourses = [];
  List<Map<String, dynamic>> teacherClasses = [];

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchAdminAndFacultyData();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    avatarCtrl.dispose();
    bioCtrl.dispose();
    achievementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminAndFacultyData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _logout();
        return;
      }

      userId = user.id;

      // 1. دریافت اطلاعات از جدول profiles
      final profile = await supabase
          .from("profiles")
          .select("*")
          .eq("id", userId)
          .single();

      firstNameCtrl.text = profile['first_name'] ?? "";
      lastNameCtrl.text = profile['last_name'] ?? "";
      emailCtrl.text = profile['email'] ?? "";
      phoneCtrl.text = profile['phone_number'] ?? "";
      avatarCtrl.text = profile['avatar_url'] ?? "";
      bioCtrl.text = profile['bio'] ?? "";

      role = profile['role'] ?? "teacher";
      totalScore = profile['total_score'] ?? 0;
      walletBalance = (profile['wallet_balance'] ?? 0).toDouble();

      // 2. دریافت اطلاعات از جدول teacher_info
      try {
        final info = await supabase
            .from("teacher_info")
            .select("*")
            .eq("id", userId)
            .maybeSingle();

        if (info != null) {
          bioCtrl.text = info['bio'] ?? bioCtrl.text;
          achievementsCtrl.text = info['achievements'] ?? "";
          if (info['avatar_url'] != null && avatarCtrl.text.isEmpty) {
            avatarCtrl.text = info['avatar_url'];
          }
        }
      } catch (_) {}

      // 3. دریافت دوره‌ها و تخصص‌های مرتبط از teacher_info_courses و courses
      try {
        final tCourses = await supabase
            .from("teacher_info_courses")
            .select("course:courses(id, title, category)")
            .eq("teacher_info_id", userId);

        teacherCourses = (tCourses as List).map((tc) => tc['course'] as Map<String, dynamic>).toList();
      } catch (_) {}

      // 4. دریافت کلاس‌های مرتبط از class_groups
      try {
        final classesData = await supabase
            .from("class_groups")
            .select("id, class_name, is_active, course:courses(title), class_students(student_id)")
            .eq("teacher_id", userId);

        teacherClasses = (classesData as List).map((cls) {
          return {
            'class_name': cls['class_name'],
            'is_active': cls['is_active'],
            'students_count': (cls['class_students'] as List?)?.length ?? 0,
            'course_title': cls['course'] != null ? (cls['course'] is List ? cls['course'][0]['title'] : cls['course']['title']) : 'General'
          };
        }).toList();
      } catch (_) {}

    } catch (e) {
      debugPrint("Error fetching faculty settings profile: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleSaveChanges() async {
    setState(() {
      isSaving = true;
      message = null;
    });

    try {
      String fName = firstNameCtrl.text.trim();
      String lName = lastNameCtrl.text.trim();
      String email = emailCtrl.text.trim();
      String phone = phoneCtrl.text.trim();
      String bio = bioCtrl.text.trim();
      String achievements = achievementsCtrl.text.trim();
      String avatar = avatarCtrl.text.trim();

      // آپدیت جدول profiles
      await supabase
          .from("profiles")
          .update({
            'first_name': fName,
            'last_name': lName,
            'email': email,
            'phone_number': phone.isNotEmpty ? phone : null,
            'bio': bio.isNotEmpty ? bio : null,
            'avatar_url': avatar.isNotEmpty ? avatar : null,
            'role': role,
          })
          .eq("id", userId);

      // آپدیت جدول teacher_info
      await supabase.from("teacher_info").upsert({
        'id': userId,
        'first_name': fName,
        'last_name': lName,
        'bio': bio.isNotEmpty ? bio : null,
        'achievements': achievements.isNotEmpty ? achievements : null,
        'avatar_url': avatar.isNotEmpty ? avatar : null,
      });

      setState(() {
        message = {'type': 'success', 'text': 'Faculty profile, role & system configurations synced successfully! 🚀'};
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => message = null);
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to update configuration: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  Future<void> handleLogoutButton() async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: cardBorder, width: 1.5)),
        title: const Text("Secure Logout", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to securely log out of the command center?", style: TextStyle(color: textGrey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmLogout != true) return;

    setState(() => isLoggingOut = true);
    await _logout();
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
              Text("SYNCHRONIZING FACULTY ENGINE...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
                // ================= HEADER (ریسپانسیو برای جلوگیری از اورفلو) =================
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "SYSTEM SETTINGS & PROFILE",
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.12),
                              foregroundColor: Colors.redAccent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                            ),
                            icon: isLoggingOut ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)) : const Icon(Icons.logout_rounded, size: 16),
                            label: Text(isLoggingOut ? "Logging out..." : "Logout", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            onPressed: isLoggingOut ? null : handleLogoutButton,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Faculty & System Control",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Manage your master profile, teacher info, specialized courses & classes.",
                        style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                      ),
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
                        Icon(message!['type'] == 'success' ? Icons.check_circle_rounded : Icons.error_rounded, color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ================= SECTION 1: IDENTITY & PROFILES =================
                Container(
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
                      const Text("FACULTY IDENTITY & ROLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                      const SizedBox(height: 16),

                      // Avatar
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: lightPinkBg,
                            backgroundImage: avatarCtrl.text.trim().isNotEmpty ? NetworkImage(avatarCtrl.text.trim()) : null,
                            child: avatarCtrl.text.trim().isEmpty ? Text(firstNameCtrl.text.isNotEmpty ? firstNameCtrl.text[0] : 'T', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 16)) : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("AVATAR URL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: avatarCtrl,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                  decoration: _inputFieldDecoration("https://..."),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Names
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("FIRST NAME *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                const SizedBox(height: 6),
                                TextField(controller: firstNameCtrl, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold), decoration: _inputFieldDecoration("First Name")),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("LAST NAME *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                const SizedBox(height: 6),
                                TextField(controller: lastNameCtrl, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold), decoration: _inputFieldDecoration("Last Name")),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text("EMAIL ADDRESS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      TextField(controller: emailCtrl, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold), decoration: _inputFieldDecoration("Email address")),
                      const SizedBox(height: 16),

                      const Text("PHONE NUMBER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold), decoration: _inputFieldDecoration("Phone number")),
                      const SizedBox(height: 16),

                      // System Role Dropdown
                      const Text("SYSTEM ROLE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        dropdownColor: surfaceWhite,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputFieldDecoration("Select role"),
                        items: const [
                          DropdownMenuItem(value: 'teacher', child: Text("Instructor / Mentor (Teacher)")),
                          DropdownMenuItem(value: 'super_admin', child: Text("Administrator (Super Admin)")),
                          DropdownMenuItem(value: 'student', child: Text("Student (Normal)")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => role = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= SECTION 2: TEACHER INFO =================
                Container(
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
                      const Text("TEACHER INFO & CREDENTIALS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                      const SizedBox(height: 16),

                      const Text("BIOGRAPHY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bioCtrl,
                        maxLines: 4,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputFieldDecoration("Write comprehensive professional biography..."),
                      ),
                      const SizedBox(height: 16),

                      const Text("ACHIEVEMENTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: achievementsCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputFieldDecoration("List certifications, awards or milestones..."),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= SECTION 3: SPECIALIZED COURSES & CLASSES =================
                Container(
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
                      const Text("SPECIALIZED COURSES (TEACHER INFO COURSES)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      teacherCourses.isEmpty
                          ? const Text("No specialized courses linked.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: teacherCourses.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final crs = teacherCourses[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardBorder.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(crs['title'] ?? 'Course', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                        child: Text(crs['category'] ?? 'General', style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 20),

                      const Text("ASSIGNED CLASSES (CLASS GROUPS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      teacherClasses.isEmpty
                          ? const Text("No active classes assigned.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: teacherClasses.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final cls = teacherClasses[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardBorder.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(cls['class_name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text("Course: ${cls['course_title']}", style: const TextStyle(color: textGrey, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                        child: Text("${cls['students_count']} Students", style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
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
                    onPressed: isSaving ? null : handleSaveChanges,
                    child: isSaving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("SAVE CONFIGURATION & SYNC 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
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