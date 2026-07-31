import 'dart:ui';
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

      if (announcementsData != null) {
        setState(() {
          announcements = (announcementsData as List).map((a) => AnnouncementItem.fromJson(a)).toList();
        });
      }
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه استاد =================
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
                    color: Colors.pink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("📢", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Official Announcements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Stay updated with faculty notices, system upgrades, and academy news.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= لیست اعلانات استاد =================
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : announcements.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: announcements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = announcements[index];
                        bool isRecent = false;
                        try {
                          final dt = DateTime.parse(item.createdAt);
                          isRecent = (DateTime.now().millisecondsSinceEpoch - dt.millisecondsSinceEpoch) < 3 * 24 * 60 * 60 * 1000;
                        } catch (_) {}

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 12, color: Colors.pinkAccent),
                                      const SizedBox(width: 4),
                                      Text(_formatDate(item.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.access_time, size: 12, color: Colors.pinkAccent),
                                      const SizedBox(width: 4),
                                      Text(_formatTime(item.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  if (isRecent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.pink.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.pink.withOpacity(0.3)),
                                      ),
                                      child: const Text("NEW UPDATE", style: TextStyle(color: Colors.pinkAccent, fontSize: 7, fontWeight: FontWeight.w900)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 6),
                              Text(item.message, style: TextStyle(color: Colors.grey.shade300, fontSize: 11, height: 1.4)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text("Target: ${item.targetRole == 'all' ? 'Entire Academy' : item.targetRole}", style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
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
                      child: const Column(
                        children: [
                          Text("📭", style: TextStyle(fontSize: 32)),
                          SizedBox(height: 10),
                          Text("No Announcements Yet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("You're all caught up! Future faculty updates will appear here.", style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}