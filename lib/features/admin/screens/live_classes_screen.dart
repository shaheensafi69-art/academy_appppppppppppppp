import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // برای باز کردن لینک‌های جلسه

class LiveClassItem {
  final String id;
  final String className;
  final bool isActive;
  final String? classTime;
  final String? classDays;
  final String? meetingLink;
  final String? signalGroupLink;
  final String? courseTitle;
  final String? teacherFirstName;
  final String? teacherLastName;

  LiveClassItem({
    required this.id,
    required this.className,
    required this.isActive,
    this.classTime,
    this.classDays,
    this.meetingLink,
    this.signalGroupLink,
    this.courseTitle,
    this.teacherFirstName,
    this.teacherLastName,
  });

  factory LiveClassItem.fromJson(Map<String, dynamic> json) {
    final courseObj = json['course'];
    Map<String, dynamic>? formattedCourse = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;

    final teacherObj = json['teacher'];
    Map<String, dynamic>? formattedTeacher = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;

    return LiveClassItem(
      id: json['id'] ?? '',
      className: json['class_name'] ?? '',
      isActive: json['is_active'] ?? false,
      classTime: json['class_time'],
      classDays: json['class_days'],
      meetingLink: json['meeting_link'],
      signalGroupLink: json['signal_group_link'],
      courseTitle: formattedCourse?['title'],
      teacherFirstName: formattedTeacher?['first_name'],
      teacherLastName: formattedTeacher?['last_name'],
    );
  }
}

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<LiveClassItem> classes = [];
  String searchQuery = "";

  // Edit Modal State
  LiveClassItem? selectedClass;
  final meetingLinkCtrl = TextEditingController();
  final signalLinkCtrl = TextEditingController();
  bool isSaving = false;
  Map<String, String>? message;

  @override
  void initState() {
    super.initState();
    _fetchLiveClasses();
  }

  @override
  void dispose() {
    meetingLinkCtrl.dispose();
    signalLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveClasses() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("class_groups")
          .select("id, class_name, is_active, class_time, class_days, meeting_link, signal_group_link, course:courses(title), teacher:profiles!teacher_id(first_name, last_name, avatar_url)")
          .order("is_active", ascending: false)
          .order("created_at", ascending: false);

      setState(() {
        classes = (response as List).map((c) => LiveClassItem.fromJson(c)).toList();
        isLoading = false;
      });
        } catch (e) {
      debugPrint("Error fetching live classes: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<LiveClassItem> get filteredClasses {
    if (searchQuery.isEmpty) return classes;
    final query = searchQuery.toLowerCase();
    return classes.where((c) =>
      c.className.toLowerCase().contains(query) ||
      (c.courseTitle?.toLowerCase().contains(query) ?? false) ||
      (c.teacherFirstName?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  void openLinkModal(LiveClassItem cls) {
    setState(() {
      selectedClass = cls;
      meetingLinkCtrl.text = cls.meetingLink ?? "";
      signalLinkCtrl.text = cls.signalGroupLink ?? "";
      message = null;
    });
  }

  Future<void> handleUpdateLinks() async {
    if (selectedClass == null) return;

    setState(() {
      isSaving = true;
      message = null;
    });

    try {
      String? newMeeting = meetingLinkCtrl.text.trim().isNotEmpty ? meetingLinkCtrl.text.trim() : null;
      String? newSignal = signalLinkCtrl.text.trim().isNotEmpty ? signalLinkCtrl.text.trim() : null;

      await supabase
          .from("class_groups")
          .update({
            'meeting_link': newMeeting,
            'signal_group_link': newSignal,
          })
          .eq("id", selectedClass!.id);

      setState(() {
        classes = classes.map((c) => c.id == selectedClass!.id
            ? LiveClassItem(
                id: c.id,
                className: c.className,
                isActive: c.isActive,
                classTime: c.classTime,
                classDays: c.classDays,
                meetingLink: newMeeting,
                signalGroupLink: newSignal,
                courseTitle: c.courseTitle,
                teacherFirstName: c.teacherFirstName,
                teacherLastName: c.teacherLastName,
              )
            : c).toList();

        message = {'type': 'success', 'text': 'Room links updated successfully!'};
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            selectedClass = null;
            message = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to update links: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
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
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.pinkAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("ESTABLISHING LIVE CONNECTION...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredClasses;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
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
                                "LIVE STUDIO",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.pinkAccent, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.podcasts_rounded, color: Colors.pinkAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Live Sessions",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Monitor active rooms and manage meeting URLs securely.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => setState(() => searchQuery = val),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: "Search cohorts...",
                                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= LIVE CLASSES LIST =================
                  currentFiltered.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Text("No live sessions found.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentFiltered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final cls = currentFiltered[index];
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
                                          color: cls.isActive ? Colors.pink.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(cls.isActive ? "LIVE COHORT" : "ARCHIVED", style: TextStyle(color: cls.isActive ? Colors.pinkAccent : Colors.grey, fontSize: 7, fontWeight: FontWeight.w900)),
                                      ),
                                      Text(cls.courseTitle ?? 'General', style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(cls.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, color: Colors.grey, size: 12),
                                      const SizedBox(width: 4),
                                      Text("${cls.teacherFirstName ?? 'Unassigned'} ${cls.teacherLastName ?? ''}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cls.meetingLink != null ? Colors.pinkAccent.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                                            foregroundColor: cls.meetingLink != null ? Colors.pinkAccent : Colors.grey,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            side: BorderSide(color: cls.meetingLink != null ? Colors.pinkAccent.withOpacity(0.3) : Colors.white10),
                                          ),
                                          icon: const Icon(Icons.videocam, size: 14),
                                          label: Text(cls.meetingLink != null ? "Join Meeting" : "No Link", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                          onPressed: cls.meetingLink != null ? () => _launchURL(cls.meetingLink!) : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white.withOpacity(0.08),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text("Manage", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        onPressed: () => openLinkModal(cls),
                                      ),
                                    ],
                                  )
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

          // Edit Links Modal
          if (selectedClass != null)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (!isSaving) setState(() => selectedClass = null);
                    },
                    child: Container(color: Colors.black.withOpacity(0.8)),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Manage Links: ${selectedClass!.className}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                              GestureDetector(
                                onTap: () {
                                  if (!isSaving) setState(() => selectedClass = null);
                                },
                                child: const Icon(Icons.close, color: Colors.grey, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (message != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: message!['type'] == 'success' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const Text("MEETING URL (ZOOM / MEET)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: meetingLinkCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: "https://zoom.us/j/...",
                              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.pinkAccent, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          const Text("COMMUNICATION GROUP URL", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: signalLinkCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: "https://t.me/...",
                              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.pinkAccent, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white, backgroundColor: Colors.pinkAccent, // Use onPrimary for older Flutter versions
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving ? null : handleUpdateLinks,
                              child: isSaving
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("SAVE & UPDATE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }
}