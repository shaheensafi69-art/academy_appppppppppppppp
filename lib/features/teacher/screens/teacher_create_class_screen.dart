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

      // 🛠 اصلاح کوئری برای جلوگیری از ارور کامپایل (استفاده از eq به جای filter)
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
        backgroundColor: const Color(0xFF030305),
        body: const Center(child: CircularProgressIndicator(color: Colors.pink)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Initialize Cohort", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Parent Course *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            courses.isNotEmpty
                ? DropdownButtonFormField<String>(
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
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Text("No courses available. Please create a course first.", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                  ),
            const SizedBox(height: 12),

            const Text("Classroom Name *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _classNameController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "e.g. Masterclass - Group 01",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Class Days *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: weekDays.map((day) {
                bool isSelected = selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => _toggleDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.pink.withOpacity(0.2) : Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.pinkAccent : Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(day.substring(0, 3), style: TextStyle(color: isSelected ? Colors.pinkAccent : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            const Text("Time (UTC/Local) *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _timeController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "e.g. 18:00 - 20:00",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const Text("Start Date", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _startDateController,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("End Date", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _endDateController,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
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

            const Text("Live Meeting Link", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _meetingLinkController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "Zoom / Teams URL",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Support Group Link", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _signalLinkController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: "Signal / WhatsApp URL",
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text("Activate Cohort", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              subtitle: Text("Allow students to see this class and its links.", style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
              value: isActive,
              activeThumbColor: Colors.pink,
              onChanged: (val) => setState(() => isActive = val),
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
                onPressed: isSubmitting || courses.isEmpty ? null : _handleSubmit,
                child: Text(isSubmitting ? "Initializing..." : "Create Class Cohort 🚀", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}