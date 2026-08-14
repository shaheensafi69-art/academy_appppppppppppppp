import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';

class StudentFriendsScreen extends StatefulWidget {
  const StudentFriendsScreen({super.key});

  @override
  State<StudentFriendsScreen> createState() => _StudentFriendsScreenState();
}

class _StudentFriendsScreenState extends State<StudentFriendsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  List<Map<String, dynamic>> myFriends = [];
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> exploreUsers = [];

  String activeTab = "friends"; // "friends", "requests", "explore"
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchFriendshipsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriendshipsData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final relations = await supabase
          .from("student_friends")
          .select("*")
          .or("sender_id.eq.$userId,receiver_id.eq.$userId");

      List<Map<String, dynamic>> friendsList = [];
      List<Map<String, dynamic>> requestsList = [];
      Set<String> connectedUserIds = {userId};

      for (var rel in (relations as List)) {
        String senderId = rel['sender_id'].toString();
        String receiverId = rel['receiver_id'].toString();
        String status = rel['status'].toString();
        String relId = rel['id'].toString();

        String otherId = (senderId == userId) ? receiverId : senderId;

        if (status == 'accepted') {
          connectedUserIds.add(otherId);
          final profile = await _fetchProfile(otherId);
          if (profile != null) {
            friendsList.add({...profile, 'rel_id': relId});
          }
        } else if (status == 'pending' && receiverId == userId) {
          connectedUserIds.add(otherId);
          final profile = await _fetchProfile(otherId);
          if (profile != null) {
            requestsList.add({...profile, 'rel_id': relId});
          }
        } else if (status == 'pending' && senderId == userId) {
          connectedUserIds.add(otherId);
        }
      }

      final profilesRes = await supabase
          .from("profiles")
          .select("*")
          .neq("id", userId)
          .limit(50);

      List<Map<String, dynamic>> exploreList = [];
      for (var p in (profilesRes as List)) {
        String pId = p['id'].toString();
        if (!connectedUserIds.contains(pId)) {
          exploreList.add(p);
        }
      }

      if (mounted) {
        setState(() {
          myFriends = friendsList;
          pendingRequests = requestsList;
          exploreUsers = exploreList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching friendships: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile(String uId) async {
    try {
      final res = await supabase
          .from("profiles")
          .select("*")
          .eq("id", uId)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> _acceptRequest(String relId) async {
    setState(() => isLoading = true);
    try {
      await supabase.from("student_friends").update({'status': 'accepted'}).eq('id', relId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request accepted! ✅"), backgroundColor: Colors.green));
      }
      await _fetchFriendshipsData();
    } catch (e) {
      debugPrint("Error accepting request: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _removeFriendOrDecline(String relId, {bool isDecline = false}) async {
    setState(() => isLoading = true);
    try {
      await supabase.from("student_friends").delete().eq('id', relId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isDecline ? "Friend request declined." : "Removed from friends."),
          backgroundColor: Colors.redAccent,
        ));
      }
      await _fetchFriendshipsData();
    } catch (e) {
      debugPrint("Error removing friend: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);
    try {
      await supabase.from("student_friends").insert({
        'sender_id': user.id,
        'receiver_id': receiverId,
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request sent! 🚀"), backgroundColor: Colors.green));
      }
      await _fetchFriendshipsData();
    } catch (e) {
      debugPrint("Error sending request: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> activeList = [];
    if (activeTab == "friends") activeList = myFriends;
    if (activeTab == "requests") activeList = pendingRequests;
    if (activeTab == "explore") activeList = exploreUsers;

    final filteredList = activeList.where((item) {
      final fullName = "${item['first_name'] ?? ''} ${item['last_name'] ?? ''}".toLowerCase();
      final email = (item['email'] ?? '').toLowerCase();
      return fullName.contains(searchQuery.toLowerCase()) || email.contains(searchQuery.toLowerCase());
    }).toList();

    return AcademyLoadingOverlay(
      isLoading: isLoading,
      message: "LOADING COMMUNITY...",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5), surfaceWhite, lightPinkBg.withOpacity(0.2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- هدر بالای صفحه ---
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
                        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.people_alt_rounded, color: primaryPink, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Student Network", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                                SizedBox(height: 4),
                                Text("Connect, collaborate, and grow your professional network.", style: TextStyle(fontSize: 12, color: textGrey, fontWeight: FontWeight.w500, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- نوار تب‌ها (Segmented Control) ---
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildTabButton("Friends (${myFriends.length})", "friends")),
                          const SizedBox(width: 6),
                          Expanded(child: _buildTabButton("Requests (${pendingRequests.length})", "requests")),
                          const SizedBox(width: 6),
                          Expanded(child: _buildTabButton("Explore", "explore")),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- سرچ باکس ---
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => searchQuery = val),
                      cursorColor: primaryPink,
                      style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600), // رنگ تیره برای جلوگیری از محو شدن
                      decoration: InputDecoration(
                        hintText: "Search by name or email...",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search_rounded, color: primaryPink, size: 22),
                        filled: true,
                        fillColor: cardBorder.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- لیست کاربران ---
                    filteredList.isNotEmpty
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final userItem = filteredList[index];
                              final uId = userItem['id'].toString();
                              final name = "${userItem['first_name'] ?? ''} ${userItem['last_name'] ?? ''}".trim();
                              final avatar = userItem['avatar_url'] ?? '';
                              final country = userItem['country'] ?? 'Global Student';
                              final score = userItem['total_score'] ?? 0;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: cardBorder, width: 1.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uId))),
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: lightPinkBg,
                                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                        child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0] : 'S', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 20)) : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uId))),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name.isNotEmpty ? name : 'Academy Student', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text("$country • Score: $score ⚡", style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // --- دکمه‌های حرفه‌ای بر اساس تب فعال ---
                                    if (activeTab == "friends")
                                      IconButton(
                                        style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                        icon: const Icon(Icons.person_remove_rounded, size: 20, color: Colors.redAccent),
                                        onPressed: () => _removeFriendOrDecline(userItem['rel_id']),
                                        tooltip: "Remove Friend",
                                      )
                                    else if (activeTab == "requests")
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 36,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                                              onPressed: () => _acceptRequest(userItem['rel_id']),
                                              child: const Text("Accept", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            height: 36,
                                            width: 36,
                                            child: IconButton(
                                              style: IconButton.styleFrom(backgroundColor: cardBorder, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                              icon: const Icon(Icons.close_rounded, size: 18, color: textGrey),
                                              onPressed: () => _removeFriendOrDecline(userItem['rel_id'], isDecline: true),
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (activeTab == "explore")
                                      SizedBox(
                                        height: 36,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                                          icon: const Icon(Icons.person_add_rounded, size: 16),
                                          label: const Text("Add", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                          onPressed: () => _sendFriendRequest(uId),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 60, color: textGrey.withOpacity(0.4)),
                                  const SizedBox(height: 16),
                                  const Text("No students found here.", style: TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 100), // فاصله پایین برای Bottom Navigation
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, String tabKey) {
    bool isActive = activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => activeTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? surfaceWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Text(
          title, 
          style: TextStyle(
            color: isActive ? primaryPink : textGrey, 
            fontSize: 12, 
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ویجت کاستوم لودینگ آکادمی (برای جلوگیری از خطای عدم وجود ویجت)
// ============================================================================

class AcademyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AcademyLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = "LOADING...",
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withOpacity(0.95),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFC2185B), strokeWidth: 3),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}