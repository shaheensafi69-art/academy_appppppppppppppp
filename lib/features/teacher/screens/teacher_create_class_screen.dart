import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseOption {
  final String id;
  final String title;

  CourseOption({required this.id, required this.title});
}

const List<String> weekDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

class TeacherCreateClassScreen extends StatefulWidget {
  const TeacherCreateClassScreen({super.key});

  @override
  State<TeacherCreateClassScreen> createState() => _TeacherCreateClassScreenState();
}

class _TeacherCreateClassScreenState extends State<TeacherCreateClassScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;

  List<CourseOption> courses = [];
  String? selectedCourseId;

  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _scheduleInfoController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _meetingLinkController = TextEditingController();
  final TextEditingController _signalLinkController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final List<String> selectedDays = [];
  bool isActive = true;

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
    _fetchTeacherCourses();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _scheduleInfoController.dispose();
    _timeController.dispose();
    _meetingLinkController.dispose();
    _signalLinkController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeacherCourses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .maybeSingle();

      final userRole = profile?['role']?.toString().toLowerCase() ?? 'student';
      bool isAdmin = userRole == 'admin' || userRole == 'super_admin';

      var queryBuilder = supabase.from("courses").select("id, title");

      dynamic response;
      if (!isAdmin) {
        response = await queryBuilder.eq("teacher_id", user.id).order("created_at", ascending: false);
      } else {
        response = await queryBuilder.order("created_at", ascending: false);
      }

      if (response != null && (response as List).isNotEmpty) {
        setState(() {
          courses = response.map<CourseOption>((c) => CourseOption(id: c['id'], title: c['title'])).toList();
          selectedCourseId = courses[0].id;
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (selectedDays.contains(day)) {
        selectedDays.remove(day);
      } else {
        selectedDays.add(day);
      }
    });
  }

  Future<void> _handleSubmit() async {
    final user = supabase.auth.currentUser;
    if (user == null || selectedCourseId == null) return;

    if (_classNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Classroom Name is required."), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one class day."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final daysString = selectedDays.join(", ");

      await supabase.from("class_groups").insert({
        'course_id': selectedCourseId,
        'teacher_id': user.id,
        'class_name': _classNameController.text.trim(),
        'schedule_info': _scheduleInfoController.text.trim().isEmpty ? null : _scheduleInfoController.text.trim(),
        'start_date': _startDateController.text.trim().isEmpty ? null : _startDateController.text.trim(),
        'end_date': _endDateController.text.trim().isEmpty ? null : _endDateController.text.trim(),
        'meeting_link': _meetingLinkController.text.trim().isEmpty ? null : _meetingLinkController.text.trim(),
        'signal_group_link': _signalLinkController.text.trim().isEmpty ? null : _signalLinkController.text.trim(),
        'class_time': _timeController.text.trim().isEmpty ? null : _timeController.text.trim(),
        'class_days': daysString,
        'is_active': isActive,
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Failed to create class cohort: $e");
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
        title: const Text("Initialize Cohort", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
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
            // انتخاب دوره مرجع
            const Text("Parent Course *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            courses.isNotEmpty
                ? DropdownButtonFormField<String>(
                    initialValue: selectedCourseId,
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
                    items: courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))).toList(),
                    onChanged: (val) => setState(() => selectedCourseId = val),
                  )
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Text("No courses available. Please create a course first.", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 16),

            // نام کلاس
            const Text("Classroom Name *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _classNameController,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g. Masterclass - Group 01",
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

            // اطلاعات برنامه
            const Text("Schedule Information", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _scheduleInfoController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "e.g. Evening Shift / Weekend Cohort",
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

            // روزهای هفته
            const Text("Class Days *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weekDays.map((day) {
                bool isSelected = selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => _toggleDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? lightPinkBg : cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 1.5 : 1),
                    ),
                    child: Text(
                      day.substring(0, 3),
                      style: TextStyle(color: isSelected ? primaryPink : textDark, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ساعت کلاس
            const Text("Class Time *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _timeController,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g. 18:00 - 20:00",
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

            // تاریخ شروع و پایان
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Start Date", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _startDateController,
                        style: const TextStyle(color: textDark, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("End Date", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _endDateController,
                        style: const TextStyle(color: textDark, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
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

            // لینک جلسه آنلاین
            const Text("Live Meeting Link", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _meetingLinkController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Zoom / Teams URL",
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

            // لینک گروه پشتیبانی
            const Text("Support Group Link", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _signalLinkController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Signal / WhatsApp URL",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            // وضعیت فعال بودن کلاس
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.5),
              ),
              child: SwitchListTile(
                title: const Text("Activate Cohort", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
                subtitle: const Text("Allow students to see this class and its links.", style: TextStyle(color: textGrey, fontSize: 10)),
                value: isActive,
                activeThumbColor: primaryPink,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => isActive = val),
              ),
            ),
            const SizedBox(height: 30),

            // دکمه ثبت نهایی
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
                onPressed: isSubmitting || courses.isEmpty ? null : _handleSubmit,
                child: Text(isSubmitting ? "Initializing..." : "Create Class Cohort 🚀", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}