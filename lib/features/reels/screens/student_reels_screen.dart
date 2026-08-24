import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../chat/screens/direct_chat_screen.dart';

class ReelItemData {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String title;
  final String? description;
  final String category;
  int viewsCount;
  int likesCount;
  int commentsCount;
  bool isLikedByMe;
  String authorName;
  String authorAvatar;

  ReelItemData({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    this.description,
    required this.category,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.authorName = "Academy Member",
    this.authorAvatar = "",
  });
}

class StudentReelsScreen extends StatefulWidget {
  final bool isActive;
  const StudentReelsScreen({super.key, this.isActive = true});

  @override
  State<StudentReelsScreen> createState() => _StudentReelsScreenState();
}

class _StudentReelsScreenState extends State<StudentReelsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ReelItemData> reels = [];
  int activeIndex = 0;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);

  final List<String> categories = [
    "🔥 All",
    "📊 Trading",
    "💻 Coding",
    "💡 Crypto",
  ];
  String selectedCategory = "🔥 All";

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  Future<void> _fetchReels() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      final currentUserId = user?.id ?? '';

      // دریافت ریلزها از جدول reels در Supabase
      var query = supabase.from("reels").select("*").eq("is_published", true);

      final res = await query.order("created_at", ascending: false);
      List<ReelItemData> loaded = [];

      for (var r in (res as List)) {
        final id = r['id'].toString();
        final uId = r['user_id'].toString();

        String authorName = "Academy Member";
        String authorAvatar = "";

        try {
          final profileRes = await supabase
              .from("profiles")
              .select("first_name, last_name, avatar_url")
              .eq("id", uId)
              .maybeSingle();

          if (profileRes != null) {
            authorName =
                "${profileRes['first_name'] ?? ''} ${profileRes['last_name'] ?? ''}"
                    .trim();
            if (authorName.isEmpty) authorName = "Academy Member";
            authorAvatar = profileRes['avatar_url'] ?? '';
          }
        } catch (_) {}

        int likesCount = r['likes_count'] ?? 0;
        bool isLiked = false;

        if (currentUserId.isNotEmpty) {
          try {
            final likeCheck = await supabase
                .from("reel_likes")
                .select("id")
                .eq("reel_id", id)
                .eq("user_id", currentUserId)
                .maybeSingle();
            isLiked = likeCheck != null;
          } catch (_) {}
        }

        loaded.add(
          ReelItemData(
            id: id,
            userId: uId,
            videoUrl: r['video_url'] ?? '',
            thumbnailUrl: r['thumbnail_url'],
            title: r['title'] ?? 'Educational Reel',
            description: r['description'],
            category: r['category'] ?? 'Educational',
            viewsCount: r['views_count'] ?? 0,
            likesCount: likesCount,
            commentsCount: r['comments_count'] ?? 0,
            isLikedByMe: isLiked,
            authorName: authorName,
            authorAvatar: authorAvatar,
          ),
        );
      }

      if (mounted) {
        setState(() {
          reels = loaded;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reels: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleLikeReel(ReelItemData reel) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      if (reel.isLikedByMe) {
        reel.isLikedByMe = false;
        reel.likesCount = (reel.likesCount > 0) ? reel.likesCount - 1 : 0;
      } else {
        reel.isLikedByMe = true;
        reel.likesCount += 1;
      }
    });

    try {
      if (!reel.isLikedByMe) {
        await supabase
            .from("reel_likes")
            .delete()
            .eq("reel_id", reel.id)
            .eq("user_id", user.id);
      } else {
        await supabase.from("reel_likes").insert({
          'reel_id': reel.id,
          'user_id': user.id,
        });
      }
    } catch (e) {
      debugPrint("Error toggling reel like: $e");
    }
  }

  void _openReelComments(ReelItemData reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReelCommentsBottomSheet(reelId: reel.id),
    );
  }

  void _showUploadReelDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    bool isUploadingFile = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload Educational Reel 🎬",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: "Reel Title",
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: isUploadingFile
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final XFile? video = await picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        if (video != null) {
                          setModalState(() => isUploadingFile = true);
                          try {
                            final bytes = await video.readAsBytes();
                            final fileName =
                                "reel_${DateTime.now().millisecondsSinceEpoch}.mp4";
                            await supabase.storage
                                .from("reels")
                                .uploadBinary(
                                  fileName,
                                  bytes,
                                  fileOptions: const FileOptions(
                                    contentType: 'video/mp4',
                                  ),
                                );
                            final publicUrl = supabase.storage
                                .from("reels")
                                .getPublicUrl(fileName);
                            urlController.text = publicUrl;
                            setModalState(() => isUploadingFile = false);
                          } catch (e) {
                            setModalState(() => isUploadingFile = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Storage Upload Error: $e"),
                                ),
                              );
                            }
                          }
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: primaryPink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryPink.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.video_library_rounded,
                        color: primaryPink,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isUploadingFile
                              ? "Uploading video to Supabase... ⏳"
                              : (urlController.text.isNotEmpty
                                    ? "Video Uploaded! ✅"
                                    : "Select Video File from Gallery 🎥"),
                          style: const TextStyle(
                            color: primaryPink,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (isUploadingFile)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: primaryPink,
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: "Video URL (or selected file path)",
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isUploadingFile
                      ? null
                      : () async {
                          final user = supabase.auth.currentUser;
                          if (user == null ||
                              titleController.text.isEmpty ||
                              urlController.text.isEmpty) {
                            return;
                          }

                          try {
                            await supabase.from("reels").insert({
                              'user_id': user.id,
                              'title': titleController.text.trim(),
                              'video_url': urlController.text.trim(),
                              'category': 'Educational',
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchReels();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Reel published successfully! 🎉",
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error uploading reel: $e"),
                                ),
                              );
                            }
                          }
                        },
                  child: const Text(
                    "PUBLISH REEL",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : Stack(
              children: [
                // صفحه اسکرول عمودی ریلز‌ها (TikTok Style Vertical Scroll)
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: reels.length,
                  onPageChanged: (index) {
                    setState(() => activeIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final reel = reels[index];
                    return _buildReelPage(reel, index);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildReelPage(ReelItemData reel, int index) {
    return Stack(
      children: [
        // پخش‌کننده واقعی ویدیو ریلز به جای تصویر ثابت
        Positioned.fill(
          child: ReelVideoPlayerWidget(
            videoUrl: reel.videoUrl,
            thumbnailUrl: reel.thumbnailUrl,
            shouldPlay: widget.isActive && (activeIndex == index),
          ),
        ),

        // سایه گرادینت برای خوانایی
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),

        // اطلاعات نویسنده و توضیحات در سمت چپ پایین
        Positioned(
          left: 16,
          bottom: 40,
          right: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: lightPinkBg,
                    backgroundImage: reel.authorAvatar.isNotEmpty
                        ? NetworkImage(reel.authorAvatar)
                        : null,
                    child: reel.authorAvatar.isEmpty
                        ? Text(
                            reel.authorName[0],
                            style: const TextStyle(
                              color: primaryPink,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    reel.authorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            peerId: reel.userId,
                            peerName: reel.authorName,
                            peerAvatar: reel.authorAvatar,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Message",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reel.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (reel.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  reel.description!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // دکمه‌های تعاملی سمت راست (Like, Comment, Share, Views)
        Positioned(
          right: 16,
          bottom: 60,
          child: Column(
            children: [
              // لایک
              GestureDetector(
                onTap: () => _toggleLikeReel(reel),
                child: Column(
                  children: [
                    Icon(
                      reel.isLikedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: reel.isLikedByMe ? primaryPink : Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${reel.likesCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // کامنت
              GestureDetector(
                onTap: () => _openReelComments(reel),
                child: Column(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${reel.commentsCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // بازدیدها
              Column(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${reel.viewsCount}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelCommentsBottomSheet extends StatefulWidget {
  final String reelId;
  const _ReelCommentsBottomSheet({required this.reelId});

  @override
  State<_ReelCommentsBottomSheet> createState() =>
      _ReelCommentsBottomSheetState();
}

class _ReelCommentsBottomSheetState extends State<_ReelCommentsBottomSheet> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final res = await supabase
          .from("reel_comments")
          .select("*")
          .eq("reel_id", widget.reelId)
          .order("created_at", ascending: true);

      if (mounted) {
        setState(() {
          comments = List<Map<String, dynamic>>.from(res as List);
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from("reel_comments").insert({
        'reel_id': widget.reelId,
        'user_id': user.id,
        'comment_text': text,
      });

      _fetchComments();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Comments 💬",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const Divider(),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFC2185B),
                      ),
                    )
                  : comments.isEmpty
                  ? const Center(
                      child: Text(
                        "Be the first to comment!",
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFCE4EC),
                            child: Icon(Icons.person, color: Color(0xFFC2185B)),
                          ),
                          title: Text(
                            c['comment_text'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
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
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFFC2185B),
                    ),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReelVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool shouldPlay;

  const ReelVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.shouldPlay,
  });

  @override
  State<ReelVideoPlayerWidget> createState() => _ReelVideoPlayerWidgetState();
}

class _ReelVideoPlayerWidgetState extends State<ReelVideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showPlayPauseIcon = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller.initialize();
      _controller.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.shouldPlay) {
          _controller.play();
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing video player: $e");
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized) return;
    if (widget.shouldPlay != oldWidget.shouldPlay) {
      if (widget.shouldPlay) {
        _controller.play();
        setState(() {
          _isPlaying = true;
        });
      } else {
        _controller.pause();
        _controller.seekTo(Duration.zero);
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
      _showPlayPauseIcon = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            const CircularProgressIndicator(
              color: Color(0xFFC2185B),
              strokeWidth: 3,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (_showPlayPauseIcon)
            AnimatedOpacity(
              opacity: _showPlayPauseIcon ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
