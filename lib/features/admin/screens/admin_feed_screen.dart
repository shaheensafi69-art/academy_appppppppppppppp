import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart'; 

class FeedPostItem {
  final String id;
  final String studentId; 
  final String rawTitle; // تایتل خام برای پردازش
  final String content;
  final String? imageUrl;
  final String createdAt;
  String authorName;
  String authorAvatar;
  int likesCount;
  bool isLikedByMe;
  int commentsCount;

  // فیلدهای استخراج شده هوشمند
  String moodTag;
  String cleanTitle;

  FeedPostItem({
    required this.id,
    required this.studentId,
    required this.rawTitle,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.authorName = "Academy Member",
    this.authorAvatar = "",
    this.likesCount = 0,
    this.isLikedByMe = false,
    this.commentsCount = 0,
  }) : moodTag = _extractMood(rawTitle),
       cleanTitle = _extractCleanTitle(rawTitle);

  static String _extractMood(String title) {
    if (title.startsWith('[') && title.contains(']')) {
      int endIndex = title.indexOf(']');
      return title.substring(1, endIndex);
    }
    return "📢 Post";
  }

  static String _extractCleanTitle(String title) {
    if (title.startsWith('[') && title.contains(']')) {
      int endIndex = title.indexOf(']');
      return title.substring(endIndex + 1).trim();
    }
    return title;
  }

  factory FeedPostItem.fromJson(Map<String, dynamic> json, {String name = "Academy Member", String avatar = "", int likes = 0, bool liked = false, int comments = 0}) {
    return FeedPostItem(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      rawTitle: json['title'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] ?? '',
      authorName: name,
      authorAvatar: avatar,
      likesCount: likes,
      isLikedByMe: liked,
      commentsCount: comments,
    );
  }
}

class AdminFeedScreen extends StatefulWidget {
  const AdminFeedScreen({super.key});

  @override
  State<AdminFeedScreen> createState() => _AdminFeedScreenState();
}

