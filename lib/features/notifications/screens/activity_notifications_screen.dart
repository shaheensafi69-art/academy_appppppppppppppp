import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../reels/screens/student_reels_screen.dart';

class ActivityNotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'like', 'comment', 'friend_request'
  final String senderName;
  final String senderAvatar;
  final DateTime createdAt;
  final String? linkUrl;

  ActivityNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.senderName,
    required this.senderAvatar,
    required this.createdAt,
    this.linkUrl,
  });
}

class ActivityNotificationsScreen extends StatefulWidget {
  const ActivityNotificationsScreen({super.key});

  @override
  State<ActivityNotificationsScreen> createState() => _ActivityNotificationsScreenState();
}

class _ActivityNotificationsScreenState extends State<ActivityNotificationsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ActivityNotificationItem> allNotifications = [];
  List<ActivityNotificationItem> filteredNotifications = [];

  String selectedFilter = 'All 🔥';
  final List<String> filters = [
    'All 🔥',
    'Likes & Comments ❤️',
    'Friend Requests 👥',
  ];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchActivityNotifications();
  }

  Future<void> _fetchActivityNotifications() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final currentUserId = user.id;
      List<ActivityNotificationItem> items = [];

      // ۱. دریافت اعلانات عمومی لایک و کامنت از user_notifications
      try {
        final notifRes = await supabase
            .from("user_notifications")
            .select()
            .eq("user_id", currentUserId)
            .inFilter("notification_type", ["like_comment", "like", "comment"])
            .order("created_at", ascending: false)
            .limit(30);

        for (var n in (notifRes as List)) {
          items.add(
            ActivityNotificationItem(
              id: n['id'].toString(),
              title: n['title'] ?? 'Likes & Comments',
              message: n['message'] ?? '',
              type: n['notification_type'] == 'comment' ? 'comment' : 'like',
              senderName: 'Safi Academy Student',
              senderAvatar: '',
              createdAt: DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now(),
              linkUrl: n['link_url'],
            ),
          );
        }
      } catch (_) {}

      // ۲. دریافت لایک‌های ریلزهای کاربر
      try {
        final myReelsRes = await supabase
            .from("reels")
            .select("id, title")
            .eq("user_id", currentUserId);

        final myReelIds = (myReelsRes as List).map((r) => r['id'].toString()).toList();
        if (myReelIds.isNotEmpty) {
          final reelLikesRes = await supabase
              .from("reel_likes")
              .select("id, reel_id, user_id, created_at, profiles(first_name, last_name, avatar_url)")
              .filter("reel_id", "in", myReelIds)
              .neq("user_id", currentUserId)
              .order("created_at", ascending: false)
              .limit(15);

          for (var l in (reelLikesRes as List)) {
            final p = l['profiles'];
            final name = (p != null) ? "${p['first_name'] ?? ''} ${p['last_name'] ?? ''}".trim() : 'Someone';
            final avatar = p != null ? (p['avatar_url'] ?? '') : '';

            items.add(
              ActivityNotificationItem(
                id: "reel_like_${l['id']}",
                title: "Liked your Reel ❤️",
                message: "$name liked your educational video.",
                type: 'like',
                senderName: name.isNotEmpty ? name : 'Student',
                senderAvatar: avatar,
                createdAt: DateTime.tryParse(l['created_at'] ?? '') ?? DateTime.now(),
              ),
            );
          }
        }
      } catch (_) {}

      // ۳. دریافت درخواست‌های دوستی (Friend Requests)
      try {
        final friendsRes = await supabase
            .from("student_friends")
            .select("id, sender_id, status, created_at, profiles!sender_id(first_name, last_name, avatar_url)")
            .eq("receiver_id", currentUserId)
            .eq("status", "pending")
            .order("created_at", ascending: false);

        for (var f in (friendsRes as List)) {
          final p = f['profiles'];
          final name = (p != null) ? "${p['first_name'] ?? ''} ${p['last_name'] ?? ''}".trim() : 'Someone';
          final avatar = p != null ? (p['avatar_url'] ?? '') : '';

          items.add(
            ActivityNotificationItem(
              id: "friend_${f['id']}",
              title: "Friend Request 👥",
              message: "$name sent you a friend request.",
              type: 'friend_request',
              senderName: name,
              senderAvatar: avatar,
              createdAt: DateTime.tryParse(f['created_at'] ?? '') ?? DateTime.now(),
            ),
          );
        }
      } catch (_) {}

      // مرتب‌سازی بر اساس جدیدترین زمان ایجاد
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          allNotifications = items;
          _applyFilter();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    if (selectedFilter == 'All 🔥') {
      filteredNotifications = List.from(allNotifications);
    } else if (selectedFilter == 'Likes & Comments ❤️') {
      filteredNotifications = allNotifications.where((n) => n.type == 'like' || n.type == 'comment').toList();
    } else if (selectedFilter == 'Friend Requests 👥') {
      filteredNotifications = allNotifications.where((n) => n.type == 'friend_request').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: primaryPink, size: 22),
            SizedBox(width: 8),
            Text("Activity & Notifications", style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: Column(
        children: [
          // دکمه‌های فیلتر دسته‌بندی
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: filters.map((f) {
                final isSel = selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
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
                          _applyFilter();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: cardBorder),

          // لیست نوتیفیکیشن‌ها
          Expanded(
            child: RefreshIndicator(
              color: primaryPink,
              onRefresh: _fetchActivityNotifications,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5))
                  : filteredNotifications.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.notifications_off_outlined, size: 60, color: textGrey),
                                  SizedBox(height: 16),
                                  Text("No activities yet", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                                  SizedBox(height: 6),
                                  Text("New likes, comments, and friend requests will appear here.", style: TextStyle(color: textGrey, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNotifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filteredNotifications[index];
                            return GestureDetector(
                              onTap: () {
                                if (item.type == 'like' || item.type == 'comment') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const StudentReelsScreen()),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder, width: 1.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: lightPinkBg,
                                          backgroundImage: item.senderAvatar.isNotEmpty ? NetworkImage(item.senderAvatar) : null,
                                          child: item.senderAvatar.isEmpty
                                              ? Text(
                                                  item.senderName.isNotEmpty ? item.senderName[0] : 'S',
                                                  style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold),
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: Icon(
                                              item.type == 'like'
                                                  ? Icons.favorite_rounded
                                                  : item.type == 'comment'
                                                      ? Icons.chat_bubble_rounded
                                                      : Icons.people_rounded,
                                              color: primaryPink,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textDark),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.message,
                                            style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textGrey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
