import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_live_class_details_screen.dart';

class LiveClassItem {
  final String id;
  final String className;
  final String classDays;
  final String classTime;
  final String? meetingLink;
  final String? signalGroupLink;
  final bool isActive;
  final int studentCount;
  final String? thumbnailUrl;
  final String category;

  LiveClassItem({
    required this.id,
    required this.className,
    required this.classDays,
    required this.classTime,
    this.meetingLink,
    this.signalGroupLink,
    required this.isActive,
    required this.studentCount,
    this.thumbnailUrl,
    required this.category,
  });
}

class TeacherLiveClassesScreen extends StatefulWidget {
  const TeacherLiveClassesScreen({super.key});

  @override
  State<TeacherLiveClassesScreen> createState() => _TeacherLiveClassesScreenState();
}

class _TeacherLiveClassesScreenState extends State<TeacherLiveClassesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<LiveClassItem> classGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveClasses();
  }

  Future<void> _fetchLiveClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final classesData = await supabase
          .from("class_groups")
          .select("id, class_name, class_days, class_time, meeting_link, signal_group_link, is_active, class_students(student_id), courses(thumbnail_url, category)")
          .eq("teacher_id", user.id)
          .order("is_active", ascending: false);

      if (classesData != null) {
        classGroups = (classesData as List).map((cls) {
          final courseObj = cls['courses'];
          final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;
          final students = cls['class_students'] as List?;

          return LiveClassItem(
            id: cls['id'] ?? '',
            className: cls['class_name'] ?? '',
            classDays: cls['class_days'] ?? 'Not Set',
            classTime: cls['class_time'] ?? 'Not Set',
            meetingLink: cls['meeting_link'],
            signalGroupLink: cls['signal_group_link'],
            isActive: cls['is_active'] ?? false,
            studentCount: students != null ? students.length : 0,
            thumbnailUrl: courseData?['thumbnail_url'],
            category: courseData?['category'] ?? 'Live Cohort',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error syncing live classes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر صفحه
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
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Text("🔴", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Live Streaming", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: 2),
                    Text("Launch live lectures and manage active channels.", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text("Active Broadcasts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
              : classGroups.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: classGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cls = classGroups[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cls.isActive ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
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
                                    child: Text(cls.category, style: const TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: cls.isActive ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cls.isActive ? "LIVE NOW" : "Standby",
                                      style: TextStyle(color: cls.isActive ? Colors.redAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(cls.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text("📅 ${cls.classDays} | 🕒 ${cls.classTime}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("👥 ${cls.studentCount} Students Enrolled", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => TeacherLiveClassDetailsScreen(classId: cls.id)),
                                      );
                                    },
                                    child: const Text("Manage Class", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text("No live broadcasts available.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}