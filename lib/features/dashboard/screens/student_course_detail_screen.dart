import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class StudentCourseDetailScreen extends StatefulWidget {
  final String courseId;
  const StudentCourseDetailScreen({super.key, required this.courseId});

  @override
  State<StudentCourseDetailScreen> createState() => _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isEnrolling = false;
  Map<String, dynamic>? courseData;
  List<Map<String, dynamic>> classGroups = [];

  // استیت‌های فرم ثبت‌نام
  bool showRegistrationForm = false;
  bool isLoadingClasses = false;
  String selectedClassGroupId = "";
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  String selectedInstructor = "";

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
    _fetchCourseDetailsAndClasses();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCourseDetailsAndClasses() async {
    setState(() => isLoading = true);
    try {
      // ۱. واکشی جزئیات دوره از جدول courses
      final res = await supabase
          .from("courses")
          .select("*")
          .eq("id", widget.courseId)
          .single();

      // ۲. واکشی کلاس‌های فعال جدول class_groups برای این دوره
      final groupsRes = await supabase
          .from("class_groups")
          .select("id, class_name, class_time, class_days, schedule_info")
          .eq("course_id", widget.courseId)
          .eq("is_active", true);

      List<Map<String, dynamic>> groups = [];
      if (groupsRes != null && groupsRes is List) {
        groups = List<Map<String, dynamic>>.from(groupsRes);
      }

      String initialInstructor = res['instructor_name'] ?? res['instructor'] ?? 'Safi Academy Faculty';

      setState(() {
        courseData = res;
        classGroups = groups;
        if (groups.isNotEmpty) {
          selectedClassGroupId = groups[0]['id'].toString();
        }
        selectedInstructor = initialInstructor;
        isLoading = false;
      });

      // پر کردن خودکار ایمیل کاربر اگر لاگین باشد
      final user = supabase.auth.currentUser;
      if (user != null && user.email != null) {
        _emailController.text = user.email!;
      }
    } catch (e) {
      debugPrint("Error fetching course details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleRegistrationSubmit() async {
    if (_fullNameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isEnrolling = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication required. Please login first."), backgroundColor: Colors.redAccent),
        );
        return;
      }

      // درج در جدول enrollments
      await supabase.from("enrollments").insert({
        'student_id': user.id,
        'course_id': widget.courseId,
        'progress_percentage': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration & Seat Reservation Successful! 🎉"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Registration error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are already enrolled or an error occurred."), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isEnrolling = false);
    }
  }

  void _shareCourse() {
    final link = "https://safiacademy.org/courses/${widget.courseId}";
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Course master link copied to clipboard! 🔗"), backgroundColor: Colors.green),
    );
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
              Text("LOADING COURSE DETAILS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (courseData == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(backgroundColor: surfaceWhite, elevation: 0, iconTheme: const IconThemeData(color: textDark)),
        body: const Center(child: Text("Course not found.", style: TextStyle(color: textDark, fontWeight: FontWeight.bold))),
      );
    }

    // استخراج اساتید دوره
    List<String> instructorOptions = [];
    if (courseData!['instructor_name'] != null) instructorOptions.add(courseData!['instructor_name']);
    if (courseData!['instructor_2_name'] != null) instructorOptions.add(courseData!['instructor_2_name']);
    if (instructorOptions.isEmpty) instructorOptions.add("Safi Academy Faculty");

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= هدر (دکمه بازگشت و اشتراک‌گذاری) =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder, width: 1.5)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, color: textDark, size: 16),
                          SizedBox(width: 6),
                          Text("Back", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: lightPinkBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.share_rounded, color: primaryPink, size: 18),
                    onPressed: _shareCourse,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ================= عکس و عنوان اصلی =================
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  courseData!['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&q=80&w=800',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 200, color: cardBorder),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                child: Text((courseData!['category'] ?? 'Trading').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink)),
              ),
              const SizedBox(height: 8),
              Text(courseData!['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark)),
              const SizedBox(height: 8),
              Text("Lead Instructor: ${courseData!['instructor_name'] ?? 'Safi Academy'}", style: const TextStyle(fontSize: 12, color: textGrey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // ================= ویژگی‌ها (مدت‌زمان، گواهینامه، قیمت) =================
              Row(
                children: [
                  _buildDetailBadge(Icons.timer_rounded, "${courseData!['duration_weeks'] ?? 4} Weeks"),
                  const SizedBox(width: 10),
                  _buildDetailBadge(Icons.emoji_events_rounded, (courseData!['includes_certificate'] ?? true) ? "Includes Certificate" : "No Certificate"),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  _buildDetailBadge(Icons.attach_money_rounded, (courseData!['price'] ?? 0) > 0 ? "\$${(courseData!['price'] as num).toStringAsFixed(2)}" : "FREE SESSION"),
                  const SizedBox(width: 10),
                  _buildDetailBadge(Icons.language_rounded, courseData!['language'] ?? 'English'),
                ],
              ),
              const SizedBox(height: 24),

              // ================= درباره دوره =================
              const Text("About Masterclass", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
              const SizedBox(height: 8),
              Text(courseData!['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500, height: 1.5)),
              const SizedBox(height: 24),

              // ================= لیست مدرسین (Instructors Section) =================
              const Text("Meet Your Instructors", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
              const SizedBox(height: 12),
              _buildInstructorCard(
                name: courseData!['instructor_name'] ?? 'Prof. Alex Safi',
                bio: courseData!['instructor_bio'] ?? 'Senior Trading Mentor & Academy Founder.',
                imageUrl: courseData!['instructor_image_url'],
              ),
              if (courseData!['instructor_2_name'] != null && courseData!['instructor_2_name'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildInstructorCard(
                  name: courseData!['instructor_2_name'],
                  bio: courseData!['instructor_2_bio'] ?? 'Professional Market Analyst.',
                  imageUrl: courseData!['instructor_2_image_url'],
                ),
              ],
              const SizedBox(height: 30),

              // ================= دکمه باز کردن فرم ثبت‌نام / رزرو کلاس =================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showRegistrationForm ? cardBorder : primaryPink,
                    foregroundColor: showRegistrationForm ? textDark : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => setState(() => showRegistrationForm = !showRegistrationForm),
                  child: Text(
                    showRegistrationForm ? "Close Registration Form" : "Reserve Your Seat & Class 🚀",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                  ),
                ),
              ),

              // ================= فرم ثبت‌نام حرفه‌ای (متصل به تلگرام و کلاس‌ها) =================
              if (showRegistrationForm) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Secure Registration & Schedule", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
                      const SizedBox(height: 4),
                      const Text("Fill out your details to finalize enrollment and class timing.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // Full Name
                      const Text("FULL NAME *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fullNameController,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration("John Doe"),
                      ),
                      const SizedBox(height: 14),

                      // Father's Name
                      const Text("FATHER'S NAME *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fatherNameController,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration("Michael Doe"),
                      ),
                      const SizedBox(height: 14),

                      // Email
                      const Text("EMAIL ADDRESS *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration("you@example.com"),
                      ),
                      const SizedBox(height: 14),

                      // WhatsApp Number
                      const Text("WHATSAPP NUMBER *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration("+1 234 567 8900"),
                      ),
                      const SizedBox(height: 14),

                      // Preferred Instructor
                      const Text("PREFERRED INSTRUCTOR *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(16)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: instructorOptions.contains(selectedInstructor) ? selectedInstructor : instructorOptions[0],
                            isExpanded: true,
                            items: instructorOptions.map((inst) {
                              return DropdownMenuItem(value: inst, child: Text(inst, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedInstructor = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Class Group Selection
                      const Text("SELECT CLASS & SCHEDULE *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink)),
                      const SizedBox(height: 6),
                      classGroups.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(16)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: classGroups.any((g) => g['id'].toString() == selectedClassGroupId) ? selectedClassGroupId : classGroups[0]['id'].toString(),
                                  isExpanded: true,
                                  items: classGroups.map((group) {
                                    return DropdownMenuItem(
                                      value: group['id'].toString(),
                                      child: Text(
                                        "${group['class_name']} | ⏰ ${group['class_time']} | 📅 ${group['class_days']}",
                                        style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => selectedClassGroupId = val);
                                  },
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                              child: const Text("No active class schedule listed. You can register and support will assign your batch.", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                      const SizedBox(height: 14),

                      // Notes
                      const Text("ADDITIONAL NOTES (OPTIONAL)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration("Any specific questions..."),
                      ),
                      const SizedBox(height: 20),

                      // Submit Registration Button
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
                          onPressed: isEnrolling ? null : _handleRegistrationSubmit,
                          child: isEnrolling
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text("Finalize Registration & Telegram Sync 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBadge(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder, width: 1.5)),
        child: Row(
          children: [
            Icon(icon, color: primaryPink, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCard({required String name, required String bio, String? imageUrl}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: lightPinkBg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: primaryPink))
                  : const Icon(Icons.person, color: primaryPink),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Text(bio, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
      filled: true,
      fillColor: cardBorder.withOpacity(0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
    );
  }
}