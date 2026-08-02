import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveClassItem {
  final String id;
  final String className;
  final bool isActive;
  final String? classTime;
  final String? classDays;
  final String? scheduleInfo;
  final String? startDate;
  final String? endDate;
  final String? meetingLink;
  final String? signalGroupLink;
  final String? courseTitle;
  final String? teacherFirstName;
  final String? teacherLastName;

  LiveClassItem({
    required this.id,
    required this.className,
    required this.isActive,
    this.classTime,
    this.classDays,
    this.scheduleInfo,
    this.startDate,
    this.endDate,
    this.meetingLink,
    this.signalGroupLink,
    this.courseTitle,
    this.teacherFirstName,
    this.teacherLastName,
  });

  factory LiveClassItem.fromJson(Map<String, dynamic> json) {
    final courseObj = json['course'];
    Map<String, dynamic>? formattedCourse = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;

    final teacherObj = json['teacher'];
    Map<String, dynamic>? formattedTeacher = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;

    return LiveClassItem(
      id: json['id'] ?? '',
      className: json['class_name'] ?? '',
      isActive: json['is_active'] ?? false,
      classTime: json['class_time'],
      classDays: json['class_days'],
      scheduleInfo: json['schedule_info'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      meetingLink: json['meeting_link'],
      signalGroupLink: json['signal_group_link'],
      courseTitle: formattedCourse?['title'],
      teacherFirstName: formattedTeacher?['first_name'],
      teacherLastName: formattedTeacher?['last_name'],
    );
  }
}

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<LiveClassItem> classes = [];
  String searchQuery = "";

  // Edit Modal State (Full Class Specifications & Links)
  LiveClassItem? selectedClass;
  final classNameCtrl = TextEditingController();
  final classTimeCtrl = TextEditingController();
  final classDaysCtrl = TextEditingController();
  final scheduleInfoCtrl = TextEditingController();
  final meetingLinkCtrl = TextEditingController();
  final signalLinkCtrl = TextEditingController();
  bool isClassActiveModal = true;
  bool isSaving = false;
  Map<String, String>? message;

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
    _fetchLiveClasses();
  }

  @override
  void dispose() {
    classNameCtrl.dispose();
    classTimeCtrl.dispose();
    classDaysCtrl.dispose();
    scheduleInfoCtrl.dispose();
    meetingLinkCtrl.dispose();
    signalLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveClasses() async {
    setState(() => isLoading = true);
    try {
      // تطابق کامل با فیلدهای جدول class_groups در دیتابیس شما
      final response = await supabase
          .from("class_groups")
          .select("id, class_name, is_active, class_time, class_days, schedule_info, start_date, end_date, meeting_link, signal_group_link, course:courses(title), teacher:profiles!teacher_id(first_name, last_name, avatar_url)")
          .order("is_active", ascending: false)
          .order("created_at", ascending: false);

      setState(() {
        classes = (response as List).map((c) => LiveClassItem.fromJson(c)).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching live classes: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<LiveClassItem> get filteredClasses {
    if (searchQuery.isEmpty) return classes;
    final query = searchQuery.toLowerCase();
    return classes.where((c) =>
      c.className.toLowerCase().contains(query) ||
      (c.courseTitle?.toLowerCase().contains(query) ?? false) ||
      (c.teacherFirstName?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  void openManageModal(LiveClassItem cls) {
    setState(() {
      selectedClass = cls;
      classNameCtrl.text = cls.className;
      classTimeCtrl.text = cls.classTime ?? "";
      classDaysCtrl.text = cls.classDays ?? "";
      scheduleInfoCtrl.text = cls.scheduleInfo ?? "";
      meetingLinkCtrl.text = cls.meetingLink ?? "";
      signalLinkCtrl.text = cls.signalGroupLink ?? "";
      isClassActiveModal = cls.isActive;
      message = null;
    });
  }

  Future<void> handleUpdateClassDetails() async {
    if (selectedClass == null) return;

    setState(() {
      isSaving = true;
      message = null;
    });

    try {
      String newName = classNameCtrl.text.trim();
      String? newTime = classTimeCtrl.text.trim().isNotEmpty ? classTimeCtrl.text.trim() : null;
      String? newDays = classDaysCtrl.text.trim().isNotEmpty ? classDaysCtrl.text.trim() : null;
      String? newSchedule = scheduleInfoCtrl.text.trim().isNotEmpty ? scheduleInfoCtrl.text.trim() : null;
      String? newMeeting = meetingLinkCtrl.text.trim().isNotEmpty ? meetingLinkCtrl.text.trim() : null;
      String? newSignal = signalLinkCtrl.text.trim().isNotEmpty ? signalLinkCtrl.text.trim() : null;

      // آپدیت کامل مشخصات کلاس در دیتابیس Supabase
      await supabase
          .from("class_groups")
          .update({
            'class_name': newName,
            'class_time': newTime,
            'class_days': newDays,
            'schedule_info': newSchedule,
            'meeting_link': newMeeting,
            'signal_group_link': newSignal,
            'is_active': isClassActiveModal,
          })
          .eq("id", selectedClass!.id);

      setState(() {
        classes = classes.map((c) => c.id == selectedClass!.id
            ? LiveClassItem(
                id: c.id,
                className: newName,
                isActive: isClassActiveModal,
                classTime: newTime,
                classDays: newDays,
                scheduleInfo: newSchedule,
                startDate: c.startDate,
                endDate: c.endDate,
                meetingLink: newMeeting,
                signalGroupLink: newSignal,
                courseTitle: c.courseTitle,
                teacherFirstName: c.teacherFirstName,
                teacherLastName: c.teacherLastName,
              )
            : c).toList();

        message = {'type': 'success', 'text': 'Class specifications & links updated!'};
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            selectedClass = null;
            message = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to update: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
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
              Text("ESTABLISHING LIVE CONNECTION...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredClasses;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
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
                          "LIVE STUDIO",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.podcasts_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Live Sessions & Cohorts",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Monitor active rooms, schedules, and manage all class properties securely.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: primaryPink, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => searchQuery = val),
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: "Search cohorts...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= LIVE CLASSES LIST =================
            currentFiltered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No live sessions found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentFiltered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final cls = currentFiltered[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                    color: cls.isActive ? Colors.green.withOpacity(0.12) : cardBorder,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cls.isActive ? "● LIVE COHORT" : "○ ARCHIVED",
                                    style: TextStyle(color: cls.isActive ? Colors.green.shade700 : textGrey, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Text(cls.courseTitle ?? 'General', style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(cls.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 12),

                            // Class Specifications
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded, color: textGrey, size: 14),
                                      const SizedBox(width: 6),
                                      Text("${cls.teacherFirstName ?? 'Unassigned'} ${cls.teacherLastName ?? ''}", style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                if (cls.classDays != null && cls.classDays!.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_month_rounded, color: textGrey, size: 14),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(cls.classDays!, style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (cls.classTime != null && cls.classTime!.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, color: textGrey, size: 14),
                                  const SizedBox(width: 6),
                                  Text(cls.classTime!, style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cls.meetingLink != null ? lightPinkBg : cardBorder,
                                      foregroundColor: cls.meetingLink != null ? primaryPink : textGrey,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.videocam_rounded, size: 16),
                                    label: Text(cls.meetingLink != null ? "Join Meeting" : "No Link", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                    onPressed: cls.meetingLink != null ? () => _launchURL(cls.meetingLink!) : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cardBorder,
                                    foregroundColor: textDark,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text("Manage", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  onPressed: () => openManageModal(cls),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),

      // Manage Modal BottomSheet (نمایش و ویرایش تمام مشخصات کلاس + لینک‌ها)
      bottomSheet: selectedClass != null
          ? Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -10))],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text("Manage Class: ${selectedClass!.className}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14), overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (!isSaving) setState(() => selectedClass = null);
                          },
                          child: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message!['type'] == 'success' ? Colors.green.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: message!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3), width: 1.5),
                        ),
                        child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // فیلدهای ویرایش تمام مشخصات کلاس
                    const Text("CLASS NAME *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: classNameCtrl,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _inputDecoration("e.g. Cohort Alpha - AI"),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CLASS DAYS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: classDaysCtrl,
                                style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                decoration: _inputDecoration("Mon, Wed, Fri"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CLASS TIME", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: classTimeCtrl,
                                style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                                decoration: _inputDecoration("18:00 - 20:00"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text("SCHEDULE INFO / NOTES", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: scheduleInfoCtrl,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _inputDecoration("Room details or extra schedule info..."),
                    ),
                    const SizedBox(height: 14),

                    const Text("MEETING URL (ZOOM / MEET)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: meetingLinkCtrl,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _inputDecoration("https://zoom.us/j/..."),
                    ),
                    const SizedBox(height: 14),

                    const Text("COMMUNICATION GROUP URL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: signalLinkCtrl,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _inputDecoration("https://t.me/..."),
                    ),
                    const SizedBox(height: 14),

                    // Active Status Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("COHORT ACTIVE STATUS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                        Switch(
                          value: isClassActiveModal,
                          activeThumbColor: primaryPink,
                          onChanged: (val) => setState(() => isClassActiveModal = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                        onPressed: isSaving ? null : handleUpdateClassDetails,
                        child: isSaving
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("SAVE & UPDATE ALL PROPERTIES 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  InputDecoration _inputDecoration(String hint) {
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