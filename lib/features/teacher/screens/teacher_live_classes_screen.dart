import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_live_class_details_screen.dart';
import 'teacher_create_class_screen.dart';

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

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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
    } catch (e) {
      debugPrint("Error syncing live classes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه ریسپانسیو =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 450;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryPink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.live_tv_rounded, color: primaryPink, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Live Streaming", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                              SizedBox(height: 3),
                              Text("Launch live lectures and channels.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isWide ? 0 : 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("Create Class", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TeacherCreateClassScreen()),
                        ).then((_) => _fetchLiveClasses());
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          const Text("Active Broadcasts", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 12),

          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : classGroups.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: classGroups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final cls = classGroups[index];
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cls.isActive ? primaryPink : cardBorder,
                              width: cls.isActive ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cls.isActive ? primaryPink.withOpacity(0.15) : Colors.black.withOpacity(0.04),
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
                                    child: Text(cls.category.toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cls.isActive ? Colors.red.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cls.isActive ? "● LIVE NOW" : "○ Standby",
                                      style: TextStyle(
                                        color: cls.isActive ? Colors.redAccent : textGrey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(cls.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: textGrey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "${cls.classDays} | ${cls.classTime}",
                                      style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: cardBorder, height: 1),
                              const SizedBox(height: 12),

                              // بخش آمار و دکمه مدیریت ریسپانسیو
                              LayoutBuilder(
                                builder: (context, boxConstraints) {
                                  bool isCardWide = boxConstraints.maxWidth > 360;
                                  return Flex(
                                    direction: isCardWide ? Axis.horizontal : Axis.vertical,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: isCardWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.people_alt_rounded, size: 14, color: textGrey),
                                          const SizedBox(width: 5),
                                          Text("${cls.studentCount} Students Enrolled", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                      SizedBox(height: isCardWide ? 0 : 10),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryPink,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => TeacherLiveClassDetailsScreen(classId: cls.id)),
                                          );
                                        },
                                        child: const Text("Manage Class", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.tv_off_rounded, size: 36, color: textGrey),
                          SizedBox(height: 10),
                          Text("No Live Broadcasts", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("No live streams or broadcasts available right now.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}