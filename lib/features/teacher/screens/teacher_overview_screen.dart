import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClassGroupItem {
  final String id;
  final String className;
  final String scheduleInfo;
  final bool isActive;
  final String startDate;
  final int enrolledCount;
  final String? meetingLink;
  final String? signalGroupLink;

  ClassGroupItem({
    required this.id,
    required this.className,
    required this.scheduleInfo,
    required this.isActive,
    required this.startDate,
    required this.enrolledCount,
    this.meetingLink,
    this.signalGroupLink,
  });

  factory ClassGroupItem.fromJson(Map<String, dynamic> json) {
    final students = json['class_students'] as List?;
    return ClassGroupItem(
      id: json['id'] ?? '',
      className: json['class_name'] ?? 'Untitled Class',
      scheduleInfo: json['schedule_info'] ?? '',
      isActive: json['is_active'] ?? false,
      startDate: json['start_date'] ?? '',
      enrolledCount: students != null ? students.length : 0,
      meetingLink: json['meeting_link'],
      signalGroupLink: json['signal_group_link'],
    );
  }
}

class TeacherOverviewScreen extends StatefulWidget {
  const TeacherOverviewScreen({super.key});

  @override
  State<TeacherOverviewScreen> createState() => _TeacherOverviewScreenState();
}

class _TeacherOverviewScreenState extends State<TeacherOverviewScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  Map<String, dynamic> instructor = {
    'first_name': 'Instructor',
    'last_name': '',
    'avatar': '',
    'email': '',
    'wallet': 0.0,
  };

  Map<String, int> stats = {
    'totalStudents': 0,
    'totalClasses': 0,
    'pendingGrading': 0,
    'todayAttendance': 0,
  };

  List<ClassGroupItem> classes = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // ۱. دریافت پروفایل استاد
      final profile = await supabase
          .from("profiles")
          .select("first_name, last_name, avatar_url, email, wallet_balance")
          .eq("id", userId)
          .maybeSingle();

      if (profile != null) {
        instructor = {
          'first_name': profile['first_name'] ?? 'Instructor',
          'last_name': profile['last_name'] ?? '',
          'avatar': profile['avatar_url'] ?? '',
          'email': profile['email'] ?? user.email ?? '',
          'wallet': (profile['wallet_balance'] ?? 0).toDouble(),
        };
      }

      // ۲. دریافت کلاس‌های استاد همراه با تعداد دانشجویان
      final classData = await supabase
          .from("class_groups")
          .select("id, class_name, schedule_info, is_active, start_date, meeting_link, signal_group_link, class_students(student_id)")
          .eq("teacher_id", userId)
          .order("is_active", ascending: false)
          .order("start_date", ascending: true)
          .limit(4);

      int totalStudentsCount = 0;
      List<String> classIds = [];

      if (classData != null) {
        classIds = (classData as List).map((c) => c['id'].toString()).toList();
        classes = (classData as List).map((cls) {
          final item = ClassGroupItem.fromJson(cls);
          totalStudentsCount += item.enrolledCount;
          return item;
        }).toList();
      }

      // ۳. استخراج تعداد تکالیف در انتظار نمره
      int pendingCount = 0;
      final myCourses = await supabase.from("courses").select("id").eq("teacher_id", userId);

      if (myCourses != null && (myCourses as List).isNotEmpty) {
        final courseIds = myCourses.map((c) => c['id']).toList();
        final myAssignments = await supabase.from("assignments").select("id").inFilter("course_id", courseIds);

        if (myAssignments != null && (myAssignments as List).isNotEmpty) {
          final assignmentIds = myAssignments.map((a) => a['id']).toList();
          final countRes = await supabase
              .from("assignment_submissions")
              .select("id")
              .inFilter("assignment_id", assignmentIds)
              .isFilter("grade", null);

          pendingCount = (countRes as List?)?.length ?? 0;
        }
      }

      // ۴. سیستم حاضر غیاب هوشمند امروز
      int todayAttCount = 0;
      if (classIds.isNotEmpty) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final attRes = await supabase
            .from("attendance_logs")
            .select("id")
            .inFilter("class_group_id", classIds)
            .eq("session_date", today)
            .eq("status", "present");

        todayAttCount = (attRes as List?)?.length ?? 0;
      }

      setState(() {
        stats = {
          'totalStudents': totalStudentsCount,
          'totalClasses': classes.length,
          'pendingGrading': pendingCount,
          'todayAttendance': todayAttCount,
        };
      });
    } catch (e) {
      debugPrint("Error loading teacher dashboard: $e");
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.pink),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= ۱. باکس پروفایل استاد =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF261026), Color(0xFF0a0a0f)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.pink.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.pink.withOpacity(0.2),
                  backgroundImage: instructor['avatar'].isNotEmpty ? NetworkImage(instructor['avatar']) : null,
                  child: instructor['avatar'].isEmpty
                      ? Text(instructor['first_name'][0], style: const TextStyle(color: Colors.pinkAccent, fontSize: 20, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.pink.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text("ACADEMY INSTRUCTOR", style: TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.pinkAccent)),
                      ),
                      const SizedBox(height: 4),
                      Text("${instructor['first_name']} ${instructor['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(instructor['email'], style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("WALLET", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("\$${instructor['wallet'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= ۲. کارت‌های آمار زنده (4 ستونه) =================
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard("Students", "${stats['totalStudents']}", "👥", Colors.indigoAccent),
              _buildStatCard("Live Classes", "${stats['totalClasses']}", "🔴", Colors.pinkAccent),
              _buildStatCard("Needs Grading", "${stats['pendingGrading']}", "📝", Colors.orangeAccent),
              _buildStatCard("Present Today", "${stats['todayAttendance']}", "✅", Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 20),

          // ================= ۳. فرماندهی کلاس‌ها (Command Center) =================
          const Text("Command Center", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),

          classes.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final room = classes[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: room.isActive ? const Color(0xFF260d13).withOpacity(0.8) : const Color(0xFF0a0a0f).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: room.isActive ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: room.isActive ? Colors.red : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(room.isActive ? "LIVE NOW" : "STANDBY", style: TextStyle(color: room.isActive ? Colors.black : Colors.grey, fontSize: 8, fontWeight: FontWeight.w900)),
                              ),
                              Text("${room.enrolledCount} Students Enrolled", style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(room.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text("Schedule: ${room.scheduleInfo}", style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (room.meetingLink != null)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: room.isActive ? Colors.red : Colors.white.withOpacity(0.1),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.video_call, size: 14),
                                    label: const Text("Launch Teams", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    onPressed: () => _launchURL(room.meetingLink!),
                                  ),
                                ),
                              if (room.meetingLink != null && room.signalGroupLink != null) const SizedBox(width: 8),
                              if (room.signalGroupLink != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: Colors.indigo.withOpacity(0.3)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.message, color: Colors.indigoAccent, size: 14),
                                    label: const Text("Open Signal", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    onPressed: () => _launchURL(room.signalGroupLink!),
                                  ),
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
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text("You are not assigned to any active classrooms yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 1),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}