import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/cloudflare_storage_service.dart';
import '../../chat/screens/direct_chat_screen.dart';

/// Modern 2-second floating toast in English with no system paths
void _showReelsToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(bottom: 36, left: 45, right: 45),
      padding: EdgeInsets.zero,
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: isError
                ? const Color(0xFFE11D48).withValues(alpha: 0.96)
                : const Color(0xFF1E1E2E).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isError
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : const Color(0xFFF494AC).withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: isError ? Colors.white : const Color(0xFFF494AC),
                size: 19,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Instagram-like animated Heart Overlay for double tap
class _InstagramHeartOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  const _InstagramHeartOverlay({super.key, required this.onAnimationComplete});

  @override
  State<_InstagramHeartOverlay> createState() => _InstagramHeartOverlayState();
}

class _InstagramHeartOverlayState extends State<_InstagramHeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_animCtrl);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 65),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_animCtrl);

    _animCtrl.forward().then((_) {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66F494AC),
                      blurRadius: 35,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF494AC),
                  size: 110,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
  DateTime? createdAt;

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
    this.authorName = 'Academy Member',
    this.authorAvatar = '',
    this.createdAt,
  });
}

class StudentReelsScreen extends StatefulWidget {
  final bool isActive;
  final String? targetReelId;
  const StudentReelsScreen({
    super.key,
    this.isActive = true,
    this.targetReelId,
  });

  @override
  State<StudentReelsScreen> createState() => _StudentReelsScreenState();
}

