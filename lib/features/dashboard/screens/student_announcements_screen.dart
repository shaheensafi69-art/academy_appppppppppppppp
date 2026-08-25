import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String message;
  final String targetRole;
  final String createdAt;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.message,
    required this.targetRole,
    required this.createdAt,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      targetRole: json['target_role'] ?? 'all',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class ClassGroupItem {
  final String id;
  final String className;
  final String scheduleInfo;
  final String? classTime;
  final String? classDays;
  final String? meetingLink;

  ClassGroupItem({
    required this.id,
    required this.className,
    required this.scheduleInfo,
    this.classTime,
    this.classDays,
    this.meetingLink,
  });

  factory ClassGroupItem.fromJson(Map<String, dynamic> json) {
    return ClassGroupItem(
      id: json['id']?.toString() ?? '',
      className: json['class_name'] ?? 'Academy Class',
      scheduleInfo: json['schedule_info'] ?? '',
      classTime: json['class_time'],
      classDays: json['class_days'],
      meetingLink: json['meeting_link'],
    );
  }
}

class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  State<StudentAnnouncementsScreen> createState() =>
      _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState
    extends State<StudentAnnouncementsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<AnnouncementItem> announcements = [];
  List<ClassGroupItem> classGroups = [];

  String selectedFilter = 'Announcements 📢';
  final List<String> filters = ['Announcements 📢', 'Classes 🎓'];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchAnnouncementsAndClasses();
  }

  Future<void> _fetchAnnouncementsAndClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // ۱. دریافت نقش کاربر برای فیلتر کردن اعلانات مربوطه
      final profile = await supabase
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .maybeSingle();

      final userRole = profile?['role'] ?? "student";

      // ۲. واکشی اعلانات
      final announcementsData = await supabase
          .from("announcements")
          .select("*")
          .inFilter("target_role", ["all", userRole])
          .order("created_at", ascending: false);

      // ۳. واکشی کلاس‌ها
      final classesData = await supabase
          .from("class_groups")
          .select("*")
          .eq("is_active", true)
          .order("created_at", ascending: false);

      setState(() {
        announcements = (announcementsData as List)
            .map((item) => AnnouncementItem.fromJson(item))
            .toList();
        classGroups = (classesData as List)
            .map((item) => ClassGroupItem.fromJson(item))
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      ];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    } catch (_) {
      return "";
    }
  }

  bool _isRecent(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final difference = DateTime.now().difference(dt);
      return difference.inDays < 3;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryPink))
            : RefreshIndicator(
                color: primaryPink,
                onRefresh: _fetchAnnouncementsAndClasses,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // هدر بخش اعلانات و کلاس‌ها
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              lightPinkBg.withOpacity(0.4),
                              const Color(0xFFFFF0F5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: primaryPink.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: lightPinkBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: primaryPink.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: primaryPink,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Academy Announcements",
                                    style: TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Stay updated with latest announcements and upcoming live class groups.",
                                    style: TextStyle(
                                      color: textGrey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // فیلتر دسته‌بندی با کنتراست بالا
                      Row(
                        children: filters.map((f) {
                          final isSel = selectedFilter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: isSel,
                              selectedColor: primaryPink,
                              backgroundColor: const Color(0xFFF3F4F6),
                              side: BorderSide.none,
                              showCheckmark: isSel,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    selectedFilter = f;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // نمایش داده فیلتر شده
                      selectedFilter == 'Announcements 📢'
                          ? _buildAnnouncementsList()
                          : _buildClassesList(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    if (announcements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: const Column(
          children: [
            Icon(Icons.notifications_off_outlined, color: textGrey, size: 36),
            SizedBox(height: 10),
            Text(
              "No Announcements Yet",
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: announcements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = announcements[index];
        bool recent = _isRecent(item.createdAt);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (recent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "NEW",
                        style: TextStyle(
                          color: primaryPink,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: textGrey,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: cardBorder, height: 1),
              const SizedBox(height: 12),
              Text(
                item.message,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassesList() {
    if (classGroups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: const Column(
          children: [
            Icon(Icons.school_outlined, color: textGrey, size: 36),
            SizedBox(height: 10),
            Text(
              "No Active Class Groups",
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: classGroups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = classGroups[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.className,
                style: const TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (group.classDays != null || group.classTime != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: primaryPink,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${group.classDays ?? 'Scheduled Days'} at ${group.classTime ?? '10:00 AM'}",
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                group.scheduleInfo,
                style: const TextStyle(
                  color: textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (group.meetingLink != null &&
                  group.meetingLink!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.video_call_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "JOIN LIVE CLASS 📹",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      final url = Uri.parse(group.meetingLink!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
