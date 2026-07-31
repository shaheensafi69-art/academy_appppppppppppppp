import 'dart:ui';
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
          .inFilter("target_role", ["all", userRole]) // Corrected: `ascending` should be a named argument
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.indigoAccent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER CARD =================
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF131324), Color(0xFF07070d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Colors.indigoAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Official Announcements",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Stay updated with latest news and notices from Safi Academy administration.",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 9, height: 1.3),
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
                        color: const Color(0xFF0a0a0f).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                              if (recent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt, color: Colors.indigoAccent, size: 10),
                                      SizedBox(width: 2),
                                      Text("New", style: TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.grey, size: 10),
                              const SizedBox(width: 4),
                              Text(_formatDate(item.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 9)),
                              const SizedBox(width: 10),
                              const Icon(Icons.access_time_rounded, color: Colors.grey, size: 10),
                              const SizedBox(width: 4),
                              Text(_formatTime(item.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 9)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 10),
                          Text(
                            item.message,
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 11, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Target: ${item.targetRole == 'all' ? 'Entire Academy' : item.targetRole.toUpperCase()}",
                              style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.notifications_off_outlined, color: Colors.grey, size: 36),
                      const SizedBox(height: 10),
                      const Text("No Announcements Yet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("You're all caught up! Future updates will appear here.", style: TextStyle(color: Colors.grey.shade500, fontSize: 10), textAlign: TextAlign.center),
                    ],
                  ),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}