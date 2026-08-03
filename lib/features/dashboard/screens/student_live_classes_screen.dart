import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_class_detail_screen.dart';

class ClassGroup {
  final String id;
  final String className;
  final String scheduleInfo;
  final bool isActive;
  final String startDate;
  final String? meetingLink;
  final String? signalGroupLink;
  final bool isPaid;
  final Map<String, dynamic>? teacher;
  final Map<String, dynamic> rawData; // برای انتقال کامل به صفحه دیتیلز

  ClassGroup({
    required this.id,
    required this.className,
    required this.scheduleInfo,
    required this.isActive,
    required this.startDate,
    this.meetingLink,
    this.signalGroupLink,
    required this.isPaid,
    required this.teacher,
    required this.rawData,
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
      rawData: json,
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

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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

      final response = await supabase
          .from("class_groups")
          .select("id, class_name, schedule_info, is_active, start_date, end_date, class_time, class_days, meeting_link, signal_group_link, teacher:profiles!teacher_id(first_name, last_name), class_students!inner(student_id, is_paid)")
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
              Text("LOADING LIVE CAMPUS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final liveSessions = classes.where((c) => c.isActive).toList();
    final generalClasses = classes.where((c) => !c.isActive).toList();

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= بنر کلاس‌ها =================
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightPinkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.podcasts_rounded, color: primaryPink, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Live Campus & Hubs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        SizedBox(height: 3),
                        Text("Access official Microsoft Teams corporate lecture rooms and sync with Signal encrypted operations.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // پخش زنده
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text("Live Transmissions (${liveSessions.length})", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),

            liveSessions.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: liveSessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = liveSessions[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StudentClassDetailScreen(classData: room.rawData, isPaid: room.isPaid)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: room.isPaid ? primaryPink.withOpacity(0.3) : cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                                          child: const Text("LIVE NOW", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5)),
                                          child: const Text("PENDING PAYMENT", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                        ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGrey),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(room.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text("Instructor: ${room.teacher != null ? '${room.teacher!['first_name']} ${room.teacher!['last_name']}' : 'Faculty Member'}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text("Schedule: ${room.scheduleInfo}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No live broadcasts running at this moment.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 28),

            // کلاس‌های برنامه‌ریزی‌شده
            const Text("Scheduled & Standby Channels", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 12),

            generalClasses.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: generalClasses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = generalClasses[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StudentClassDetailScreen(classData: room.rawData, isPaid: room.isPaid)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                          decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                          child: const Text("STANDBY", style: TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5)),
                                          child: const Text("LOCKED", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                        ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGrey),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(room.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text("Instructor: ${room.teacher != null ? '${room.teacher!['first_name']} ${room.teacher!['last_name']}' : 'Faculty Member'}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text("Schedule: ${room.scheduleInfo}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No upcoming or standby classes at the moment.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}