class _StudentReelsScreenState extends State<StudentReelsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  String selectedTab = 'for_you'; // 'for_you' or 'friends'
  List<ReelItemData> allForYouReels = [];
  List<ReelItemData> allFriendsReels = [];
  List<ReelItemData> reels = [];
  int activeIndex = 0;
  final PageController _pageController = PageController();

  final Set<String> _viewedReelIds = {};
  String? _activeHeartReelId;
  int _heartAnimTrigger = 0;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);

  void _handleDoubleTapReel(ReelItemData reel) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeHeartReelId = reel.id;
      _heartAnimTrigger++;
    });

    if (!reel.isLikedByMe) {
      _toggleLikeReel(reel);
    }
  }

  final List<String> categories = [
    '🔥 All',
    '🚀 Explore',
    '📊 Trading',
    '💻 Coding',
    '💡 Crypto',
    '🎓 Educational',
  ];
  String selectedCategory = '🔥 All';

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchReels() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      final currentUserId = user?.id ?? '';

      // ۱. دریافت تمام ریلز‌های منتشرشده از جدول reels
      final res = await supabase
          .from('reels')
          .select('*')
          .eq('is_published', true);

      // ۲. دریافت لایک‌های کاربر به صورت یک‌جا (بچ کوئری سریع و مطمئن بدون خطای RLS)
      Set<String> myLikedReelIds = {};
      if (currentUserId.isNotEmpty) {
        try {
          final myLikes = await supabase
              .from('reel_likes')
              .select('reel_id')
              .eq('user_id', currentUserId);
          myLikedReelIds = (myLikes as List)
              .map((e) => e['reel_id']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet();
        } catch (e) {
          debugPrint('Error fetching user likes batch: $e');
        }

        // ۲.۵. دریافت تمام ویدیوهایی که این کاربر قبلاً دیده تا ویوی تکراری حتی پس از بستن و باز کردن اپ ثبت نشود
        try {
          final myViews = await supabase
              .from('reel_views')
              .select('reel_id')
              .eq('viewer_id', currentUserId);
          final viewedIds = (myViews as List)
              .map((e) => e['reel_id']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet();
          _viewedReelIds.addAll(viewedIds);
        } catch (e) {
          debugPrint('Error fetching user views batch: $e');
        }
      }

      // ۳. دریافت لیست دوستان تایید شده (accepted) از جدول student_friends
      Set<String> friendIds = {};
      if (currentUserId.isNotEmpty) {
        try {
          final friendsRes = await supabase
              .from('student_friends')
              .select('sender_id, receiver_id')
              .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
              .eq('status', 'accepted');
          for (var f in (friendsRes as List)) {
            final s = f['sender_id']?.toString() ?? '';
            final r = f['receiver_id']?.toString() ?? '';
            if (s.isNotEmpty && s != currentUserId) friendIds.add(s);
            if (r.isNotEmpty && r != currentUserId) friendIds.add(r);
          }
        } catch (e) {
          debugPrint('Error fetching friend ids: $e');
        }
      }

      // ۴. دریافت اطلاعات پروفایل سازندگان ویدیو به صورت بچ
      final userIds = (res as List)
          .map((r) => r['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          final profRes = await supabase
              .from('profiles')
              .select('id, first_name, last_name, avatar_url')
              .inFilter('id', userIds);
          for (var p in (profRes as List)) {
            profilesMap[p['id'].toString()] = p;
          }
        } catch (e) {
          debugPrint('Error batch fetching profiles: $e');
        }
      }

      // ۵. الگوریتم اکسپلور (Explore Algorithm) مشابه تیک‌تاک و اینستاگرام با تمرکز بالا بر لایک و کامنت
      double calculateExploreScore(Map<String, dynamic> r) {
        final likes = (r['likes_count'] as num?)?.toDouble() ?? 0.0;
        final comments = (r['comments_count'] as num?)?.toDouble() ?? 0.0;
        final views = (r['views_count'] as num?)?.toDouble() ?? 0.0;

        // ضریب ۵ برای کامنت، ضریب ۳ برای لایک، ضریب ۰.۵ برای بازدید طبق خواسته کاربر
        double score = (comments * 5.0) + (likes * 3.0) + (views * 0.5);

        // امتیاز ویژه محتوای جدید (Recency Boost)
        try {
          final createdAt = DateTime.parse(r['created_at'].toString());
          final hoursAgo = DateTime.now().difference(createdAt).inHours;
          if (hoursAgo < 24) {
            score += 35.0;
          } else if (hoursAgo < 72) {
            score += 20.0;
          } else if (hoursAgo < 168) {
            score += 8.0;
          }
        } catch (_) {}

        return score;
      }

      List<Map<String, dynamic>> rawList =
          List<Map<String, dynamic>>.from(res as List);
      // مرتب‌سازی اکسپلور بر اساس بالاترین تعامل
      rawList.sort(
          (a, b) => calculateExploreScore(b).compareTo(calculateExploreScore(a)));

      List<ReelItemData> loaded = [];

      for (var r in rawList) {
        final id = r['id'].toString();
        final uId = r['user_id'].toString();

        String authorName = 'Academy Member';
        String authorAvatar = '';

        if (profilesMap.containsKey(uId)) {
          final prof = profilesMap[uId]!;
          authorName =
              '${prof['first_name'] ?? ''} ${prof['last_name'] ?? ''}'.trim();
          if (authorName.isEmpty) authorName = 'Academy Member';
          authorAvatar = prof['avatar_url'] ?? '';
        }

        DateTime? createdAt;
        try {
          if (r['created_at'] != null) {
            createdAt = DateTime.parse(r['created_at'].toString());
          }
        } catch (_) {}

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
            likesCount: r['likes_count'] ?? 0,
            commentsCount: r['comments_count'] ?? 0,
            isLikedByMe: myLikedReelIds.contains(id),
            authorName: authorName,
            authorAvatar: authorAvatar,
            createdAt: createdAt,
          ),
        );
      }

      // اگر از طریق دیپ‌لینک، ویدیو خاصی هدف قرار داده شده باشد، آن را در ابتدای لیست می‌گذاریم
      if (widget.targetReelId != null) {
        final targetIndex = loaded.indexWhere(
          (r) => r.id == widget.targetReelId,
        );
        if (targetIndex != -1) {
          final targetReel = loaded.removeAt(targetIndex);
          loaded.insert(0, targetReel);
        }
      }

      allForYouReels = loaded;
      allFriendsReels =
          loaded.where((r) => friendIds.contains(r.userId)).toList();

      if (mounted) {
        setState(() {
          reels =
              (selectedTab == 'friends') ? allFriendsReels : allForYouReels;
          isLoading = false;
        });

        // ثبت بازدید ویدیوی اول در صورت وجود
        if (reels.isNotEmpty && widget.isActive) {
          _recordView(reels.first);
        }
      }
    } catch (e) {
      debugPrint('Error fetching reels: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ثبت بازدید یکتا در جدول اختصاصی reel_views و جدول reels (تنها یک‌بار برای هر کاربر)
  Future<void> _recordView(ReelItemData reel) async {
    final user = supabase.auth.currentUser;
    final currentUserId = user?.id ?? '';

    // ۱. بررسی فوری در کش محلی: اگر این ویدیو قبلاً توسط این کاربر دیده شده، ثبت مجدد نمی‌شود
    if (_viewedReelIds.contains(reel.id)) return;
    _viewedReelIds.add(reel.id);

    if (currentUserId.isEmpty) return;

    try {
      // ۲. بررسی دیتابیس برای اطمینان قطعی از اینکه کاربر قبلاً این ریلز را ندیده باشد
      final existingView = await supabase
          .from('reel_views')
          .select('id')
          .eq('reel_id', reel.id)
          .eq('viewer_id', currentUserId)
          .maybeSingle();

      if (existingView != null) {
        // کاربر قبلاً این ویدیو را دیده؛ ویو نباید اضافه شود
        return;
      }

      // ۳. ثبت رکورد جدید در جدول reel_views
      await supabase.from('reel_views').insert({
        'reel_id': reel.id,
        'viewer_id': currentUserId,
        'viewed_at': DateTime.now().toIso8601String(),
      });

      // ۴. افزایش شمارنده views_count در جدول اصلی reels
      reel.viewsCount += 1;
      await supabase
          .from('reels')
          .update({'views_count': reel.viewsCount})
          .eq('id', reel.id);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error recording unique reel view: $e');
    }
  }

  // لایک یا آن‌لایک ریلز با سینک دوطرفه در جدول‌های reel_likes و reels
  Future<void> _toggleLikeReel(ReelItemData reel) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like reels! ❤️')),
      );
      return;
    }

    final willBeLiked = !reel.isLikedByMe;

    setState(() {
      reel.isLikedByMe = willBeLiked;
      if (willBeLiked) {
        reel.likesCount += 1;
      } else {
        reel.likesCount = (reel.likesCount > 0) ? reel.likesCount - 1 : 0;
      }
    });

    try {
      if (willBeLiked) {
        // ۱. ثبت در جدول reel_likes
        await supabase.from('reel_likes').insert({
          'reel_id': reel.id,
          'user_id': user.id,
          'created_at': DateTime.now().toIso8601String(),
        });

        // ۲. شمارش دقیق و به‌روزرسانی در جدول اصلی reels
        final countRes = await supabase
            .from('reel_likes')
            .select('id')
            .eq('reel_id', reel.id);
        final realLikes = (countRes as List).length;
        reel.likesCount = realLikes;
        await supabase
            .from('reels')
            .update({'likes_count': realLikes})
            .eq('id', reel.id);

        // ۳. ارسال نوتیفیکیشن برای سازنده ریلز
        if (reel.userId != user.id) {
          try {
            final senderProfile = await supabase
                .from('profiles')
                .select('first_name, last_name')
                .eq('id', user.id)
                .maybeSingle();
            final String senderName = (senderProfile != null)
                ? '${senderProfile['first_name'] ?? 'Someone'} ${senderProfile['last_name'] ?? ''}'
                    .trim()
                : 'Someone';

            await supabase.from('user_notifications').insert({
              'user_id': reel.userId,
              'sender_id': user.id,
              'title': 'Liked your Reel ❤️',
              'message':
                  '$senderName liked your educational video: "${reel.title}"',
              'notification_type': 'like',
              'link_url': '/reel/${reel.id}',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
        }
      } else {
        // حذف از reel_likes
        await supabase
            .from('reel_likes')
            .delete()
            .eq('reel_id', reel.id)
            .eq('user_id', user.id);

        // شمارش مجدد و به‌روزرسانی جدول reels
        final countRes = await supabase
            .from('reel_likes')
            .select('id')
            .eq('reel_id', reel.id);
        final realLikes = (countRes as List).length;
        reel.likesCount = realLikes;
        await supabase
            .from('reels')
            .update({'likes_count': realLikes})
            .eq('id', reel.id);
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error toggling reel like: $e');
    }
  }

  // دانلود ویدیو ریلز مانند اینستاگرام و تیک‌تاک و ذخیره مستقیم در گالری گوشی
  Future<void> _downloadReel(ReelItemData reel) async {
    double progress = 0.0;
    StateSetter? setProgressState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          setProgressState = setDialogState;
          return AlertDialog(
            backgroundColor: const Color(0xFF1F2937),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.downloading_rounded,
                    color: primaryPink, size: 28),
                SizedBox(width: 10),
                Text(
                  'Downloading Reel...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  color: primaryPink,
                  backgroundColor: Colors.white12,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                      color: primaryPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      // ۱. دانلود موقت در حافظه موقت (Temporary Directory)
      final tempDir = await getTemporaryDirectory();
      final tempFilePath =
          '${tempDir.path}/reel_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final dio = Dio();
      await dio.download(
        reel.videoUrl,
        tempFilePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && setProgressState != null) {
            setProgressState!(() {
              progress = received / total;
            });
          }
        },
      );

      // بستن دیالوگ درصد دانلود
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // ۲. ذخیره مستقیم و رسمی در گالری گوشی (MediaStore در اندروید / Photos در iOS)
      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putVideo(tempFilePath, album: 'Safi Academy');
      } catch (galErr) {
        debugPrint('Gal album save fallback: $galErr');
        await Gal.putVideo(tempFilePath);
      }

      // پاک‌سازی فایل موقت
      try {
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      // ۳. نمایش پاپ‌آپ شکیل ۲ ثانیه‌ای طبق خواسته کاربر به زبان انگلیسی (بدون کد و پیام سیستمی)
      if (mounted) {
        _showReelsToast(context, 'Video saved to gallery 🎬');
      }
    } catch (e) {
      debugPrint('Error saving reel to gallery: $e');
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        _showReelsToast(context, 'Failed to save video', isError: true);
      }
    }
  }

  // باز کردن پنجره اشتراک‌گذاری و ارسال مستقیم به دوستان
  void _openShareModal(ReelItemData reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReelShareBottomSheet(reel: reel),
    );
  }

  // باز کردن پنجره کامنت‌ها با قابلیت به‌روزرسانی آنی تعداد کامنت‌ها
  void _openReelComments(ReelItemData reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReelCommentsBottomSheet(
        reelId: reel.id,
        onCommentAdded: (newCount) {
          setState(() {
            reel.commentsCount = newCount;
          });
        },
      ),
    );
  }

  void _showUploadReelDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    bool isUploadingFile = false;
    String uploadCategory = 'Explore';

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
                'Upload Educational Reel 🎬',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Reel Title',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // انتخاب دسته‌بندی با اضافه شدن اکسپلور
              DropdownButtonFormField<String>(
                value: uploadCategory,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Explore', child: Text('🌟 Explore')),
                  DropdownMenuItem(
                      value: 'Educational', child: Text('🎓 Educational')),
                  DropdownMenuItem(
                      value: 'Trading', child: Text('📊 Trading')),
                  DropdownMenuItem(
                      value: 'Coding', child: Text('💻 Coding')),
                  DropdownMenuItem(
                      value: 'Motivation', child: Text('🔥 Motivation')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => uploadCategory = val);
                  }
                },
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
                            final user = supabase.auth.currentUser;
                            final uId = user?.id ?? 'guest';
                            final fileName =
                                'reel_${DateTime.now().millisecondsSinceEpoch}_$uId.mp4';
                            final publicUrl = await CloudflareStorageService
                                .instance
                                .upload(
                              bucket: 'safiacademy-media',
                              path: 'reels/$fileName',
                              bytes: bytes,
                              contentType: 'video/mp4',
                            );
                            urlController.text = publicUrl;
                            setModalState(() => isUploadingFile = false);
                          } catch (e) {
                            setModalState(() => isUploadingFile = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Storage Upload Error: $e'),
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
                              ? 'Uploading video to Cloudflare... ⏳'
                              : (urlController.text.isNotEmpty
                                  ? 'Video Uploaded! ✅'
                                  : 'Select Video File from Gallery 🎥'),
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
                  hintText: 'Video URL (or Cloudflare media link)',
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
                            await supabase.from('reels').insert({
                              'user_id': user.id,
                              'title': titleController.text.trim(),
                              'video_url': urlController.text.trim(),
                              'category': uploadCategory,
                              'is_published': true,
                              'likes_count': 0,
                              'comments_count': 0,
                              'views_count': 0,
                              'created_at': DateTime.now().toIso8601String(),
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchReels();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reel published successfully! 🎉',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error uploading reel: $e'),
                                ),
                              );
                            }
                          }
                        },
                  child: const Text(
                    'PUBLISH REEL',
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
          ? const Center(
              child: CircularProgressIndicator(color: primaryPink))
          : Stack(
              children: [
                // اگر تب دوستان خالی بود، پیام مناسب نمایش داده شود
                if (selectedTab == 'friends' && reels.isEmpty)
                  _buildEmptyFriendsState()
                else
                  PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: reels.length,
                    onPageChanged: (index) {
                      setState(() => activeIndex = index);
                      if (index >= 0 && index < reels.length) {
                        _recordView(reels[index]);
                      }
                    },
                    itemBuilder: (context, index) {
                      final reel = reels[index];
                      return _buildReelPage(reel, index);
                    },
                  ),

                // دکمه‌های بالا: دوستان | برای شما (Friends | For You)
                _buildTopTabBar(),
              ],
            ),
    );
  }

  // نوار انتخاب تب بالای صفحه
  Widget _buildTopTabBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // دکمه تب دوستان
              GestureDetector(
                onTap: () {
                  if (selectedTab != 'friends') {
                    setState(() {
                      selectedTab = 'friends';
                      activeIndex = 0;
                      reels = allFriendsReels;
                    });
                    if (reels.isNotEmpty && widget.isActive) {
                      _recordView(reels.first);
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Friends',
                      style: TextStyle(
                        color: selectedTab == 'friends'
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 16,
                        fontWeight: selectedTab == 'friends'
                            ? FontWeight.w900
                            : FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: selectedTab == 'friends'
                            ? primaryPink
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 14,
                width: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: Colors.white24,
              ),
              // دکمه تب برای شما (اکسپلور)
              GestureDetector(
                onTap: () {
                  if (selectedTab != 'for_you') {
                    setState(() {
                      selectedTab = 'for_you';
                      activeIndex = 0;
                      reels = allForYouReels;
                    });
                    if (reels.isNotEmpty && widget.isActive) {
                      _recordView(reels.first);
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'For You',
                      style: TextStyle(
                        color: selectedTab == 'for_you'
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 16,
                        fontWeight: selectedTab == 'for_you'
                            ? FontWeight.w900
                            : FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: selectedTab == 'for_you'
                            ? primaryPink
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // وضعیت خالی بودن تب دوستان
  Widget _buildEmptyFriendsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryPink.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: primaryPink,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Reels from Friends Yet 🤝',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ویدیوهایی که توسط دوستان تایید شده شما ثبت شوند در این بخش نمایش داده خواهند شد.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                setState(() {
                  selectedTab = 'for_you';
                  activeIndex = 0;
                  reels = allForYouReels;
                });
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text(
                'Watch For You (Explore) 🔥',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelPage(ReelItemData reel, int index) {
    return Stack(
      children: [
        // پخش‌کننده واقعی ویدیو ریلز با پشتیبانی از دبل‌تپ و لایک
        Positioned.fill(
          child: ReelVideoPlayerWidget(
            videoUrl: reel.videoUrl,
            thumbnailUrl: reel.thumbnailUrl,
            shouldPlay: widget.isActive && (activeIndex == index),
            onDoubleTap: () => _handleDoubleTapReel(reel),
          ),
        ),

        // سایه گرادینت برای خوانایی
        Positioned.fill(
          child: IgnorePointer(
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
        ),

        // انیمیشن قلب پاپ‌آپ اینستاگرام در مرکز صفحه هنگام دبل‌تپ
        if (_activeHeartReelId == reel.id)
          Center(
            child: _InstagramHeartOverlay(
              key: ValueKey('heart_${reel.id}_$_heartAnimTrigger'),
              onAnimationComplete: () {
                if (mounted) {
                  setState(() {
                    _activeHeartReelId = null;
                  });
                }
              },
            ),
          ),

        // اطلاعات نویسنده و توضیحات در سمت چپ پایین
        Positioned(
          left: 16,
          bottom: 95,
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
                            reel.authorName.isNotEmpty
                                ? reel.authorName[0]
                                : 'A',
                            style: const TextStyle(
                              color: primaryPink,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reel.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        'Message',
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
              if (reel.description != null &&
                  reel.description!.trim().isNotEmpty) ...[
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

        // دکمه‌های تعاملی سمت راست (Like, Comment, Save/Download, Share, Views)
        Positioned(
          right: 16,
          bottom: 110,
          child: Column(
            children: [
              // ۱. لایک
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
                      '${reel.likesCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ۲. کامنت
              GestureDetector(
                onTap: () => _openReelComments(reel),
                child: Column(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reel.commentsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ۳. دانلود ویدیو (مانند تیک‌تاک و اینستاگرام)
              GestureDetector(
                onTap: () => _downloadReel(reel),
                child: const Column(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ۴. اشتراک‌گذاری و ارسال به دوستان
              GestureDetector(
                onTap: () => _openShareModal(reel),
                child: const Column(
                  children: [
                    Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ۵. بازدیدها
              Column(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${reel.viewsCount}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4)
                      ],
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

// پنجره اشتراک‌گذاری ریلز و ارسال مستقیم به دوستان
class _ReelShareBottomSheet extends StatefulWidget {
  final ReelItemData reel;
  const _ReelShareBottomSheet({required this.reel});

  @override
  State<_ReelShareBottomSheet> createState() => _ReelShareBottomSheetState();
}

class _ReelShareBottomSheetState extends State<_ReelShareBottomSheet> {
  final supabase = Supabase.instance.client;
  bool isLoadingFriends = true;
  List<Map<String, dynamic>> friends = [];
  Set<String> sentFriendIds = {};

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoadingFriends = false);
      return;
    }

    try {
      final relations = await supabase
          .from('student_friends')
          .select('sender_id, receiver_id, status')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .eq('status', 'accepted');

      Set<String> friendIds = {};
      for (var r in (relations as List)) {
        final sId = r['sender_id']?.toString() ?? '';
        final rId = r['receiver_id']?.toString() ?? '';
        if (sId.isNotEmpty && sId != user.id) friendIds.add(sId);
        if (rId.isNotEmpty && rId != user.id) friendIds.add(rId);
      }

      if (friendIds.isNotEmpty) {
        final profs = await supabase
            .from('profiles')
            .select('id, first_name, last_name, avatar_url')
            .inFilter('id', friendIds.toList());
        if (mounted) {
          setState(() {
            friends = List<Map<String, dynamic>>.from(profs as List);
            isLoadingFriends = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingFriends = false);
      }
    } catch (e) {
      debugPrint('Error fetching friends for share: $e');
      if (mounted) setState(() => isLoadingFriends = false);
    }
  }

  Future<void> _sendToFriend(Map<String, dynamic> friend) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final friendId = friend['id']?.toString() ?? '';
    if (friendId.isEmpty || sentFriendIds.contains(friendId)) return;

    setState(() {
      sentFriendIds.add(friendId);
    });

    try {
      // ارسال در چت مستقیم (direct_messages)
      await supabase.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': friendId,
        'message_text':
            '🎬 [Reel] ${widget.reel.title}\nhttps://www.safiacademy.org/en/feed/reels?id=${widget.reel.id}',
        'attachment_url': widget.reel.videoUrl,
        'attachment_type': 'reel',
        'is_delivered': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      // ارسال نوتیفیکیشن درون‌برنامه‌ای به دوست
      try {
        final myProfile = await supabase
            .from('profiles')
            .select('first_name, last_name')
            .eq('id', user.id)
            .maybeSingle();
        final myName = (myProfile != null)
            ? '${myProfile['first_name'] ?? 'Friend'} ${myProfile['last_name'] ?? ''}'
                .trim()
            : 'A friend';

        await supabase.from('user_notifications').insert({
          'user_id': friendId,
          'sender_id': user.id,
          'title': '🎬 New Reel Shared',
          'message': '$myName shared a reel with you: "${widget.reel.title}"',
          'notification_type': 'direct_message',
          'link_url': '/chat/${user.id}',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (mounted) {
        _showReelsToast(context, 'Video sent to friend 🚀');
      }
    } catch (e) {
      debugPrint('Error sending reel to friend: $e');
      if (mounted) {
        setState(() {
          sentFriendIds.remove(friendId);
        });
        _showReelsToast(context, 'Failed to send video', isError: true);
      }
    }
  }

  void _copyReelLink() {
    // تنها لینک ویدیو بدون هیچ متن اضافی طبق خواسته کاربر:
    final pureLink = 'https://www.safiacademy.org/en/feed/reels?id=${widget.reel.id}';
    Clipboard.setData(ClipboardData(text: pureLink));
    Navigator.pop(context);
    _showReelsToast(context, 'Link copied to clipboard 📋');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share Reel 🚀',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اشتراک‌گذاری ویدیو یا ارسال مستقیم به دوستان در پیام‌رسان آکادمی',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),

          // دکمه کاپی لینک ویدیو
          GestureDetector(
            onTap: _copyReelLink,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: lightPinkBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryPink.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: primaryPink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Copy Reel Link',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'https://www.safiacademy.org/en/feed/reels?id=...',
                          style: TextStyle(
                            color: primaryPink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.copy_rounded, color: primaryPink, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Send to Friends 💬',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),

          // لیست دوستان
          SizedBox(
            height: 190,
            child: isLoadingFriends
                ? const Center(
                    child: CircularProgressIndicator(color: primaryPink),
                  )
                : friends.isEmpty
                    ? Center(
                        child: Text(
                          'You haven\'t added any friends yet.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final friendId =
                              friend['id']?.toString() ?? '';
                          final isSent = sentFriendIds.contains(friendId);
                          final name =
                              '${friend['first_name'] ?? ''} ${friend['last_name'] ?? ''}'
                                  .trim();
                          final avatar = friend['avatar_url'] ?? '';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: lightPinkBg,
                              backgroundImage: avatar.isNotEmpty
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar.isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name[0] : 'F',
                                      style: const TextStyle(
                                        color: primaryPink,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name.isNotEmpty ? name : 'Academy Student',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSent
                                    ? Colors.green
                                    : primaryPink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isSent
                                  ? null
                                  : () => _sendToFriend(friend),
                              child: Text(
                                isSent ? 'Sent ✅' : 'Send',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// کامنت‌های ریلز با ثبت در جدول reel_comments و به‌روزرسانی جدول reels
class _ReelCommentsBottomSheet extends StatefulWidget {
  final String reelId;
  final ValueChanged<int>? onCommentAdded;

  const _ReelCommentsBottomSheet({
    required this.reelId,
    this.onCommentAdded,
  });

  @override
  State<_ReelCommentsBottomSheet> createState() =>
      _ReelCommentsBottomSheetState();
}

class _ReelCommentsBottomSheetState extends State<_ReelCommentsBottomSheet> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final res = await supabase
          .from('reel_comments')
          .select('*, profiles:user_id(first_name, last_name, avatar_url)')
          .eq('reel_id', widget.reelId)
          .order('created_at', ascending: true);

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
      // ۱. ثبت کامنت در جدول اختصاصی reel_comments
      await supabase.from('reel_comments').insert({
        'reel_id': widget.reelId,
        'user_id': user.id,
        'comment_text': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      // ۲. شمارش مجدد کامنت‌های واقعی و به‌روزرسانی جدول reels
      final countRes = await supabase
          .from('reel_comments')
          .select('id')
          .eq('reel_id', widget.reelId);
      final realCommentsCount = (countRes as List).length;

      await supabase
          .from('reels')
          .update({'comments_count': realCommentsCount})
          .eq('id', widget.reelId);

      widget.onCommentAdded?.call(realCommentsCount);

      // ۳. ثبت نوتیفیکیشن کامنت ریلز
      try {
        final reelData = await supabase
            .from('reels')
            .select('user_id, title')
            .eq('id', widget.reelId)
            .maybeSingle();

        if (reelData != null) {
          final authorId = reelData['user_id']?.toString() ?? '';
          final reelTitle = reelData['title'] ?? 'your reel';
          if (authorId.isNotEmpty && authorId != user.id) {
            final senderProfile = await supabase
                .from('profiles')
                .select('first_name, last_name')
                .eq('id', user.id)
                .maybeSingle();
            final String senderName = (senderProfile != null)
                ? '${senderProfile['first_name'] ?? 'Someone'} ${senderProfile['last_name'] ?? ''}'
                    .trim()
                : 'Someone';

            await supabase.from('user_notifications').insert({
              'user_id': authorId,
              'sender_id': user.id,
              'title': '💬 Comment on your Reel',
              'message': '$senderName commented on "$reelTitle": "$text"',
              'notification_type': 'comment',
              'link_url': '/reel/${widget.reelId}',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      } catch (_) {}

      _fetchComments();
    } catch (_) {}
  }

  void _replyToUser(String username) {
    setState(() {
      _controller.text = '@$username ${_controller.text}';
    });
    _focusNode.requestFocus();
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
              'Comments 💬',
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
                        color: Color(0xFFF494AC),
                      ),
                    )
                  : comments.isEmpty
                      ? const Center(
                          child: Text(
                            'Be the first to comment!',
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
                            final profile = c['profiles'];
                            final String authorName = (profile != null)
                                ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                                    .trim()
                                : 'Academy Student';
                            final String avatarUrl = (profile != null)
                                ? (profile['avatar_url'] ?? '')
                                : '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFFAF4F6),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        authorName.isNotEmpty
                                            ? authorName[0]
                                            : 'S',
                                        style: const TextStyle(
                                          color: Color(0xFFF494AC),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                authorName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  c['comment_text'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              trailing: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _replyToUser(authorName),
                                child: const Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: Color(0xFFF494AC),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
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
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
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
                      color: Color(0xFFF494AC),
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
  final VoidCallback? onDoubleTap;

  const ReelVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.shouldPlay,
    this.onDoubleTap,
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
      debugPrint('Error initializing video player: $e');
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
            if (widget.thumbnailUrl != null &&
                widget.thumbnailUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            const CircularProgressIndicator(
              color: Color(0xFFF494AC),
              strokeWidth: 3,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_controller.value.aspectRatio > 1.1)
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  if (_controller.value.aspectRatio > 1.1)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.75),
                      ),
                    ),
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ],
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
