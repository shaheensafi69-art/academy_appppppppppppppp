import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/auth_required_modal.dart';
import '../../../core/widgets/fast_cached_image.dart';
import '../../chat/screens/direct_chat_screen.dart';
import '../screens/user_profile_screen.dart';
import 'feed_comments_sheet.dart';

class FeedPostItem {
  final String id;
  final String studentId;
  final String rawTitle;
  final String content;
  final String? imageUrl;
  final String createdAt;
  String authorName;
  String authorAvatar;
  int likesCount;
  bool isLikedByMe;
  int commentsCount;

  String moodTag;
  String cleanTitle;

  FeedPostItem({
    required this.id,
    required this.studentId,
    required this.rawTitle,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.authorName = "Academy Student",
    this.authorAvatar = "",
    this.likesCount = 0,
    this.isLikedByMe = false,
    this.commentsCount = 0,
  })  : moodTag = _extractMood(rawTitle),
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

  factory FeedPostItem.fromJson(
    Map<String, dynamic> json, {
    String name = "Academy Student",
    String avatar = "",
    int likes = 0,
    bool liked = false,
    int comments = 0,
  }) {
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

/// Modular, self-contained Feed Post Card widget.
/// Manages its own local like state to avoid rebuilding the entire feed list on interaction.
class FeedPostCard extends StatefulWidget {
  final FeedPostItem post;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onCommentsUpdated;

  const FeedPostCard({
    super.key,
    required this.post,
    this.onDelete,
    this.onEdit,
    this.onCommentsUpdated,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  final supabase = Supabase.instance.client;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  late bool isLiked;
  late int likesCount;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLikedByMe;
    likesCount = widget.post.likesCount;
  }

  @override
  void didUpdateWidget(covariant FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isLikedByMe != widget.post.isLikedByMe ||
        oldWidget.post.likesCount != widget.post.likesCount) {
      isLiked = widget.post.isLikedByMe;
      likesCount = widget.post.likesCount;
    }
  }

  Future<void> _toggleLike() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      AuthRequiredModal.show(context, actionName: "like posts");
      return;
    }

    final willLike = !isLiked;
    setState(() {
      isLiked = willLike;
      likesCount += willLike ? 1 : -1;
      if (likesCount < 0) likesCount = 0;
      widget.post.isLikedByMe = isLiked;
      widget.post.likesCount = likesCount;
    });

    try {
      if (!willLike) {
        await supabase
            .from("discussion_likes")
            .delete()
            .eq("post_id", widget.post.id)
            .eq("student_id", user.id);
      } else {
        await supabase.from("discussion_likes").insert({
          "post_id": widget.post.id,
          "student_id": user.id,
        });

        if (widget.post.studentId != user.id) {
          try {
            final senderProfile = await supabase
                .from("profiles")
                .select("first_name, last_name")
                .eq("id", user.id)
                .maybeSingle();
            final String senderName = (senderProfile != null)
                ? "${senderProfile['first_name'] ?? 'Someone'} ${senderProfile['last_name'] ?? ''}"
                    .trim()
                : 'Someone';

            await supabase.from("user_notifications").insert({
              'user_id': widget.post.studentId,
              'sender_id': user.id,
              'title': "Liked your post ❤️",
              'message':
                  "$senderName liked your post: \"${widget.post.cleanTitle}\"",
              'notification_type': "like",
              'link_url': "/post/${widget.post.id}",
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Error toggling like: $e");
    }
  }

  void _sharePost() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      AuthRequiredModal.show(context, actionName: "share posts");
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Post link ready to share: "${widget.post.cleanTitle}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  void _openComments() {
    FeedCommentsSheet.show(
      context,
      postId: widget.post.id,
      currentUserId: supabase.auth.currentUser?.id ?? '',
    ).then((_) {
      widget.onCommentsUpdated?.call();
    });
  }

  void _showPostActionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: primaryPink),
              title: const Text(
                "Edit Post",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text(
                "Delete Post",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final currentUserId = supabase.auth.currentUser?.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سربرگ کاربر
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FastCircleAvatar(
                  imageUrl: post.authorAvatar,
                  radius: 20,
                  fallbackText: post.authorName.isNotEmpty
                      ? post.authorName[0]
                      : 'U',
                  border: Border.all(
                    color: primaryPink.withOpacity(0.2),
                    width: 2,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: post.studentId),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserProfileScreen(userId: post.studentId),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.public, color: textGrey, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              post.createdAt.isNotEmpty
                                  ? post.createdAt.split('T')[0]
                                  : '',
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (currentUserId != null && currentUserId != post.studentId)
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: primaryPink,
                      size: 20,
                    ),
                    tooltip: "Message Author",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            peerId: post.studentId,
                            peerName: post.authorName,
                            peerAvatar: post.authorAvatar,
                          ),
                        ),
                      );
                    },
                  ),
                if (currentUserId == post.studentId)
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, color: textGrey),
                    onPressed: _showPostActionMenu,
                  ),
              ],
            ),
          ),

          // تگ مود
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
                style: const TextStyle(
                  color: primaryPink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // عنوان و محتوای متن
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.cleanTitle.isNotEmpty) ...[
                  Text(
                    post.cleanTitle,
                    style: const TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  post.content,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // عکس پست با FastCachedImage (کش شده و لود لحظه‌ای)
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: FastCachedImage(
                    imageUrl: post.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 1080,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          // نوار آمار لایک و کامنت
          if (likesCount > 0 || post.commentsCount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (likesCount > 0)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.thumb_up_rounded,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$likesCount",
                          style: const TextStyle(color: textGrey, fontSize: 12),
                        ),
                      ],
                    )
                  else
                    const SizedBox(),
                  if (post.commentsCount > 0)
                    Text(
                      "${post.commentsCount} comments",
                      style: const TextStyle(color: textGrey, fontSize: 12),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(color: cardBorder, height: 24),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(color: cardBorder, height: 24),
            ),
          ],

          // دکمه‌های تعاملی
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLiked
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            color: isLiked ? primaryPink : textGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Like",
                            style: TextStyle(
                              color: isLiked ? primaryPink : textGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _openComments,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: textGrey,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Comment",
                            style: TextStyle(
                              color: textGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _sharePost,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            color: textGrey,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Share",
                            style: TextStyle(
                              color: textGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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
}
