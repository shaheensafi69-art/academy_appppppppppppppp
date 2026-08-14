import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId;

  const UserProfileScreen({super.key, this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> userPosts = [];
  
  String friendshipStatus = 'none'; // 'none', 'friends', 'pending_sent', 'pending_received'
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

  String get targetUserId {
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      return widget.userId!;
    }
    return supabase.auth.currentUser?.id ?? '';
  }

  bool get isMyProfile {
    final current = supabase.auth.currentUser?.id;
    return widget.userId == null || widget.userId!.isEmpty || widget.userId == current;
  }

  Future<void> _fetchProfileAndPosts() async {
    setState(() => isLoading = true);
    try {
      if (targetUserId.isEmpty) return;

      // دریافت اطلاعات پروفایل
      final res = await supabase
          .from("profiles")
          .select("*")
          .eq("id", targetUserId)
          .maybeSingle();

      // دریافت تعداد دوستان
      final friendsRes = await supabase
          .from("student_friends")
          .select("id")
          .or("sender_id.eq.$targetUserId,receiver_id.eq.$targetUserId")
          .eq("status", "accepted");

      int count = (friendsRes is List) ? friendsRes.length : 0;

      // بررسی وضعیت دوستی
      String status = 'none';
      final currentUser = supabase.auth.currentUser;
      if (!isMyProfile && currentUser != null) {
        final relRes = await supabase
            .from("student_friends")
            .select("*")
            .or("and(sender_id.eq.${currentUser.id},receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.${currentUser.id})")
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

      // دریافت پست‌های کاربر و شمارش لایک و کامنت‌ها
      final postsRes = await supabase
          .from("discussion_posts")
          .select("*")
          .eq("student_id", targetUserId)
          .order("created_at", ascending: false);

      List<Map<String, dynamic>> enrichedPosts = [];
      if (postsRes is List) {
        for (var post in postsRes) {
          String pId = post['id'].toString();

          int likesCount = 0;
          try {
            final likesRes = await supabase.from("discussion_likes").select("id").eq("post_id", pId);
            if (likesRes is List) likesCount = likesRes.length;
          } catch (_) {}

          int commentsCount = 0;
          try {
            final commentsRes = await supabase.from("discussion_comments").select("id").eq("post_id", pId);
            if (commentsRes is List) commentsCount = commentsRes.length;
          } catch (_) {}

          enrichedPosts.add({
            ...post,
            'likes_count': likesCount,
            'comments_count': commentsCount,
          });
        }
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
        setState(() => friendshipStatus = 'pending_sent');
      } else if (friendshipStatus == 'pending_sent' || friendshipStatus == 'friends') {
        await supabase
            .from("student_friends")
            .delete()
            .or("and(sender_id.eq.${currentUser.id},receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.${currentUser.id})");
        setState(() => friendshipStatus = 'none');
      } else if (friendshipStatus == 'pending_received') {
        await supabase
            .from("student_friends")
            .update({'status': 'accepted'})
            .or("and(sender_id.eq.$targetUserId,receiver_id.eq.${currentUser.id})");
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
      setState(() {
        userPosts.removeWhere((p) => p['id'].toString() == postId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post deleted successfully.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting post: $e")));
      }
    }
  }

  Future<void> _editPostModal(Map<String, dynamic> post) async {
    final TextEditingController titleController = TextEditingController(text: post['title']);
    final TextEditingController contentController = TextEditingController(text: post['content']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Post ✏️", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              cursorColor: primaryPink,
              decoration: _inputDecoration("Title"),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              cursorColor: primaryPink,
              maxLines: 5,
              decoration: _inputDecoration("Content"),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink, 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  try {
                    await supabase.from("discussion_posts").update({
                      'title': titleController.text.trim(),
                      'content': contentController.text.trim(),
                    }).eq("id", post['id']);

                    if (mounted) {
                      Navigator.pop(context);
                      _fetchProfileAndPosts();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post updated successfully!")));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating post: $e")));
                  }
                },
                child: const Text("UPDATE POST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- حل مشکل ۱: منوی کشویی زیبا و حرفه‌ای برای ادیت و دلیت ---
  void _showPostActionMenu(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              // گزینه Edit
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _editPostModal(post);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, color: Colors.blue, size: 24),
                      const SizedBox(width: 16),
                      const Text("Edit Post", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textDark)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: Colors.blue.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // گزینه Delete
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(post['id'].toString());
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
                      const SizedBox(width: 16),
                      const Text("Delete Post", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.red)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: Colors.red.withOpacity(0.5)),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Post", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to delete this post? This action cannot be undone.", style: TextStyle(color: textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- باز کردن کامنت‌ها ---
  void _openCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsWidget(
        postId: postId, 
        currentUserId: supabase.auth.currentUser?.id ?? ''
      ),
    ).then((_) {
      _fetchProfileAndPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(isMyProfile ? "My Profile" : "User Profile", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFF0F5), surfaceWhite, lightPinkBg.withOpacity(0.2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryPink))
            : profileData != null
                ? RefreshIndicator(
                    color: primaryPink,
                    onRefresh: _fetchProfileAndPosts,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // بخش کارت اطلاعات پروفایل
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                                  boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 36,
                                          backgroundColor: lightPinkBg,
                                          backgroundImage: profileData!['avatar_url'] != null && profileData!['avatar_url'].toString().isNotEmpty
                                              ? NetworkImage(profileData!['avatar_url'])
                                              : null,
                                          child: profileData!['avatar_url'] == null || profileData!['avatar_url'].toString().isEmpty
                                              ? Text(
                                                  profileData!['first_name'] != null && profileData!['first_name'].toString().isNotEmpty
                                                      ? profileData!['first_name'][0]
                                                      : 'U',
                                                  style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 24),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                                child: Text((profileData!['role'] ?? 'student').toString().toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink)),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                "${profileData!['first_name'] ?? ''} ${profileData!['last_name'] ?? ''}",
                                                style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(profileData!['email'] ?? '', style: const TextStyle(color: textGrey, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(color: cardBorder, height: 1),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem("Friends", "$friendsCount"),
                                        _buildStatItem("Score", "${profileData!['total_score'] ?? 0}"),
                                        _buildStatItem("Posts", "${userPosts.length}"),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    if (!isMyProfile)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: friendshipStatus == 'friends' ? cardBorder : primaryPink,
                                            foregroundColor: friendshipStatus == 'friends' ? textDark : Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          icon: Icon(
                                            friendshipStatus == 'friends'
                                                ? Icons.how_to_reg_rounded
                                                : friendshipStatus == 'pending_sent'
                                                    ? Icons.access_time_rounded
                                                    : friendshipStatus == 'pending_received'
                                                        ? Icons.person_add_alt_1_rounded
                                                        : Icons.person_add_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            friendshipStatus == 'friends'
                                                ? 'Friends ✓ (Click to Remove)'
                                                : friendshipStatus == 'pending_sent'
                                                    ? 'Request Pending'
                                                    : friendshipStatus == 'pending_received'
                                                        ? 'Accept Friend Request'
                                                        : 'Add Friend 🤝',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                                          ),
                                          onPressed: isActionLoading ? null : _handleFriendAction,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // بیوگرافی
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
                                    const Text("About Me", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                    const SizedBox(height: 8),
                                    Text(
                                      (profileData!['bio'] != null && profileData!['bio'].toString().isNotEmpty)
                                          ? profileData!['bio']
                                          : "No biography provided yet.",
                                      style: const TextStyle(color: textGrey, fontSize: 12, height: 1.4),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildInfoRow(Icons.public_rounded, "Country", profileData!['country'] ?? 'Not specified'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // بخش نمایش پست‌های کاربر
                              const Text("User Posts", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 12),

                              userPosts.isNotEmpty
                                  ? ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: userPosts.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                                      itemBuilder: (context, index) {
                                        final post = userPosts[index];
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: surfaceWhite,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: cardBorder, width: 1.5),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    post['created_at']?.toString().split('T')[0] ?? '',
                                                    style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                  if (isMyProfile)
                                                    IconButton(
                                                      icon: const Icon(Icons.more_horiz_rounded, color: textGrey),
                                                      onPressed: () => _showPostActionMenu(post),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(post['title'] ?? '', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                              const SizedBox(height: 4),
                                              Text(post['content'] ?? '', style: const TextStyle(color: textGrey, fontSize: 12, height: 1.3)),
                                              if (post['image_url'] != null && post['image_url'].toString().isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(post['image_url'], height: 180, width: double.infinity, fit: BoxFit.cover),
                                                ),
                                              ],
                                              const SizedBox(height: 12),
                                              const Divider(color: cardBorder),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.favorite_rounded, color: primaryPink, size: 16),
                                                      const SizedBox(width: 6),
                                                      Text("${post['likes_count'] ?? 0} Likes", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                  InkWell(
                                                    onTap: () => _openCommentsBottomSheet(post['id'].toString()),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.mode_comment_outlined, color: textGrey, size: 16),
                                                          const SizedBox(width: 6),
                                                          Text("${post['comments_count'] ?? 0} Comments", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                        border: Border.all(color: cardBorder, width: 1.5),
                                      ),
                                      child: const Text("No posts shared by this user yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const Center(child: Text("Profile not found.", style: TextStyle(color: textDark, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: const TextStyle(color: textGrey, fontWeight: FontWeight.w900, fontSize: 9)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: primaryPink, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
      filled: true,
      fillColor: cardBorder.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
    );
  }
}

// =====================================================================
// حل مشکل ۲: ویجت نمایش کامنت‌ها و قابلیت ریپلای زدن
// این ویجت برای جلوگیری از ارور ارتباط (Join) به صورت دستی پروفایل را دریافت می‌کند
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
      // دریافت تمام کامنت‌های مربوط به این پست
      final res = await supabase
          .from("discussion_comments")
          .select("*")
          .eq("post_id", widget.postId)
          .order("created_at", ascending: true);

      List<Map<String, dynamic>> fetchedComments = List<Map<String, dynamic>>.from(res as List);
      
      // دریافت دستی اطلاعات پروفایل برای جلوگیری از ارور ارتباط دیتابیس (Join Error)
      Set<String> studentIds = fetchedComments.map((c) => c['student_id'].toString()).toSet();
      Map<String, Map<String, dynamic>> profilesMap = {};
      
      for (String sId in studentIds) {
        try {
          final p = await supabase.from("profiles").select("first_name, last_name, avatar_url").eq("id", sId).maybeSingle();
          if (p != null) profilesMap[sId] = p;
        } catch (_) {}
      }

      // جایگذاری اطلاعات پروفایل در کامنت‌ها
      for (var c in fetchedComments) {
        String sId = c['student_id'].toString();
        c['profiles'] = profilesMap[sId] ?? {
          'first_name': 'Student',
          'last_name': '',
          'avatar_url': ''
        };
      }

      if (mounted) {
        setState(() {
          comments = fetchedComments;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comments: $e");
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

      if (replyingToCommentId != null) {
        insertData['parent_comment_id'] = replyingToCommentId!;
      }

      await supabase.from("discussion_comments").insert(insertData);

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
    // باز شدن کیبورد برای نوشتن ریپلای
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      replyingToCommentId = null;
      replyingToName = null;
    });
    _commentFocusNode.unfocus();
  }

  // نمایش درختی کامنت‌ها
  List<Widget> _buildCommentTree(String? parentId, double leftPadding) {
    final childComments = comments.where((c) {
      if (parentId == null) return c['parent_comment_id'] == null;
      return c['parent_comment_id']?.toString() == parentId;
    }).toList();
    
    List<Widget> commentWidgets = [];
    for (var c in childComments) {
      final String authorName = "${c['profiles']?['first_name'] ?? 'User'} ${c['profiles']?['last_name'] ?? ''}".trim();
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
                backgroundImage: c['profiles']?['avatar_url'] != null && c['profiles']?['avatar_url'] != '' ? NetworkImage(c['profiles']['avatar_url']) : null,
                child: c['profiles']?['avatar_url'] == null || c['profiles']?['avatar_url'] == '' ? const Icon(Icons.person, size: 16, color: Color(0xFFC2185B)) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(authorName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF111827))),
                          const SizedBox(height: 4),
                          Text(c['comment_text'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Text(c['created_at']?.toString().split('T')[0] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _startReplying(cId, authorName),
                            child: const Text("Reply", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF6B7280))),
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

      // جلوگیری از تو رفتگی بیش از حد ریپلای‌ها (Padding Limit)
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
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),
          const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const Divider(height: 30),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)))
                : comments.isEmpty
                    ? const Center(child: Text("No comments yet. Start the conversation!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        children: _buildCommentTree(null, 0),
                      ),
          ),
          
          // نوار ارسال کامنت 
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
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
                        Text("Replying to $replyingToName", style: const TextStyle(fontSize: 12, color: Color(0xFFC2185B), fontWeight: FontWeight.w900)),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                        )
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: replyingToName != null ? "Write a reply..." : "Add a comment...",
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(color: Color(0xFFC2185B), shape: BoxShape.circle),
                      child: IconButton(
                        icon: isSending 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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