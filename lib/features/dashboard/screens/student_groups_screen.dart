import 'dart:ui';
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
    final filteredGroups = groups.where((g) => g.className.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر و جستجو =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Safi Community", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text("Experience real-time connection. Access your official classroom operations on Signal.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Search active channels...",
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= لیست گروه‌ها =================
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : filteredGroups.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredGroups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        bool hasSignal = group.signalGroupLink != null && group.signalGroupLink!.isNotEmpty;

                        return GestureDetector(
                          onTap: hasSignal ? () => _launchURL(group.signalGroupLink!) : null,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0f).withOpacity(hasSignal ? 0.8 : 0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: hasSignal ? Colors.indigo.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    group.className.isNotEmpty ? group.className[0].toUpperCase() : "G",
                                    style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(group.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                          if (group.latestMessage != null)
                                            Text(_formatTime(group.latestMessage!['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 8)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text("👤 ", style: TextStyle(fontSize: 9)),
                                          Text(group.teacher?['first_name'] ?? 'Faculty', style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        group.latestMessage != null ? group.latestMessage!['message_text'] : (hasSignal ? "Enter protected Signal group channel..." : "Signal Workspace Sync Pending"),
                                        style: TextStyle(color: hasSignal ? Colors.grey.shade400 : Colors.amber.shade400, fontSize: 10, fontStyle: hasSignal ? FontStyle.italic : FontStyle.normal),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasSignal) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                                ],
                              ],
                            ),
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
                          Text("💬", style: TextStyle(fontSize: 32)),
                          SizedBox(height: 10),
                          Text("No Enrolled Channels", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("Join an active course curriculum to unlock your priority workspace.", style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}