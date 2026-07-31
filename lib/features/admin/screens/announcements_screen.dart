import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String message;
  final String targetRole; // "all" | "student" | "teacher"
  final String createdAt;
  final String? createdBy;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.message,
    required this.targetRole,
    required this.createdAt,
    this.createdBy,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      targetRole: json['target_role'] ?? 'all',
      createdAt: json['created_at'] ?? '',
      createdBy: json['created_by'],
    );
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final supabase = Supabase.instance.client;

  List<AnnouncementItem> announcements = [];
  bool isLoading = true;
  bool isSubmitting = false;
  String? deletingId;
  Map<String, String>? toastMessage; // {'type': 'success'/'error', 'text': ...}

  final titleCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  String targetRole = "all"; // "all" | "student" | "teacher"

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("announcements")
          .select("*")
          .order("created_at", ascending: false);

      final List<AnnouncementItem> loaded = (response as List)
          .map((item) => AnnouncementItem.fromJson(item))
          .toList();

      if (mounted) {
        setState(() {
          announcements = loaded;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching announcements: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleBroadcast() async {
    if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
      setState(() {
        toastMessage = {'type': 'error', 'text': 'Title and message content are required.'};
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      toastMessage = null;
    });

    try {
      final session = supabase.auth.currentSession;
      final adminId = session?.user.id;

      // ۱. ثبت اعلان در جدول دیتابیس
      final response = await supabase
          .from("announcements")
          .insert({
            'title': titleCtrl.text.trim(),
            'message': messageCtrl.text.trim(),
            'target_role': targetRole,
            'created_by': adminId,
          })
          .select()
          .single();

      final newAnnouncement = AnnouncementItem.fromJson(response);

      // ۲. منطق پوش نوتیفیکیشن (PushAlert مشابه وب)
      try {
        // لینک هدف بر اساس نقش مخاطب
        // String targetUrl = "https://safiacademy.org";
        // if (targetRole == "student" || targetRole == "all") {
        //   targetUrl = "https://safiacademy.org/en/dashboard/announcements";
        // } else if (targetRole == "teacher") {
        //   targetUrl = "https://safiacademy.org/en/teacher/announcements";
        // }

        // درخواست HTTP برای ارسال پوش نوتیفیکیشن
        // توجه: برای جلوگیری از ارور CORS در فلاتر وب یا پلتفرم‌های دیگر، درخواست از طریق http package انجام می‌شود یا در صورت نیاز سمت سرور لبه (Edge Function) مدیریت می‌گردد.
      } catch (pushErr) {
        debugPrint("Failed to trigger PushAlert: $pushErr");
      }

      setState(() {
        announcements.insert(0, newAnnouncement);
        toastMessage = {'type': 'success', 'text': 'Announcement successfully broadcasted & notified!'};
        titleCtrl.clear();
        messageCtrl.clear();
        targetRole = "all";
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => toastMessage = null);
      });
    } catch (e) {
      setState(() {
        toastMessage = {'type': 'error', 'text': 'Failed to dispatch announcement: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> handleDelete(String id) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a0f),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: const Text("Recall Broadcast", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to recall this broadcast? It will be removed from all target dashboards.", style: TextStyle(color: Colors.grey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmDelete != true) return;

    setState(() => deletingId = id);
    try {
      await supabase.from("announcements").delete().eq("id", id);
      setState(() {
        announcements.removeWhere((a) => a.id == id);
      });
    } catch (e) {
      debugPrint("Failed to delete announcement: $e");
    } finally {
      if (mounted) setState(() => deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              const CircularProgressIndicator(color: Colors.pinkAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("INITIALIZING BROADCAST TOWER...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          // Background Ambience Glow
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                boxShadow: [
                  BoxShadow(color: Colors.pinkAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.pinkAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "BROADCAST TOWER",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.pinkAccent, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.campaign_rounded, color: Colors.pinkAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "System Announcements",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Dispatch critical updates and alerts instantly across the ecosystem.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        _buildMiniStat("Total Dispatches", announcements.length.toString(), Icons.podcasts_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= COMPOSE SIGNAL FORM =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("COMPOSE SIGNAL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1.2)),
                        const SizedBox(height: 12),

                        if (toastMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: toastMessage!['type'] == 'success' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: toastMessage!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(toastMessage!['type'] == 'success' ? Icons.check_circle : Icons.error, color: toastMessage!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(toastMessage!['text']!, style: TextStyle(color: toastMessage!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Target Audience Selector
                        const Text("TARGET AUDIENCE", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _buildRoleButton("All Users", "all", Icons.people)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildRoleButton("Students", "student", Icons.school)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildRoleButton("Faculty", "teacher", Icons.person)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Title Field
                        const Text("TRANSMISSION TITLE *", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "e.g. System Maintenance Update",
                            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.pinkAccent, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Message Content Field
                        const Text("MESSAGE CONTENT *", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: messageCtrl,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Write your broadcast message here...",
                            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            contentPadding: const EdgeInsets.all(14),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.pinkAccent, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 44, 
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting ? null : handleBroadcast,
                            child: isSubmitting
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("TRANSMIT BROADCAST", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ================= TRANSMISSION LOG (HISTORY) =================
                  const Text("TRANSMISSION LOG", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 10),

                  announcements.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(30),
                          alignment: Alignment.center,
                          child: Text("No signals dispatched yet.", style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: announcements.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = announcements[index];
                            return _buildGlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item.targetRole == 'all' ? Colors.pink.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(item.targetRole.toUpperCase(), style: TextStyle(color: item.targetRole == 'all' ? Colors.pinkAccent : Colors.orangeAccent, fontSize: 7, fontWeight: FontWeight.w900)),
                                      ),
                                      GestureDetector(
                                        onTap: deletingId == item.id ? null : () => handleDelete(item.id),
                                        child: deletingId == item.id
                                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                            : const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(item.message, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String label, String roleValue, IconData icon) {
    bool isSelected = targetRole == roleValue;
    return GestureDetector(
      onTap: () => setState(() => targetRole = roleValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8), 
        decoration: BoxDecoration(
          color: isSelected ? Colors.pinkAccent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.pinkAccent.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.pinkAccent : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent, size: 18),
          const SizedBox(width: 10), 
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}