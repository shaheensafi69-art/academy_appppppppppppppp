import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupCard {
  final String id;
  final String className;
  final String? signalGroupLink;
  final Map<String, dynamic>? teacher;
  Map<String, dynamic>? latestMessage;

  GroupCard({
    required this.id,
    required this.className,
    this.signalGroupLink,
    this.teacher,
    this.latestMessage,
  });

  factory GroupCard.fromJson(Map<String, dynamic> json) {
    final teacherObj = json['teacher'];
    final teacherData = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;

    return GroupCard(
      id: json['id'] ?? '',
      className: json['class_name'] ?? 'Unknown Class',
      signalGroupLink: json['signal_group_link'],
      teacher: teacherData,
      latestMessage: json['latest_message'],
    );
  }
}

class StudentGroupsScreen extends StatefulWidget {
  const StudentGroupsScreen({super.key});

  @override
  State<StudentGroupsScreen> createState() => _StudentGroupsScreenState();
}

class _StudentGroupsScreenState extends State<StudentGroupsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<GroupCard> groups = [];
  String searchQuery = "";
  RealtimeChannel? _realtimeChannel;

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
    _fetchMyGroups();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _realtimeChannel = supabase
        .channel('public:class_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'class_messages',
          callback: (payload) {
            _updateLatestMessageRealtime(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _updateLatestMessageRealtime(Map<String, dynamic> newMessage) {
    if (!mounted) return;
    setState(() {
      for (var group in groups) {
        if (group.id == newMessage['class_group_id']) {
          group.latestMessage = {
            'message_text': newMessage['message_text'],
            'created_at': newMessage['created_at'],
          };
        }
      }
      groups.sort((a, b) {
        final timeA = a.latestMessage != null ? DateTime.parse(a.latestMessage!['created_at']).millisecondsSinceEpoch : 0;
        final timeB = b.latestMessage != null ? DateTime.parse(b.latestMessage!['created_at']).millisecondsSinceEpoch : 0;
        return timeB.compareTo(timeA);
      });
    });
  }

  Future<void> _fetchMyGroups() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final profile = await supabase.from("profiles").select("role").eq("id", userId).single();
      List<String> groupIds = [];

      if (profile['role'] == "student") {
        final enrollments = await supabase.from("class_students").select("class_group_id").eq("student_id", userId);
        groupIds = (enrollments as List?)?.map((e) => e['class_group_id'] as String).toList() ?? [];
      }

      var query = supabase.from("class_groups").select("id, class_name, signal_group_link, teacher:profiles!teacher_id(first_name, last_name, avatar_url)");

      if (profile['role'] == "student") {
        if (groupIds.isEmpty) {
          setState(() {
            groups = [];
            isLoading = false;
          });
          return;
        }
        query = query.inFilter("id", groupIds);
      } else if (profile['role'] == "teacher") {
        query = query.eq("teacher_id", userId);
      }

      final classGroups = await query;

      List<GroupCard> loadedGroups = [];
      for (var group in (classGroups as List)) {
        final lastMsg = await supabase
            .from("class_messages")
            .select("message_text, created_at")
            .eq("class_group_id", group['id'])
            .order("created_at", ascending: false)
            .limit(1)
            .maybeSingle();

        final card = GroupCard.fromJson(group);
        card.latestMessage = lastMsg;
        loadedGroups.add(card);
      }

      loadedGroups.sort((a, b) {
        final timeA = a.latestMessage != null ? DateTime.parse(a.latestMessage!['created_at']).millisecondsSinceEpoch : 0;
        final timeB = b.latestMessage != null ? DateTime.parse(b.latestMessage!['created_at']).millisecondsSinceEpoch : 0;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          groups = loadedGroups;
        });
      }
    } catch (e) {
      debugPrint("Error fetching groups: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }
      return "${date.month}/${date.day}";
    } catch (_) {
      return "";
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING COMMUNITY...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final filteredGroups = groups.where((g) => g.className.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= هدر و جستجو =================
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: primaryPink, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Safi Community", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                            const SizedBox(height: 3),
                            const Text("Experience real-time connection. Access your official classroom operations on Signal.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: primaryPink, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => searchQuery = val),
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: "Search active channels...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= لیست گروه‌ها =================
            filteredGroups.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      bool hasSignal = group.signalGroupLink != null && group.signalGroupLink!.isNotEmpty;

                      return GestureDetector(
                        onTap: hasSignal ? () => _launchURL(group.signalGroupLink!) : null,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: hasSignal ? primaryPink.withOpacity(0.3) : cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: lightPinkBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  group.className.isNotEmpty ? group.className[0].toUpperCase() : "G",
                                  style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(group.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                        if (group.latestMessage != null)
                                          Text(_formatTime(group.latestMessage!['created_at']), style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_rounded, color: primaryPink, size: 12),
                                        const SizedBox(width: 4),
                                        Text(group.teacher?['first_name'] ?? 'Faculty', style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      group.latestMessage != null ? group.latestMessage!['message_text'] : (hasSignal ? "Enter protected Signal group channel..." : "Signal Workspace Sync Pending"),
                                      style: TextStyle(color: hasSignal ? textGrey : Colors.amber.shade800, fontSize: 11, fontStyle: hasSignal ? FontStyle.italic : FontStyle.normal, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (hasSignal) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: lightPinkBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_ios_rounded, color: primaryPink, size: 12),
                                ),
                              ],
                            ],
                          ),
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
                        const Icon(Icons.chat_bubble_outline_rounded, color: textGrey, size: 36),
                        const SizedBox(height: 10),
                        const Text("No Enrolled Channels", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text("Join an active course curriculum to unlock your priority workspace.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
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