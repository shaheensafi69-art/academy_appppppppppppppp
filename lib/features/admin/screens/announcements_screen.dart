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
  Map<String, String>? toastMessage;

  final titleCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  String targetRole = "all"; // "all" | "student" | "teacher"

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
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: cardBorder, width: 1.5)),
        title: const Text("Recall Broadcast", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to recall this broadcast? It will be removed from all target dashboards.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900))),
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("INITIALIZING BROADCAST TOWER...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
            // ================= HEADER =================
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "BROADCAST TOWER",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.campaign_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "System Announcements",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Dispatch critical updates and alerts instantly across the ecosystem.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  _buildMiniStat("Total Dispatches", announcements.length.toString(), Icons.podcasts_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= COMPOSE SIGNAL FORM =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("COMPOSE SIGNAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                  const SizedBox(height: 14),

                  if (toastMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: toastMessage!['type'] == 'success' ? Colors.green.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: toastMessage!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            toastMessage!['type'] == 'success' ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: toastMessage!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              toastMessage!['text']!,
                              style: TextStyle(
                                color: toastMessage!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Target Audience Selector
                  const Text("TARGET AUDIENCE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildRoleButton("All Users", "all", Icons.people_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRoleButton("Students", "student", Icons.school_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRoleButton("Faculty", "teacher", Icons.psychology_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title Field
                  const Text("TRANSMISSION TITLE *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "e.g. System Maintenance Update",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Content Field
                  const Text("MESSAGE CONTENT *", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Write your broadcast message here...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSubmitting ? null : handleBroadcast,
                      child: isSubmitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text("TRANSMIT BROADCAST 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= TRANSMISSION LOG (HISTORY) =================
            Row(
              children: [
                const Text("TRANSMISSION LOG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1.5, color: cardBorder)),
              ],
            ),
            const SizedBox(height: 14),

            announcements.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No signals dispatched yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: announcements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = announcements[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.targetRole == 'all' ? lightPinkBg : Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.targetRole.toUpperCase(),
                                    style: TextStyle(
                                      color: item.targetRole == 'all' ? primaryPink : Colors.orange.shade800,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: deletingId == item.id ? null : () => handleDelete(item.id),
                                  child: deletingId == item.id
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                      : const Icon(Icons.delete_outline_rounded, color: textGrey, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(item.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(item.message, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(String label, String roleValue, IconData icon) {
    bool isSelected = targetRole == roleValue;
    return GestureDetector(
      onTap: () => setState(() => targetRole = roleValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? lightPinkBg : cardBorder.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 1.5 : 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? primaryPink : textGrey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isSelected ? primaryPink : textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}