class _AdminFeedScreenState extends State<AdminFeedScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<FeedPostItem> allPosts = [];
  List<FeedPostItem> filteredPosts = [];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false; 

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchFeedPosts();

    _scrollController.addListener(() {
      if (_scrollController.offset > 60 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 60 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedPosts() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      final userId = user?.id;

      final res = await supabase.from("discussion_posts").select("*").order("created_at", ascending: false);

      List<FeedPostItem> loadedPosts = [];

      for (var item in (res as List)) {
        String pId = item['id'].toString();
        String sId = item['student_id'].toString();

        String authorName = "Academy Member";
        String authorAvatar = "";
        try {
          final profileRes = await supabase.from("profiles").select("first_name, last_name, avatar_url").eq("id", sId).maybeSingle();
          if (profileRes != null) {
            authorName = "${profileRes['first_name'] ?? ''} ${profileRes['last_name'] ?? ''}".trim();
            if (authorName.isEmpty) authorName = "Academy Member";
            authorAvatar = profileRes['avatar_url'] ?? '';
          }
        } catch (_) {}

        int likesCount = 0;
        bool isLikedByMe = false;
        try {
          final likesRes = await supabase.from("discussion_likes").select("student_id").eq("post_id", pId);
          likesCount = likesRes.length;
          if (userId != null) isLikedByMe = likesRes.any((l) => l['student_id'] == userId);
                } catch (_) {}

        int commentsCount = 0;
        try {
          final commentsRes = await supabase.from("discussion_comments").select("id").eq("post_id", pId);
          commentsCount = commentsRes.length;
        } catch (_) {}

        loadedPosts.add(FeedPostItem.fromJson(
          item,
          name: authorName,
          avatar: authorAvatar,
          likes: likesCount,
          liked: isLikedByMe,
          comments: commentsCount,
        ));
      }

      if (mounted) {
        setState(() {
          allPosts = loadedPosts;
          filteredPosts = loadedPosts;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Feed posts fetch error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        filteredPosts = allPosts;
      } else {
        final q = query.trim().toLowerCase();
        filteredPosts = allPosts.where((post) {
          final titleMatch = post.cleanTitle.toLowerCase().contains(q);
          final contentMatch = post.content.toLowerCase().contains(q);
          final nameMatch = post.authorName.toLowerCase().contains(q);
          return titleMatch || contentMatch || nameMatch;
        }).toList();
      }
    });
  }

  Future<void> _toggleLike(FeedPostItem post) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      if (post.isLikedByMe) {
        post.isLikedByMe = false;
        post.likesCount = (post.likesCount > 0) ? post.likesCount - 1 : 0;
      } else {
        post.isLikedByMe = true;
        post.likesCount += 1;
      }
    });

    try {
      if (!post.isLikedByMe) {
        await supabase.from("discussion_likes").delete().eq("post_id", post.id).eq("student_id", user.id);
      } else {
        await supabase.from("discussion_likes").insert({"post_id": post.id, "student_id": user.id});
      }
    } catch (e) {
      debugPrint("Error toggling like: $e");
      _fetchFeedPosts();
    }
  }

  void _openCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsWidget(postId: postId, currentUserId: supabase.auth.currentUser?.id ?? ''),
    ).then((_) => _fetchFeedPosts());
  }

  void _scrollToTopAndSearch() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _deletePost(String postId) async {
    try {
      await supabase.from("discussion_posts").delete().eq("id", postId);
      setState(() {
        allPosts.removeWhere((p) => p.id == postId);
        filteredPosts.removeWhere((p) => p.id == postId);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post deleted successfully.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting post: $e")));
    }
  }

  Future<void> _editPostModal(FeedPostItem post) async {
    final TextEditingController titleController = TextEditingController(text: post.cleanTitle);
    final TextEditingController contentController = TextEditingController(text: post.content);

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
            TextField(controller: titleController, cursorColor: primaryPink, decoration: _inputDecoration("Title"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
            const SizedBox(height: 12),
            TextField(controller: contentController, cursorColor: primaryPink, maxLines: 5, decoration: _inputDecoration("Content"), style: const TextStyle(fontSize: 14, color: textDark)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryPink, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  try {
                    String finalTitleToSave = "[${post.moodTag}] ${titleController.text.trim()}";
                    await supabase.from("discussion_posts").update({'title': finalTitleToSave, 'content': contentController.text.trim()}).eq("id", post.id);
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchFeedPosts();
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

  void _showPostActionMenu(FeedPostItem post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(color: surfaceWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              InkWell(
                onTap: () { Navigator.pop(context); _editPostModal(post); },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1.5)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20)),
                      const SizedBox(width: 16),
                      const Text("Edit Post", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textDark)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: Colors.blue.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () { Navigator.pop(context); _showDeleteConfirmation(post.id); },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Delete Post", style: TextStyle(fontWeight: FontWeight.w900))]),
        content: const Text("Are you sure you want to delete this post? This action cannot be undone.", style: TextStyle(color: textGrey, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: textDark, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); _deletePost(postId); },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: textGrey, fontSize: 13), filled: true, fillColor: cardBorder.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFFFF0F5), surfaceWhite, lightPinkBg.withOpacity(0.2)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Stack(
          children: [
            RefreshIndicator(
              color: primaryPink,
              onRefresh: _fetchFeedPosts,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 3))
                  : filteredPosts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: topPadding + 160),
                            Center(child: Column(children: [Icon(Icons.search_off_rounded, size: 60, color: textGrey.withOpacity(0.5)), const SizedBox(height: 16), const Text("No posts found.", style: TextStyle(color: textGrey, fontSize: 16, fontWeight: FontWeight.bold))])),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.only(top: topPadding + (_isScrolled ? 90 : 150), bottom: 100),
                          itemCount: filteredPosts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final post = filteredPosts[index];
                            return _buildPostCard(post);
                          },
                        ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: 0, left: 0, right: 0,
              height: topPadding + (_isScrolled ? 70 : 140),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
                    decoration: BoxDecoration(color: surfaceWhite.withOpacity(0.85), border: Border(bottom: BorderSide(color: cardBorder, width: 1.5)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Academy Feed", style: TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isScrolled
                                  ? GestureDetector(key: const ValueKey('search_btn'), onTap: _scrollToTopAndSearch, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle), child: const Icon(Icons.search_rounded, color: Colors.white, size: 20)))
                                  : Container(key: const ValueKey('notif_btn'), padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: lightPinkBg, shape: BoxShape.circle), child: const Icon(Icons.notifications_none_rounded, color: primaryPink, size: 20)),
                            ),
                          ],
                        ),
                        if (!_isScrolled) ...[
                          const SizedBox(height: 16),
                          Expanded(
                            child: TextField(
                              controller: _searchController, onChanged: _onSearchChanged, cursorColor: primaryPink,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
                              decoration: InputDecoration(
                                hintText: "Search posts, peers, or ideas...", hintStyle: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500), prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, color: textGrey, size: 18), onPressed: () { _searchController.clear(); _onSearchChanged(""); FocusScope.of(context).unfocus(); }) : null,
                                filled: true, fillColor: const Color(0xFFF3F4F6), contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(FeedPostItem post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: surfaceWhite, borderRadius: BorderRadius.circular(24), border: Border.all(color: cardBorder, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: post.studentId))),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryPink.withOpacity(0.2), width: 2)),
                    child: CircleAvatar(
                      radius: 20, backgroundColor: lightPinkBg,
                      backgroundImage: post.authorAvatar.isNotEmpty ? NetworkImage(post.authorAvatar) : null,
                      child: post.authorAvatar.isEmpty ? Text(post.authorName.isNotEmpty ? post.authorName[0] : 'U', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 16)) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: post.studentId))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(children: [const Icon(Icons.public, color: textGrey, size: 12), const SizedBox(width: 4), Text(post.createdAt.isNotEmpty ? post.createdAt.split('T')[0] : '', style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600))]),
                      ],
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_horiz_rounded, color: textGrey), onPressed: () => _showPostActionMenu(post)),
              ],
            ),
          ),
          
          // --- بخش نمایش تگ مود جدا شده در بالای تایتل ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lightPinkBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                post.moodTag,
                style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.cleanTitle.isNotEmpty) ...[
                  Text(post.cleanTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                ],
                Text(post.content, style: const TextStyle(color: Color(0xFF374151), fontSize: 14, height: 1.5)),
              ],
            ),
          ),

          // --- بخش نمایش عکس با Placeholder (موقع لود شدن) ---
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
                            const SizedBox(height: 8),
                            Text("Loading image...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        alignment: Alignment.center,
                        color: Colors.grey.shade200,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, color: textGrey, size: 32),
                            SizedBox(height: 6),
                            Text("Image failed to load", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          if (post.likesCount > 0 || post.commentsCount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (post.likesCount > 0) Row(children: [Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle), child: const Icon(Icons.thumb_up_rounded, color: Colors.white, size: 10)), const SizedBox(width: 6), Text("${post.likesCount}", style: const TextStyle(color: textGrey, fontWeight: FontWeight.bold, fontSize: 12))]) else const SizedBox(),
                  if (post.commentsCount > 0) Text("${post.commentsCount} Comments", style: const TextStyle(color: textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(color: cardBorder, height: 24, thickness: 1.5)),
          ] else ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(color: cardBorder, height: 24, thickness: 1.5)),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: InkWell(onTap: () => _toggleLike(post), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(post.isLikedByMe ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, color: post.isLikedByMe ? primaryPink : textGrey, size: 20), const SizedBox(width: 8), Text("Like", style: TextStyle(color: post.isLikedByMe ? primaryPink : textGrey, fontWeight: FontWeight.bold, fontSize: 13))])))),
                Expanded(child: InkWell(onTap: () => _openCommentsBottomSheet(post.id), borderRadius: BorderRadius.circular(12), child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline_rounded, color: textGrey, size: 20), SizedBox(width: 8), Text("Comment", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold, fontSize: 13))])))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// کلاس نمایش کامنت‌ها 
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
      final res = await supabase.from("discussion_comments").select("*").eq("post_id", widget.postId).order("created_at", ascending: true);
      List<Map<String, dynamic>> fetchedComments = List<Map<String, dynamic>>.from(res as List);
      
      Set<String> studentIds = fetchedComments.map((c) => c['student_id'].toString()).toSet();
      Map<String, Map<String, dynamic>> profilesMap = {};
      
      for (String sId in studentIds) {
        try {
          final p = await supabase.from("profiles").select("first_name, last_name, avatar_url").eq("id", sId).maybeSingle();
          if (p != null) profilesMap[sId] = p;
        } catch (_) {}
      }

      for (var c in fetchedComments) {
        String sId = c['student_id'].toString();
        c['profiles'] = profilesMap[sId] ?? {'first_name': 'User', 'last_name': '', 'avatar_url': ''};
      }

      if (mounted) {
        setState(() { comments = fetchedComments; isLoading = false; });
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
      final insertData = {'post_id': widget.postId, 'student_id': widget.currentUserId, 'comment_text': text};
      if (replyingToCommentId != null) insertData['parent_comment_id'] = replyingToCommentId!;

      await supabase.from("discussion_comments").insert(insertData);

      _commentController.clear();
      _commentFocusNode.unfocus();
      setState(() { replyingToCommentId = null; replyingToName = null; });
      await _fetchComments();
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _startReplying(String commentId, String authorName) {
    setState(() { replyingToCommentId = commentId; replyingToName = authorName; });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() { replyingToCommentId = null; replyingToName = null; });
    _commentFocusNode.unfocus();
  }

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
          padding: EdgeInsets.only(left: leftPadding, bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16, backgroundColor: const Color(0xFFFCE4EC),
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
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(authorName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF111827))),
                          const SizedBox(height: 4),
                          Text(c['comment_text'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),
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
                          GestureDetector(onTap: () => _startReplying(cId, authorName), child: const Text("Reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6B7280)))),
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
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const Divider(height: 30),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)))
                : comments.isEmpty
                    ? const Center(child: Text("No comments yet. Start the conversation!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                    : ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), physics: const BouncingScrollPhysics(), children: _buildCommentTree(null, 0)),
          ),
          Container(
            padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
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
                        GestureDetector(onTap: _cancelReply, child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey))
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController, focusNode: _commentFocusNode, cursorColor: const Color(0xFFC2185B), 
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)), 
                        decoration: InputDecoration(hintText: replyingToName != null ? "Write a reply..." : "Add a comment...", hintStyle: const TextStyle(color: Colors.grey, fontSize: 13), filled: true, fillColor: const Color(0xFFF3F4F6), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: const BoxDecoration(color: Color(0xFFC2185B), shape: BoxShape.circle),
                      child: IconButton(icon: isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: isSending ? null : _sendComment),
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