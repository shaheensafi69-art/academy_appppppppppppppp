import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String message;
  final String targetRole;
  final String createdBy;
  final String createdAt;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.message,
    required this.targetRole,
    required this.createdBy,
    required this.createdAt,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      targetRole: json['target_role'] ?? 'all',
      createdBy: json['created_by'] ?? '',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class TeacherAnnouncementsScreen extends StatefulWidget {
  const TeacherAnnouncementsScreen({super.key});

  @override
  State<TeacherAnnouncementsScreen> createState() => _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState extends State<TeacherAnnouncementsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<AnnouncementItem> announcements = [];

  // پالت رنگی اختصاصی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // ۱. دریافت نقش استاد از جدول profiles
      final profile = await supabase
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .maybeSingle();

      final userRole = profile?['role'] ?? "teacher";

      // ۲. واکشی اعلانات (مربوط به "all" یا نقش "teacher")
      final announcementsData = await supabase
          .from("announcements")
          .select("*")
          .inFilter("target_role", ["all", userRole])
          .order("created_at", ascending: false);

      setState(() {
        announcements = (announcementsData as List).map((a) => AnnouncementItem.fromJson(a)).toList();
      });
        } catch (e) {
      debugPrint("Error fetching announcements: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      hour = hour == 0 ? 12 : hour;
      return "$hour:$minute $period";
    } catch (_) {
      return "";
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
          // ================= هدر صفحه استاد =================
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: primaryPink, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Official Announcements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                      SizedBox(height: 3),
                      Text("Stay updated with faculty notices, system upgrades, and academy news.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= لیست اعلانات استاد =================
          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : announcements.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: announcements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = announcements[index];
                        bool isRecent = false;
                        try {
                          final dt = DateTime.parse(item.createdAt);
                          isRecent = (DateTime.now().millisecondsSinceEpoch - dt.millisecondsSinceEpoch) < 3 * 24 * 60 * 60 * 1000;
                        } catch (_) {}

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 12, color: primaryPink),
                                      const SizedBox(width: 4),
                                      Text(_formatDate(item.createdAt), style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.access_time_rounded, size: 12, color: primaryPink),
                                      const SizedBox(width: 4),
                                      Text(_formatTime(item.createdAt), style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  if (isRecent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: lightPinkBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text("NEW UPDATE", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(item.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(item.message, style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cardBorder.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Target: ${item.targetRole == 'all' ? 'Entire Academy' : item.targetRole}",
                                  style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
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
                          Icon(Icons.notifications_off_rounded, size: 36, color: textGrey),
                          SizedBox(height: 10),
                          Text("No Announcements Yet", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("You're all caught up! Future faculty updates will appear here.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}