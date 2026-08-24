import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../chat/screens/direct_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId;
  final VoidCallback? onExit;

  const UserProfileScreen({super.key, this.userId, this.onExit});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> userPosts = [];

  String friendshipStatus = 'none';
  bool isActionLoading = false;
  int friendsCount = 0;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchProfileAndPosts();
  }

  String get targetUserId =>
      (widget.userId != null && widget.userId!.isNotEmpty)
      ? widget.userId!
      : (supabase.auth.currentUser?.id ?? '');
  bool get isMyProfile =>
      widget.userId == null ||
      widget.userId!.isEmpty ||
      widget.userId == supabase.auth.currentUser?.id;

  String _extractMood(String title) {
    if (title.startsWith('[') && title.contains(']')) {
      int endIndex = title.indexOf(']');
      return title.substring(1, endIndex);
    }
    return "📢 Post";
  }

  String _extractCleanTitle(String title) {
    if (title.startsWith('[') && title.contains(']')) {
      int endIndex = title.indexOf(']');
      return title.substring(endIndex + 1).trim();
    }
    return title;
  }

  Future<void> _fetchProfileAndPosts() async {
    setState(() => isLoading = true);
    try {
      if (targetUserId.isEmpty) return;

      final res = await supabase
          .from("profiles")
          .select("*")
          .eq("id", targetUserId)
          .maybeSingle();
      final friendsRes = await supabase
          .from("student_friends")
          .select("id")
          .or("sender_id.eq.$targetUserId,receiver_id.eq.$targetUserId")
          .eq("status", "accepted");
      int count = (friendsRes as List).length;

      String status = 'none';
      final currentUser = supabase.auth.currentUser;
      if (!isMyProfile && currentUser != null) {
        final relRes = await supabase
            .from("student_friends")
            .select("*")
            .or(
              "and(sender_id.eq.${currentUser.id},receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.${currentUser.id})",
            )
            .maybeSingle();
        if (relRes != null) {
          if (relRes['status'] == 'accepted') {
            status = 'friends';
          } else if (relRes['sender_id'] == currentUser.id) {
            status = 'pending_sent';
          } else {
            status = 'pending_received';
          }
        }
      }

      final postsRes = await supabase
          .from("discussion_posts")
          .select("*")
          .eq("student_id", targetUserId)
          .order("created_at", ascending: false);
      List<Map<String, dynamic>> enrichedPosts = [];
      for (var post in postsRes) {
        String pId = post['id'].toString();
        int likesCount = 0;
        bool isLikedByMe = false;
        try {
          final likesRes = await supabase
              .from("discussion_likes")
              .select("student_id")
              .eq("post_id", pId);
          likesCount = likesRes.length;
          if (currentUser != null)
            isLikedByMe = likesRes.any(
              (like) => like['student_id'] == currentUser.id,
            );
        } catch (_) {}

        int commentsCount = 0;
        try {
          final commentsRes = await supabase
              .from("discussion_comments")
              .select("id")
              .eq("post_id", pId);
          commentsCount = commentsRes.length;
        } catch (_) {}

        enrichedPosts.add({
          ...post,
          'likes_count': likesCount,
          'comments_count': commentsCount,
          'is_liked_by_me': isLikedByMe,
        });
      }

      if (mounted) {
        setState(() {
          profileData = res;
          friendsCount = count;
          friendshipStatus = status;
          userPosts = enrichedPosts;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile & posts: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // دیالوگ ویرایش پروفایل برای کاربر خودم
  void _showEditProfileModal() {
    final TextEditingController firstNameController = TextEditingController(
      text: profileData?['first_name'] ?? '',
    );
    final TextEditingController lastNameController = TextEditingController(
      text: profileData?['last_name'] ?? '',
    );
    final TextEditingController countryController = TextEditingController(
      text: profileData?['country'] ?? '',
    );
    final TextEditingController dobController = TextEditingController(
      text: profileData?['date_of_birth'] ?? '',
    );
    final TextEditingController bioController = TextEditingController(
      text: profileData?['bio'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Edit Profile ✏️",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: firstNameController,
                cursorColor: primaryPink,
                decoration: _inputDecoration("First Name"),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                cursorColor: primaryPink,
                decoration: _inputDecoration("Last Name"),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryController,
                cursorColor: primaryPink,
                decoration: _inputDecoration("Country"),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dobController,
                cursorColor: primaryPink,
                decoration: _inputDecoration("Date of Birth (YYYY-MM-DD)"),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                cursorColor: primaryPink,
                maxLines: 4,
                decoration: _inputDecoration("Biography / About Me"),
                style: const TextStyle(fontSize: 14, color: textDark),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      final user = supabase.auth.currentUser;
                      if (user == null) return;

                      await supabase
                          .from("profiles")
                          .update({
                            'first_name': firstNameController.text.trim(),
                            'last_name': lastNameController.text.trim(),
                            'country': countryController.text.trim(),
                            'date_of_birth': dobController.text.trim().isEmpty
                                ? null
                                : dobController.text.trim(),
                            'bio': bioController.text.trim(),
                          })
                          .eq("id", user.id);

                      if (!mounted) return;
                      Navigator.pop(sheetContext);
                      await _fetchProfileAndPosts();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile updated successfully! ✅"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error updating profile: $e"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "SAVE CHANGES",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textGrey, fontSize: 13),
      filled: true,
      fillColor: cardBorder.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cardBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryPink, width: 1.5),
      ),
    );
  }

  Future<void> _handleFriendAction() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    setState(() => isActionLoading = true);
    try {
      if (friendshipStatus == 'none') {
        await supabase.from("student_friends").insert({
          'sender_id': currentUser.id,
          'receiver_id': targetUserId,
          'status': 'pending',
        });
        if (!mounted) return;
        setState(() => friendshipStatus = 'pending_sent');
      } else if (friendshipStatus == 'pending_sent' ||
          friendshipStatus == 'friends') {
        await supabase
            .from("student_friends")
            .delete()
            .or(
              "and(sender_id.eq.${currentUser.id},receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.${currentUser.id})",
            );
        if (!mounted) return;
        setState(() => friendshipStatus = 'none');
      } else if (friendshipStatus == 'pending_received') {
        await supabase
            .from("student_friends")
            .update({'status': 'accepted'})
            .or(
              "and(sender_id.eq.$targetUserId,receiver_id.eq.${currentUser.id})",
            );
        if (!mounted) return;
        setState(() => friendshipStatus = 'friends');
      }
    } catch (e) {
      debugPrint("Error handling friendship: $e");
    } finally {
      if (mounted) setState(() => isActionLoading = false);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await supabase.from("discussion_posts").delete().eq("id", postId);
      if (!mounted) return;
      setState(
        () => userPosts.removeWhere((p) => p['id'].toString() == postId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted successfully.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting post: $e")));
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post, int index) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    bool currentlyLiked = post['is_liked_by_me'] ?? false;
    int currentLikes = post['likes_count'] ?? 0;

    setState(() {
      if (currentlyLiked) {
        userPosts[index]['is_liked_by_me'] = false;
        userPosts[index]['likes_count'] = (currentLikes > 0)
            ? currentLikes - 1
            : 0;
      } else {
        userPosts[index]['is_liked_by_me'] = true;
        userPosts[index]['likes_count'] = currentLikes + 1;
      }
    });

    try {
      if (currentlyLiked) {
        await supabase
            .from("discussion_likes")
            .delete()
            .eq("post_id", post['id'])
            .eq("student_id", currentUser.id);
      } else {
        await supabase.from("discussion_likes").insert({
          "post_id": post['id'],
          "student_id": currentUser.id,
        });
      }
    } catch (e) {
      _fetchProfileAndPosts();
    }
  }

  void _showPostActionMenu(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirmation(post['id'].toString());
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Delete Post",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.red,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Post",
          style: TextStyle(fontWeight: FontWeight.w900, color: textDark),
        ),
        content: const Text(
          "Are you sure you want to delete this post? This action cannot be undone.",
          style: TextStyle(color: textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Cancel",
              style: TextStyle(color: textGrey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deletePost(postId);
            },
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsWidget(
        postId: postId,
        currentUserId: supabase.auth.currentUser?.id ?? '',
      ),
    ).then((_) => _fetchProfileAndPosts());
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacher = profileData?['role'] == 'teacher';
    bool isAdmin =
        profileData?['role'] == 'admin' ||
        profileData?['role'] == 'super_admin';
    Color roleColor = isAdmin
        ? Colors.deepPurple
        : (isTeacher ? Colors.blueAccent : primaryPink);
    String roleLabel = isAdmin
        ? "ADMINISTRATOR 🛡️"
        : (isTeacher ? "INSTRUCTOR 🎓" : "STUDENT 🌍");

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(
          isMyProfile ? "My Profile" : "Academy Profile",
          style: const TextStyle(
            color: textDark,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.exit_to_app_rounded, size: 18),
            label: const Text(
              "EXIT",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (isMyProfile) {
                if (widget.onExit != null) {
                  widget.onExit!();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFF0F5),
              surfaceWhite,
              lightPinkBg.withValues(alpha: 0.2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryPink,
                  strokeWidth: 3,
                ),
              )
            : profileData != null
            ? RefreshIndicator(
                color: primaryPink,
                onRefresh: _fetchProfileAndPosts,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // کارت اطلاعات پروفایل
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: roleColor.withValues(alpha: 0.08),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundColor: roleColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      backgroundImage:
                                          profileData!['avatar_url'] != null &&
                                              profileData!['avatar_url']
                                                  .toString()
                                                  .isNotEmpty
                                          ? NetworkImage(
                                              profileData!['avatar_url'],
                                            )
                                          : null,
                                      child:
                                          profileData!['avatar_url'] == null ||
                                              profileData!['avatar_url']
                                                  .toString()
                                                  .isEmpty
                                          ? Text(
                                              profileData!['first_name'] !=
                                                          null &&
                                                      profileData!['first_name']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? profileData!['first_name'][0]
                                                  : 'U',
                                              style: TextStyle(
                                                color: roleColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 24,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              roleLabel,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: roleColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "${profileData!['first_name'] ?? ''} ${profileData!['last_name'] ?? ''}",
                                            style: const TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Divider(color: cardBorder, height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(
                                      "Network",
                                      "$friendsCount",
                                      roleColor,
                                    ),
                                    if (!isTeacher && !isAdmin)
                                      _buildStatItem(
                                        "Score",
                                        "${profileData!['total_score'] ?? 0}",
                                        roleColor,
                                      ),
                                    _buildStatItem(
                                      "Posts",
                                      "${userPosts.length}",
                                      roleColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                if (isMyProfile)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: lightPinkBg,
                                        foregroundColor: primaryPink,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        "Edit My Profile ✏️",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: _showEditProfileModal,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                friendshipStatus == 'friends'
                                                ? cardBorder
                                                : primaryPink,
                                            foregroundColor:
                                                friendshipStatus == 'friends'
                                                ? textDark
                                                : Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: Icon(
                                            friendshipStatus == 'friends'
                                                ? Icons.how_to_reg_rounded
                                                : friendshipStatus ==
                                                      'pending_sent'
                                                ? Icons.access_time_rounded
                                                : friendshipStatus ==
                                                      'pending_received'
                                                ? Icons.person_add_alt_1_rounded
                                                : Icons.person_add_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            friendshipStatus == 'friends'
                                                ? 'Connected ✓'
                                                : friendshipStatus ==
                                                      'pending_sent'
                                                ? 'Pending'
                                                : friendshipStatus ==
                                                      'pending_received'
                                                ? 'Accept'
                                                : 'Connect 🤝',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: isActionLoading
                                              ? null
                                              : _handleFriendAction,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryPink,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          "Chat 💬",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () {
                                          final targetId =
                                              widget.userId ??
                                              (profileData != null
                                                  ? profileData!['id']
                                                  : null);
                                          if (targetId != null) {
                                            final peerName =
                                                "${profileData?['first_name'] ?? ''} ${profileData?['last_name'] ?? ''}"
                                                    .trim();
                                            final peerAvatar =
                                                profileData?['avatar_url'] ??
                                                '';
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    DirectChatScreen(
                                                      peerId: targetId,
                                                      peerName:
                                                          peerName.isNotEmpty
                                                          ? peerName
                                                          : 'User',
                                                      peerAvatar: peerAvatar,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // اطلاعات کامل پروفایل (بدون شماره موبایل و اسم پدر)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Complete Profile Info",
                                  style: TextStyle(
                                    color: textDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  (profileData!['bio'] != null &&
                                          profileData!['bio']
                                              .toString()
                                              .isNotEmpty)
                                      ? profileData!['bio']
                                      : "No biography provided yet.",
                                  style: const TextStyle(
                                    color: textGrey,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  Icons.email_outlined,
                                  "Email Address",
                                  profileData!['email'] ?? 'Not specified',
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.cake_rounded,
                                  "Date of Birth",
                                  profileData!['date_of_birth'] ??
                                      'Not specified',
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.public_rounded,
                                  "Country",
                                  profileData!['country'] ?? 'Global',
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.account_balance_wallet_rounded,
                                  "Wallet Balance",
                                  "\$${(profileData!['wallet_balance'] ?? 0).toDouble().toStringAsFixed(2)}",
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.bolt_rounded,
                                  "Total Score",
                                  "${profileData!['total_score'] ?? 0} XP",
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.qr_code_rounded,
                                  "Referral Code",
                                  profileData!['referral_code'] ?? 'N/A',
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.link_rounded,
                                  "Referral Link",
                                  profileData!['referral_link'] ?? 'N/A',
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.percent_rounded,
                                  "Referral Discount Rate",
                                  "${profileData!['referral_discount_rate'] ?? 0}%",
                                  roleColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  Icons.calendar_today_rounded,
                                  "Member Since",
                                  profileData!['created_at'] != null
                                      ? profileData!['created_at']
                                            .toString()
                                            .split('T')[0]
                                      : 'N/A',
                                  roleColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // بخش نمایش پست‌های کاربر
                          const Text(
                            "Shared Posts",
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),

                          userPosts.isNotEmpty
                              ? ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: userPosts.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final post = userPosts[index];
                                    final rawTitle = post['title'] ?? '';
                                    final moodTag = _extractMood(rawTitle);
                                    final cleanTitle = _extractCleanTitle(
                                      rawTitle,
                                    );
                                    final imageUrl = post['image_url'];

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: surfaceWhite,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: cardBorder,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                post['created_at']
                                                        ?.toString()
                                                        .split('T')[0] ??
                                                    '',
                                                style: const TextStyle(
                                                  color: textGrey,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (isMyProfile)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.more_horiz_rounded,
                                                    color: textGrey,
                                                  ),
                                                  onPressed: () =>
                                                      _showPostActionMenu(post),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // تگ مود جدا شده
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: lightPinkBg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              moodTag,
                                              style: const TextStyle(
                                                color: primaryPink,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          if (cleanTitle.isNotEmpty) ...[
                                            Text(
                                              cleanTitle,
                                              style: const TextStyle(
                                                color: textDark,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          Text(
                                            post['content'] ?? '',
                                            style: const TextStyle(
                                              color: textGrey,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),

                                          // نمایش تصویر پست با Placeholder و لودینگ استاندارد
                                          if (imageUrl != null &&
                                              imageUrl
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 14),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.height *
                                                      0.35,
                                                ),
                                                width: double.infinity,
                                                color: Colors.grey.shade100,
                                                child: Image.network(
                                                  imageUrl.toString(),
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (
                                                        context,
                                                        child,
                                                        loadingProgress,
                                                      ) {
                                                        if (loadingProgress ==
                                                            null)
                                                          return child;
                                                        return Container(
                                                          height: 180,
                                                          alignment:
                                                              Alignment.center,
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              const CircularProgressIndicator(
                                                                color:
                                                                    primaryPink,
                                                                strokeWidth: 2,
                                                              ),
                                                              const SizedBox(
                                                                height: 6,
                                                              ),
                                                              Text(
                                                                "Loading image...",
                                                                style: TextStyle(
                                                                  color:
                                                                      textGrey,
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Container(
                                                          height: 140,
                                                          alignment:
                                                              Alignment.center,
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                          child: const Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .broken_image_rounded,
                                                                color: textGrey,
                                                                size: 28,
                                                              ),
                                                              SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                "Image failed to load",
                                                                style: TextStyle(
                                                                  color:
                                                                      textGrey,
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                ),
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 12),
                                          const Divider(color: cardBorder),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              InkWell(
                                                onTap: () =>
                                                    _toggleLike(post, index),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 12,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        (post['is_liked_by_me'] ??
                                                                false)
                                                            ? Icons
                                                                  .thumb_up_rounded
                                                            : Icons
                                                                  .thumb_up_outlined,
                                                        color:
                                                            (post['is_liked_by_me'] ??
                                                                false)
                                                            ? primaryPink
                                                            : textGrey,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "${post['likes_count'] ?? 0} Likes",
                                                        style: TextStyle(
                                                          color:
                                                              (post['is_liked_by_me'] ??
                                                                  false)
                                                              ? primaryPink
                                                              : textGrey,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    _openCommentsBottomSheet(
                                                      post['id'].toString(),
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 12,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .mode_comment_outlined,
                                                        color: textGrey,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "${post['comments_count'] ?? 0} Comments",
                                                        style: const TextStyle(
                                                          color: textGrey,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: cardBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Text(
                                    "No posts shared by this user yet.",
                                    style: TextStyle(
                                      color: textGrey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : const Center(
                child: Text(
                  "Profile not found.",
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: textGrey,
            fontWeight: FontWeight.w900,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: textGrey,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// ویجت نمایش کامنت‌ها در پروفایل
// =====================================================================
class _CommentsWidget extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const _CommentsWidget({required this.postId, required this.currentUserId});

  @override
  State<_CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<_CommentsWidget> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSending = false;
  List<Map<String, dynamic>> comments = [];

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  String? replyingToCommentId;
  String? replyingToName;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() => isLoading = true);
    try {
      final res = await supabase
          .from("discussion_comments")
          .select("*")
          .eq("post_id", widget.postId)
          .order("created_at", ascending: true);
      List<Map<String, dynamic>> fetchedComments =
          List<Map<String, dynamic>>.from(res as List);

      Set<String> studentIds = fetchedComments
          .map((c) => c['student_id'].toString())
          .toSet();
      Map<String, Map<String, dynamic>> profilesMap = {};

      for (String sId in studentIds) {
        try {
          final p = await supabase
              .from("profiles")
              .select("first_name, last_name, avatar_url")
              .eq("id", sId)
              .maybeSingle();
          if (p != null) profilesMap[sId] = p;
        } catch (_) {}
      }

      for (var c in fetchedComments) {
        String sId = c['student_id'].toString();
        c['profiles'] =
            profilesMap[sId] ??
            {'first_name': 'User', 'last_name': '', 'avatar_url': ''};
      }

      if (mounted) {
        setState(() {
          comments = fetchedComments;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => isSending = true);
    try {
      final insertData = {
        'post_id': widget.postId,
        'student_id': widget.currentUserId,
        'comment_text': text,
      };
      if (replyingToCommentId != null)
        insertData['parent_comment_id'] = replyingToCommentId!;

      await supabase.from("discussion_comments").insert(insertData);

      if (!mounted) return;
      _commentController.clear();
      _commentFocusNode.unfocus();
      setState(() {
        replyingToCommentId = null;
        replyingToName = null;
      });
      await _fetchComments();
    } catch (e) {
      debugPrint("Error sending comment: $e");
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _startReplying(String commentId, String authorName) {
    setState(() {
      replyingToCommentId = commentId;
      replyingToName = authorName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      replyingToCommentId = null;
      replyingToName = null;
    });
    _commentFocusNode.unfocus();
  }

  List<Widget> _buildCommentTree(String? parentId, double leftPadding) {
    final childComments = comments.where((c) {
      if (parentId == null) return c['parent_comment_id'] == null;
      return c['parent_comment_id']?.toString() == parentId;
    }).toList();

    List<Widget> commentWidgets = [];
    for (var c in childComments) {
      final String authorName =
          "${c['profiles']?['first_name'] ?? 'User'} ${c['profiles']?['last_name'] ?? ''}"
              .trim();
      final String cId = c['id'].toString();

      commentWidgets.add(
        Padding(
          padding: EdgeInsets.only(left: leftPadding, bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFCE4EC),
                backgroundImage:
                    c['profiles']?['avatar_url'] != null &&
                        c['profiles']?['avatar_url'] != ''
                    ? NetworkImage(c['profiles']['avatar_url'])
                    : null,
                child:
                    c['profiles']?['avatar_url'] == null ||
                        c['profiles']?['avatar_url'] == ''
                    ? const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFFC2185B),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c['comment_text'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Text(
                            c['created_at']?.toString().split('T')[0] ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _startReplying(cId, authorName),
                            child: const Text(
                              "Reply",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      double nextPadding = leftPadding + 36;
      if (nextPadding > 72) nextPadding = 72;
      commentWidgets.addAll(_buildCommentTree(cId, nextPadding));
    }
    return commentWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Comments",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const Divider(height: 30),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFC2185B)),
                  )
                : comments.isEmpty
                ? const Center(
                    child: Text(
                      "No comments yet. Start the conversation!",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: _buildCommentTree(null, 0),
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyingToName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Replying to $replyingToName",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFC2185B),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        cursorColor: const Color(0xFFC2185B),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: replyingToName != null
                              ? "Write a reply..."
                              : "Add a comment...",
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFC2185B),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                        onPressed: isSending ? null : _sendComment,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
