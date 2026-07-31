import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClassGroup {
  final String id;
  final String className;
  final String scheduleInfo;
  final bool isActive;
  final String startDate;
  final String? meetingLink;
  final String? signalGroupLink;
  final bool isPaid; // وضعیت تأیید پرداخت از جدول class_students
  final Map<String, dynamic>? teacher;

  ClassGroup({
    required this.id,
    required this.className,
    required this.scheduleInfo,
    required this.isActive,
    required this.startDate,
    this.meetingLink,
    this.signalGroupLink,
    required this.isPaid,
    this.teacher,
  });

  factory ClassGroup.fromJson(Map<String, dynamic> json, String userId) {
    final studentRelationObj = json['class_students'];
    final studentRelation = studentRelationObj is List
        ? studentRelationObj.firstWhere((cs) => cs['student_id'] == userId, orElse: () => null)
        : studentRelationObj;

    final teacherObj = json['teacher'];
    final teacherData = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;

    return ClassGroup(
      id: json['id'] ?? '',
      className: json['class_name'] ?? 'Unknown Class',
      scheduleInfo: json['schedule_info'] ?? '',
      isActive: json['is_active'] ?? false,
      startDate: json['start_date'] ?? '',
      meetingLink: json['meeting_link'],
      signalGroupLink: json['signal_group_link'],
      isPaid: studentRelation?['is_paid'] ?? false,
      teacher: teacherData,
    );
  }
}

class StudentLiveClassesScreen extends StatefulWidget {
  const StudentLiveClassesScreen({super.key});

  @override
  State<StudentLiveClassesScreen> createState() => _StudentLiveClassesScreenState();
}

class _StudentLiveClassesScreenState extends State<StudentLiveClassesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ClassGroup> classes = [];
  
  get ascending => null;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // واکشی کلاس‌ها و وضعیت is_paid از جدول پیوند class_students
      final response = await supabase
          .from("class_groups")
          .select("id, class_name, schedule_info, is_active, start_date, meeting_link, signal_group_link, teacher:profiles!teacher_id(first_name, last_name), class_students!inner(student_id, is_paid)")
          .eq("class_students.student_id", userId)
          .order("is_active", ascending: false)
          .order("start_date", ascending: false);

      setState(() {
        classes = (response as List).map((cls) => ClassGroup.fromJson(cls, userId)).toList();
      });
        } catch (e) {
      debugPrint("Error loading enrolled classes: $e");
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
    final liveSessions = classes.where((c) => c.isActive).toList();
    final generalClasses = classes.where((c) => !c.isActive).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
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
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("🎓", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Live Campus & Hubs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Access official Microsoft Teams corporate lecture rooms and sync with Signal encrypted operations.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= ۱. بخش پخش زنده (Live Transmissions) =================
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text("Live Transmissions (${liveSessions.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    liveSessions.isNotEmpty
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: liveSessions.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final room = liveSessions[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: room.isPaid ? const Color(0xFF1a0a0a).withOpacity(0.7) : const Color(0xFF0a0a0f).withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: room.isPaid ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        room.isPaid
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                                child: const Text("LIVE NOW", style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                                              )
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                                                child: const Text("PENDING PAYMENT VERIFICATION", style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900)),
                                              ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(room.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text("Instructor: ${room.teacher != null ? '${room.teacher!['first_name']} ${room.teacher!['last_name']}' : 'Faculty Member'}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                    Text("Schedule: ${room.scheduleInfo}", style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                    const SizedBox(height: 14),

                                    room.isPaid
                                        ? Column(
                                            children: [
                                              if (room.meetingLink != null)
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor: Colors.white,
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                    ),
                                                    icon: const Icon(Icons.video_call, size: 16),
                                                    label: const Text("Join Teams Lecture", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                    onPressed: () => _launchURL(room.meetingLink!),
                                                  ),
                                                ),
                                              if (room.meetingLink != null && room.signalGroupLink != null) const SizedBox(height: 8),
                                              if (room.signalGroupLink != null)
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.white,
                                                      side: const BorderSide(color: Colors.white10),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                    ),
                                                    icon: const Icon(Icons.message, color: Colors.indigoAccent, size: 16),
                                                    label: const Text("Signal Operations", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                    onPressed: () => _launchURL(room.signalGroupLink!),
                                                  ),
                                                ),
                                            ],
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(12),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                                            child: const Text("Class channel is locked until support confirms tuition payment.", style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                          ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0f),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: const Text("No live broadcasts running at this moment.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ),
                    const SizedBox(height: 24),

                    // ================= ۲. بخش کلاس‌های برنامه‌ریزی‌شده (Scheduled & Standby) =================
                    const Text("Scheduled & Standby Channels", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 10),

                    generalClasses.isNotEmpty
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: generalClasses.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final room = generalClasses[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0a0a0f).withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    room.isPaid
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                                            child: const Text("STANDBY", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w900)),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                                            child: const Text("LOCKED", style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900)),
                                          ),
                                    const SizedBox(height: 8),
                                    Text(room.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text("Instructor: ${room.teacher != null ? '${room.teacher!['first_name']} ${room.teacher!['last_name']}' : 'Faculty Member'}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                    Text("Schedule: ${room.scheduleInfo}", style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                    const SizedBox(height: 12),
                                    room.isPaid && room.signalGroupLink != null
                                        ? SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: BorderSide(color: Colors.indigo.withOpacity(0.3)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                              ),
                                              icon: const Icon(Icons.message, color: Colors.indigoAccent, size: 16),
                                              label: const Text("Open Signal Hub", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              onPressed: () => _launchURL(room.signalGroupLink!),
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(10),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                                            child: const Text("Awaiting payment validation from support team.", style: TextStyle(color: Colors.grey, fontSize: 9)),
                                          ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0f),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: const Text("No upcoming or standby classes at the moment.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ),
                  ],
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}