import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      targetRole: json['target_role'] ?? 'all',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  State<StudentAnnouncementsScreen> createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<AnnouncementItem> announcements = [];

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
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
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

      // ۲. واکشی اعلانات (آن‌هایی که برای "all" هستند یا مستقیماً برای نقش این کاربر)
      final announcementsData = await supabase
          .from("announcements")
          .select("*")
          .inFilter("target_role", ["all", userRole])
          .order("created_at", ascending: false);

      setState(() {
        announcements = (announcementsData as List)
            .map((item) => AnnouncementItem.fromJson(item))
            .toList();
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
      final months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      int hour = dt.hour;
      String period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return "$hour:${dt.minute.toString().padLeft(2, '0')} $period";
    } catch (_) {
      return "";
    }
  }

  bool _isRecent(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt).inDays;
      return diff < 3; // کمتر از ۳ روز پیش
    } catch (_) {
      return false;
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
              Text("LOADING ANNOUNCEMENTS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER CARD =================
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: lightPinkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: primaryPink, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Official Announcements",
                          style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Stay updated with latest news and notices from Safi Academy administration.",
                          style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ANNOUNCEMENTS LIST =================
            announcements.isNotEmpty
                ? ListView.separated(
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
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                ),
                                if (recent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: lightPinkBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded, color: primaryPink, size: 12),
                                        const SizedBox(width: 2),
                                        const Text("New", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: textGrey, size: 11),
                                const SizedBox(width: 4),
                                Text(_formatDate(item.createdAt), style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                const Icon(Icons.access_time_rounded, color: textGrey, size: 11),
                                const SizedBox(width: 4),
                                Text(_formatTime(item.createdAt), style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: cardBorder, height: 1),
                            const SizedBox(height: 12),
                            Text(
                              item.message,
                              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cardBorder.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Target: ${item.targetRole == 'all' ? 'Entire Academy' : item.targetRole.toUpperCase()}",
                                style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900),
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
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.notifications_off_outlined, color: textGrey, size: 36),
                        const SizedBox(height: 10),
                        const Text("No Announcements Yet", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text("You're all caught up! Future updates will appear here.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}