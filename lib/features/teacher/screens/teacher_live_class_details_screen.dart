import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'teacher_edit_class_screen.dart';
import 'teacher_class_students_screen.dart';

class LiveClassDetailsItem {
  final String id;
  final String className;
  final String classDays;
  final String classTime;
  final String? meetingLink;
  final String? signalGroupLink;
  final bool isActive;
  final int studentCount;
  final String courseTitle;
  final String? instructorName;
  final String? instructorBio;
  final String? instructorImageUrl;
  final String? instructor2Name;
  final String? instructor2Bio;
  final String? instructor2ImageUrl;

  LiveClassDetailsItem({
    required this.id,
    required this.className,
    required this.classDays,
    required this.classTime,
    this.meetingLink,
    this.signalGroupLink,
    required this.isActive,
    required this.studentCount,
    required this.courseTitle,
    this.instructorName,
    this.instructorBio,
    this.instructorImageUrl,
    this.instructor2Name,
    this.instructor2Bio,
    this.instructor2ImageUrl,
  });
}

class TeacherLiveClassDetailsScreen extends StatefulWidget {
  final String classId;
  const TeacherLiveClassDetailsScreen({super.key, required this.classId});

  @override
  State<TeacherLiveClassDetailsScreen> createState() => _TeacherLiveClassDetailsScreenState();
}

class _TeacherLiveClassDetailsScreenState extends State<TeacherLiveClassDetailsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  LiveClassDetailsItem? details;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from("class_groups")
          .select("id, class_name, class_days, class_time, meeting_link, signal_group_link, is_active, class_students(student_id), courses(title, instructor_name, instructor_bio, instructor_image_url, instructor_2_name, instructor_2_bio, instructor_2_image_url)")
          .eq("id", widget.classId)
          .maybeSingle();

      if (data != null) {
        final courseObj = data['courses'];
        final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;
        final students = data['class_students'] as List?;

        setState(() {
          details = LiveClassDetailsItem(
            id: data['id'],
            className: data['class_name'] ?? '',
            classDays: data['class_days'] ?? 'Not Set',
            classTime: data['class_time'] ?? 'Not Set',
            meetingLink: data['meeting_link'],
            signalGroupLink: data['signal_group_link'],
            isActive: data['is_active'] ?? false,
            studentCount: students != null ? students.length : 0,
            courseTitle: courseData?['title'] ?? 'Untitled Course',
            instructorName: courseData?['instructor_name'],
            instructorBio: courseData?['instructor_bio'],
            instructorImageUrl: courseData?['instructor_image_url'],
            instructor2Name: courseData?['instructor_2_name'],
            instructor2Bio: courseData?['instructor_2_bio'],
            instructor2ImageUrl: courseData?['instructor_2_image_url'],
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
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
        body: const Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    if (details == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(backgroundColor: surfaceWhite, elevation: 0, iconTheme: const IconThemeData(color: textDark)),
        body: const Center(child: Text("Class not found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold))),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(
          details!.className,
          style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= باکس وضعیت و نام کورس =================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: details!.isActive ? primaryPink : cardBorder, width: details!.isActive ? 2 : 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: details!.isActive ? primaryPink.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
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
                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                              child: Text(details!.courseTitle, style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: details!.isActive ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                details!.isActive ? "● Broadcast Active" : "○ Standby Mode",
                                style: TextStyle(
                                  color: details!.isActive ? Colors.green.shade700 : textGrey,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: primaryPink),
                            const SizedBox(width: 6),
                            Expanded(child: Text(details!.classDays, style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w600))),
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time_rounded, size: 14, color: primaryPink),
                            const SizedBox(width: 6),
                            Text(details!.classTime, style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        
                        // ریسپانسیو کردن دکمه‌های لانچ روم و ساینال برای صفحات کوچک
                        LayoutBuilder(
                          builder: (context, constraints) {
                            bool isWide = constraints.maxWidth > 400;
                            return Flex(
                              direction: isWide ? Axis.horizontal : Axis.vertical,
                              children: [
                                if (details!.meetingLink != null)
                                  Expanded(
                                    flex: isWide ? 1 : 0,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: details!.isActive ? primaryPink : textDark,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.video_call_rounded, size: 18),
                                        label: const Text("Launch Room", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () => _launchURL(details!.meetingLink!),
                                      ),
                                    ),
                                  ),
                                if (details!.meetingLink != null && details!.signalGroupLink != null)
                                  SizedBox(width: isWide ? 10 : 0, height: isWide ? 0 : 8),
                                if (details!.signalGroupLink != null)
                                  Expanded(
                                    flex: isWide ? 1 : 0,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: textDark,
                                          side: const BorderSide(color: cardBorder, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: primaryPink),
                                        label: const Text("Open Signal", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () => _launchURL(details!.signalGroupLink!),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ================= دکمه‌های ابزارهای سریع (ریسپانسیو) =================
                  const Text("Quick Operations", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWide = constraints.maxWidth > 400;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children: [
                          Expanded(
                            flex: isWide ? 1 : 0,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cardBorder.withValues(alpha: 0.5),
                                  foregroundColor: textDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.group_rounded, size: 16, color: primaryPink),
                                label: const Text("Manage Roster", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherClassStudentsScreen(classId: widget.classId)));
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: isWide ? 10 : 0, height: isWide ? 0 : 8),
                          Expanded(
                            flex: isWide ? 1 : 0,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cardBorder.withValues(alpha: 0.5),
                                  foregroundColor: textDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.settings_rounded, size: 16, color: primaryPink),
                                label: const Text("Class Settings", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherEditClassScreen(classId: widget.classId)))
                                      .then((_) => _fetchDetails());
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // ================= اساتید کلاس =================
                  const Text("Assigned Faculty Instructors", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: lightPinkBg,
                          backgroundImage: details!.instructorImageUrl != null ? NetworkImage(details!.instructorImageUrl!) : null,
                          child: details!.instructorImageUrl == null ? const Icon(Icons.person_rounded, color: primaryPink) : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("PRIMARY INSTRUCTOR", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(details!.instructorName ?? 'Verified Faculty', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(details!.instructorBio ?? 'Academy Instructor', style: const TextStyle(color: textGrey, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}