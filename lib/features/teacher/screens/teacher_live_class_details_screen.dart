import 'dart:ui';
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
        backgroundColor: const Color(0xFF030305),
        body: const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    if (details == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        appBar: AppBar(backgroundColor: Colors.black),
        body: const Center(child: Text("Class not found", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(details!.className, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // باکس وضعیت و نام کورس
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0a0f),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(details!.courseTitle, style: const TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: details!.isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(details!.isActive ? "Broadcast Active" : "Standby Mode", style: TextStyle(color: details!.isActive ? Colors.greenAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.purpleAccent),
                      const SizedBox(width: 6),
                      Text(details!.classDays, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 14, color: Colors.purpleAccent),
                      const SizedBox(width: 6),
                      Text(details!.classTime, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (details!.meetingLink != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, elevation: 0),
                            icon: const Icon(Icons.video_call, size: 16),
                            label: const Text("Launch Room", style: TextStyle(fontSize: 10)),
                            onPressed: () => _launchURL(details!.meetingLink!),
                          ),
                        ),
                      if (details!.meetingLink != null && details!.signalGroupLink != null) const SizedBox(width: 8),
                      if (details!.signalGroupLink != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white12)),
                            icon: const Icon(Icons.message, size: 16, color: Colors.pinkAccent),
                            label: const Text("Open Signal", style: TextStyle(fontSize: 10)),
                            onPressed: () => _launchURL(details!.signalGroupLink!),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // دکمه‌های ابزارهای سریع (Quick Operations)
            const Text("Quick Operations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05), foregroundColor: Colors.white, elevation: 0),
                    icon: const Icon(Icons.group, size: 16, color: Colors.purpleAccent),
                    label: const Text("Manage Roster", style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherClassStudentsScreen(classId: widget.classId)));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05), foregroundColor: Colors.white, elevation: 0),
                    icon: const Icon(Icons.settings, size: 16, color: Colors.pinkAccent),
                    label: const Text("Class Settings", style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherEditClassScreen(classId: widget.classId)))
                          .then((_) => _fetchDetails());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // اساتید کلاس
            const Text("Assigned Faculty Instructors", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0a0f),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    backgroundImage: details!.instructorImageUrl != null ? NetworkImage(details!.instructorImageUrl!) : null,
                    child: details!.instructorImageUrl == null ? const Icon(Icons.person, color: Colors.purpleAccent) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("PRIMARY INSTRUCTOR", style: TextStyle(color: Colors.purpleAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                        Text(details!.instructorName ?? 'Verified Faculty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(details!.instructorBio ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}