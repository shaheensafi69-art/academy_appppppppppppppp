import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSubmitting = false;
  Map<String, String>? message;

  List<Map<String, dynamic>> coursesList = [];
  List<Map<String, dynamic>> teachersList = [];

  // Controllers مطابق با ستون‌های جدول class_groups
  final classNameCtrl = TextEditingController();
  final scheduleInfoCtrl = TextEditingController();
  final classTimeCtrl = TextEditingController(text: "18:00 - 20:00");
  final classDaysCtrl = TextEditingController(text: "Saturday, Monday, Wednesday");
  final meetingLinkCtrl = TextEditingController();
  final signalGroupLinkCtrl = TextEditingController();

  String? selectedCourseId;
  String? selectedTeacherId;
  DateTime? startDate;
  DateTime? endDate;
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
    _fetchCoursesAndTeachers();
  }

  @override
  void dispose() {
    classNameCtrl.dispose();
    scheduleInfoCtrl.dispose();
    classTimeCtrl.dispose();
    classDaysCtrl.dispose();
    meetingLinkCtrl.dispose();
    signalGroupLinkCtrl.dispose();
    super.dispose();
  }

  /// واکشی دوره‌ها از جدول courses و اساتید از جدول profiles
  Future<void> _fetchCoursesAndTeachers() async {
    try {
      final coursesRes = await supabase
          .from("courses")
          .select("id, title, category")
          .order("title", ascending: true);

      final teachersRes = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url")
          .inFilter("role", ["teacher", "super_admin", "mentor"])
          .order("first_name", ascending: true);

      if (mounted) {
        setState(() {
          coursesList = (coursesRes as List?)?.cast<Map<String, dynamic>>() ?? [];
          teachersList = (teachersRes as List?)?.cast<Map<String, dynamic>>() ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses/teachers: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryPink,
              onPrimary: Colors.white,
              surface: surfaceWhite,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> handleCreateClass() async {
    if (classNameCtrl.text.trim().isEmpty || selectedCourseId == null || selectedTeacherId == null) {
      setState(() {
        message = {'type': 'error', 'text': 'Class Name, Course, and Teacher are required fields.'};
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      message = null;
    });

    try {
      await supabase.from("class_groups").insert({
        'course_id': selectedCourseId,
        'teacher_id': selectedTeacherId,
        'class_name': classNameCtrl.text.trim(),
        'schedule_info': scheduleInfoCtrl.text.trim().isNotEmpty ? scheduleInfoCtrl.text.trim() : null,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'meeting_link': meetingLinkCtrl.text.trim().isNotEmpty ? meetingLinkCtrl.text.trim() : null,
        'signal_group_link': signalGroupLinkCtrl.text.trim().isNotEmpty ? signalGroupLinkCtrl.text.trim() : null,
        'class_time': classTimeCtrl.text.trim().isNotEmpty ? classTimeCtrl.text.trim() : null,
        'class_days': classDaysCtrl.text.trim().isNotEmpty ? classDaysCtrl.text.trim() : null,
        'is_active': isActive,
      });

      setState(() {
        message = {'type': 'success', 'text': 'Class cohort successfully created and deployed! 🚀'};
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to create class: ${e.toString()}'};
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
              Text("LOADING SYSTEM DIRECTORIES...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
                        Text("Back to Cohorts", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
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
                              "COHORT MANAGEMENT",
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                            ),
                          ),
                          const Icon(Icons.class_rounded, color: primaryPink, size: 22),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Create New Class Cohort", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark)),
                      const SizedBox(height: 4),
                      const Text("Assign course, instructor, schedule and online links for students.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
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

                // 1. Course & Teacher Assignment Section
                _buildSection(
                  title: "1. Course & Instructor Assignment",
                  subtitle: "Link cohort to an active academic course and assign faculty lead",
                  children: [
                    const Text("SELECT COURSE *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _buildCourseCustomDropdown(),
                    const SizedBox(height: 16),

                    const Text("ASSIGN INSTRUCTOR *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _buildTeacherCustomDropdown(),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Class Details & Schedule
                _buildSection(
                  title: "2. Cohort Details & Schedule",
                  subtitle: "Define cohort title, meeting days and daily time slot",
                  children: [
                    _buildTextField("CLASS NAME *", classNameCtrl, "e.g. Batch 04 - Shopify Mastery"),
                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWide = constraints.maxWidth > 500;
                        return Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          children: [
                            Expanded(flex: isWide ? 1 : 0, child: _buildTextField("CLASS TIME SLOT", classTimeCtrl, "e.g. 18:00 - 20:00")),
                            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                            Expanded(flex: isWide ? 1 : 0, child: _buildTextField("CLASS DAYS", classDaysCtrl, "e.g. Sat, Mon, Wed")),
                          ],
                        );
                      },
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
                                  const Text("START DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: cardBorder.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: cardBorder, width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            startDate == null ? "Select start date" : "${startDate!.year}-${startDate!.month}-${startDate!.day}",
                                            style: TextStyle(color: startDate == null ? textGrey : textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: primaryPink),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("END DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: cardBorder.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: cardBorder, width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            endDate == null ? "Select end date" : "${endDate!.year}-${endDate!.month}-${endDate!.day}",
                                            style: TextStyle(color: endDate == null ? textGrey : textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: primaryPink),
                                        ],
                                      ),
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
                    _buildTextField("SCHEDULE INFO (NOTES)", scheduleInfoCtrl, "Additional schedule details or room info..."),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Online Links & Status
                _buildSection(
                  title: "3. Virtual Links & Status",
                  subtitle: "Zoom/Google Meet link and communication channel",
                  children: [
                    _buildTextField("MEETING LINK (ZOOM / MEET)", meetingLinkCtrl, "https://zoom.us/j/..."),
                    const SizedBox(height: 16),
                    _buildTextField("SIGNAL / TELEGRAM GROUP LINK", signalGroupLinkCtrl, "https://t.me/+..."),
                    const SizedBox(height: 16),

                    const Text("COHORT STATUS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _buildStatusCustomDropdown(),
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
                    onPressed: isSubmitting ? null : handleCreateClass,
                    child: isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("CREATE CLASS COHORT 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
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

  // 1. کشویی کاستومایز شده و کاملاً امن برای انتخاب دوره (Course)
  Widget _buildCourseCustomDropdown() {
    bool isValidValue = coursesList.any((crs) => crs['id'] == selectedCourseId);
    String? safeValue = isValidValue ? selectedCourseId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          hint: const Text("Choose academic course...", style: TextStyle(color: textGrey, fontSize: 11)),
          dropdownColor: surfaceWhite,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink),
          items: coursesList.map((crs) {
            return DropdownMenuItem<String>(
              value: crs['id']?.toString(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.menu_book_rounded, color: primaryPink, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(crs['title'] ?? '', style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(crs['category'] ?? 'General', style: const TextStyle(color: textGrey, fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => selectedCourseId = val),
        ),
      ),
    );
  }

  // 2. کشویی کاستومایز شده و کاملاً امن برای انتخاب مدرس (Teacher)
  Widget _buildTeacherCustomDropdown() {
    bool isValidValue = teachersList.any((t) => t['id'] == selectedTeacherId);
    String? safeValue = isValidValue ? selectedTeacherId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          hint: const Text("Choose instructor for this class...", style: TextStyle(color: textGrey, fontSize: 11)),
          dropdownColor: surfaceWhite,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink),
          items: teachersList.map((t) {
            String name = "${t['first_name'] ?? ''} ${t['last_name'] ?? ''}";
            return DropdownMenuItem<String>(
              value: t['id']?.toString(),
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
                          Text(t['email'] ?? '', style: const TextStyle(color: textGrey, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => selectedTeacherId = val),
        ),
      ),
    );
  }

  // 3. کشویی کاستومایز شده وضعیت کلاس (Active Status)
  Widget _buildStatusCustomDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool>(
          value: isActive,
          dropdownColor: surfaceWhite,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink),
          items: [
            DropdownMenuItem(
              value: true,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text("Active (Live Cohort)", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: textGrey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.history_rounded, color: textGrey, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text("Archived / Completed", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          onChanged: (val) => setState(() => isActive = val ?? true),
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

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
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