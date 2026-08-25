import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'direct_chat_screen.dart';

class ChatThreadItem {
  final String peerId;
  final String peerName;
  final String peerAvatar;
  final String role;
  final String lastMessage;
  final String time;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  ChatThreadItem({
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.role,
    required this.lastMessage,
    required this.time,
    this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
  });
}

class DirectChatListScreen extends StatefulWidget {
  const DirectChatListScreen({super.key});

  @override
  State<DirectChatListScreen> createState() => _DirectChatListScreenState();
}

class _DirectChatListScreenState extends State<DirectChatListScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  bool isSearchingLive = false;
  List<ChatThreadItem> threads = [];
  List<ChatThreadItem> searchResults = [];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchExistingChatThreads();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (mounted && !isSearchingLive) {
        _fetchExistingChatThreads(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// دریافت فقط گفتگوهایی که کاربر قبلاً با آنها پیام رد و بدل کرده است (دیتابیس واقعی)
  Future<void> _fetchExistingChatThreads({bool showLoading = true}) async {
    if (showLoading) setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final currentUserId = user.id;

      // دریافت آخرین پیام‌ها برای همه گفتگوهای این کاربر
      final messagesRes = await supabase
          .from("direct_messages")
          .select(
            "id, sender_id, receiver_id, message_text, created_at, is_read",
          )
          .or("sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId")
          .order("created_at", ascending: false);

      Map<String, Map<String, dynamic>> activePeersMap = {};

      for (var m in (messagesRes as List)) {
        final senderId = m['sender_id']?.toString() ?? '';
        final receiverId = m['receiver_id']?.toString() ?? '';
        final peerId = (senderId == currentUserId) ? receiverId : senderId;

        if (peerId.isEmpty || peerId == currentUserId) continue;

        if (!activePeersMap.containsKey(peerId)) {
          activePeersMap[peerId] = {
            'lastMessage': m['message_text'] ?? '',
            'created_at': m['created_at'] ?? '',
            'unreadCount': 0,
          };
        }

        // شمارش پیام‌های خوانده‌نشده
        if (senderId == peerId &&
            receiverId == currentUserId &&
            m['is_read'] == false) {
          activePeersMap[peerId]!['unreadCount'] =
              (activePeersMap[peerId]!['unreadCount'] as int) + 1;
        }
      }

      List<ChatThreadItem> loadedThreads = [];

      for (var entry in activePeersMap.entries) {
        final peerId = entry.key;
        final data = entry.value;

        String fullName = "Academy Member";
        String avatar = "";
        String role = "STUDENT";

        try {
          final profileRes = await supabase
              .from("profiles")
              .select("first_name, last_name, avatar_url, role")
              .eq("id", peerId)
              .maybeSingle();

          if (profileRes != null) {
            final fName = profileRes['first_name'] ?? '';
            final lName = profileRes['last_name'] ?? '';
            fullName = "$fName $lName".trim();
            if (fullName.isEmpty) fullName = "Academy Member";
            avatar = profileRes['avatar_url'] ?? '';
            role = (profileRes['role'] ?? 'STUDENT').toString().toUpperCase();
          }
        } catch (_) {}

        String timeStr = "";
        DateTime? msgDt;
        final dtStr = data['created_at']?.toString() ?? '';
        if (dtStr.isNotEmpty) {
          try {
            msgDt = DateTime.parse(dtStr);
            timeStr =
                "${msgDt.hour.toString().padLeft(2, '0')}:${msgDt.minute.toString().padLeft(2, '0')}";
          } catch (_) {}
        }

        loadedThreads.add(
          ChatThreadItem(
            peerId: peerId,
            peerName: fullName,
            peerAvatar: avatar,
            role: role,
            lastMessage: data['lastMessage'],
            time: timeStr,
            lastMessageTime: msgDt,
            unreadCount: data['unreadCount'] as int,
            isOnline: true,
          ),
        );
      }

      loadedThreads.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      if (mounted) {
        setState(() {
          threads = loadedThreads;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching existing chat threads: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// جستجوی زنده بین تمام کاربران/دوستان آکادمی فقط زمانی که کاربر تایپ می‌کند
  void _onSearchChanged(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        isSearchingLive = false;
        searchResults = [];
      });
      return;
    }

    setState(() => isSearchingLive = true);

    try {
      final user = supabase.auth.currentUser;
      final currentUserId = user?.id ?? '';

      final res = await supabase
          .from("profiles")
          .select("id, first_name, last_name, avatar_url, role")
          .or("first_name.ilike.%$q%,last_name.ilike.%$q%")
          .limit(20);

      List<ChatThreadItem> found = [];
      for (var p in (res as List)) {
        final pId = p['id'].toString();
        if (pId == currentUserId) continue;

        final fName = p['first_name'] ?? '';
        final lName = p['last_name'] ?? '';
        String fullName = "$fName $lName".trim();
        if (fullName.isEmpty) fullName = "Academy Member";

        found.add(
          ChatThreadItem(
            peerId: pId,
            peerName: fullName,
            peerAvatar: p['avatar_url'] ?? '',
            role: (p['role'] ?? 'STUDENT').toString().toUpperCase(),
            lastMessage: "گفتگو را شروع کنید 💬",
            time: "",
            unreadCount: 0,
            isOnline: true,
          ),
        );
      }

      if (mounted) {
        setState(() => searchResults = found);
      }
    } catch (e) {
      debugPrint("Error searching users for chat: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _searchController.text.trim().isNotEmpty
        ? searchResults
        : threads;

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textDark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Direct Messages 💬",
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          // نوار جستجوی کانتکت‌ها
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              cursorColor: primaryPink,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
              decoration: InputDecoration(
                hintText: "Search friends or teachers to message...",
                hintStyle: const TextStyle(color: textGrey, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: textGrey,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: textGrey,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged("");
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardBorder,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryPink, width: 1.5),
                ),
              ),
            ),
          ),

          // لیست گفتگوها یا حالت خالی (Empty State)
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryPink,
                      strokeWidth: 2.5,
                    ),
                  )
                : displayList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: lightPinkBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: primaryPink,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.trim().isNotEmpty
                              ? "No contacts found for '${_searchController.text}'"
                              : "هیچ گفتگو فعالی وجود ندارد",
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "نام دوست یا استاد خود را جستجو کنید و اولین پیام را بفرستید!",
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: primaryPink,
                    onRefresh: _fetchExistingChatThreads,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: displayList.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: cardBorder, height: 16),
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        return _buildThreadItem(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadItem(ChatThreadItem item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectChatScreen(
              peerId: item.peerId,
              peerName: item.peerName,
              peerAvatar: item.peerAvatar,
            ),
          ),
        );
        _fetchExistingChatThreads();
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: lightPinkBg,
            backgroundImage: item.peerAvatar.isNotEmpty
                ? NetworkImage(item.peerAvatar)
                : null,
            child: item.peerAvatar.isEmpty
                ? Text(
                    item.peerName.isNotEmpty ? item.peerName[0] : 'U',
                    style: const TextStyle(
                      color: primaryPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.peerName,
              style: const TextStyle(
                color: textDark,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: lightPinkBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.role,
              style: const TextStyle(
                color: primaryPink,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        item.lastMessage,
        style: TextStyle(
          color: item.unreadCount > 0 ? textDark : textGrey,
          fontSize: 12,
          fontWeight: item.unreadCount > 0
              ? FontWeight.w800
              : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            item.time,
            style: const TextStyle(
              color: textGrey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (item.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: primaryPink,
                shape: BoxShape.circle,
              ),
              child: Text(
                "${item.unreadCount}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
