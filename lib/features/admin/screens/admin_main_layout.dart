import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت صفحات پنل ادمین
import 'admin_dashboard_screen.dart';
import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'courses_screen.dart';
import 'classes_screen.dart';
import 'finance_screen.dart';
import 'awards_screen.dart';
import 'announcements_screen.dart';
import 'live_classes_screen.dart';
import 'admin_support_requests_screen.dart';
import 'settings_screen.dart';
import 'reseller_sync_screen.dart';

import '../../feed/screens/feed_viewer_screen.dart';
import '../../feed/screens/friends_viewer_screen.dart';
import '../../feed/screens/create_post_screen.dart';
import '../../feed/screens/user_profile_screen.dart';
import '../../feed/screens/reels_viewer_screen.dart';
import '../../feed/screens/upload_reel_screen.dart';

import '../../../core/services/auth_helper.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../core/localization/l10n_extensions.dart';
import '../../dashboard/screens/student_main_layout.dart';
import '../../teacher/screens/teacher_main_layout.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isMenuOpen = false;
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);

  final List<Widget?> _cachedScreens = List.filled(17, null);

  Widget _createScreen(int index) {
    switch (index) {
      case 0:
        return const AdminDashboardScreen();
      case 1:
        return const ManageStudentsScreen();
      case 2:
        return const ManageTeachersScreen();
      case 3:
        return const CoursesScreen();
      case 4:
        return const ClassesScreen();
      case 5:
        return const FinanceScreen();
      case 6:
        return const AwardsScreen();
      case 7:
        return const AnnouncementsScreen();
      case 8:
        return const LiveClassesScreen();
      case 9:
        return const AdminSupportRequestsScreen();
      case 10:
        return const AdminSettingsScreen();
      case 11:
        return CreatePostScreen(
          onPostSuccess: () => setState(() => _currentIndex = 12),
          onCancel: () => setState(() => _currentIndex = 12),
        );
      case 12:
        return const StudentFeedScreen();
      case 13:
        return const StudentFriendsScreen();
      case 14:
        return UserProfileScreen(
          onExit: () => setState(() => _currentIndex = 0),
        );
      case 15:
        return StudentReelsScreen(isActive: _currentIndex == 15);
      case 16:
        return const ResellerSyncScreen();
      default:
        return const AdminDashboardScreen();
    }
  }

  List<Widget> get _screens {
    return List.generate(17, (i) {
      if (i == _currentIndex) {
        if (i == 15) {
          _cachedScreens[i] = const StudentReelsScreen(isActive: true);
        } else {
          _cachedScreens[i] ??= _createScreen(i);
        }
      } else if (i == 15 && _cachedScreens[15] != null) {
        _cachedScreens[15] = const StudentReelsScreen(isActive: false);
      }
      return _cachedScreens[i] ?? const SizedBox.shrink();
    });
  }

  final List<Map<String, dynamic>> _menuItems = [
    {"icon": Icons.dashboard_rounded, "index": 0, "color": primaryPink},
    {
      "icon": Icons.school_rounded,
      "index": 1,
      "color": const Color(0xFF00897B),
    },
    {
      "icon": Icons.psychology_rounded,
      "index": 2,
      "color": const Color(0xFF3949AB),
    },
    {
      "icon": Icons.menu_book_rounded,
      "index": 3,
      "color": const Color(0xFF7B1FA2),
    },
    {"icon": Icons.class_rounded, "index": 4, "color": const Color(0xFF00ACC1)},
    {
      "icon": Icons.payments_rounded,
      "index": 5,
      "color": const Color(0xFF2E7D32),
    },
    {
      "icon": Icons.emoji_events_rounded,
      "index": 6,
      "color": const Color(0xFFFFA000),
    },
    {
      "icon": Icons.campaign_rounded,
      "index": 7,
      "color": const Color(0xFFFB8C00),
    },
    {
      "icon": Icons.live_tv_rounded,
      "index": 8,
      "color": const Color(0xFFE53935),
    },
    {
      "icon": Icons.dynamic_feed_rounded,
      "index": 12,
      "color": const Color(0xFFD81B60),
    },
    {"icon": Icons.headset_mic_rounded, "index": 9, "color": primaryPink},
    {"icon": Icons.settings_rounded, "index": 10, "color": textGrey},
    {"icon": Icons.sync_rounded, "index": 16, "color": const Color(0xFF8E24AA)},
  ];

  String _getMenuItemName(BuildContext context, int index) {
    switch (index) {
      case 0:
        return context.l10n.overview;
      case 1:
        return context.l10n.students;
      case 2:
        return context.l10n.teachers;
      case 3:
        return context.l10n.courses;
      case 4:
        return context.l10n.classes;
      case 5:
        return context.l10n.finance;
      case 6:
        return context.l10n.achievements;
      case 7:
        return context.l10n.announcements;
      case 8:
        return context.l10n.liveStudio;
      case 9:
        return context.l10n.supportRequests;
      case 10:
        return context.l10n.settings;
      case 12:
        return context.l10n.feed;
      case 13:
        return context.l10n.friends;
      case 14:
        return context.l10n.profile;
      case 15:
        return context.l10n.reels;
      case 16:
        return 'همگام‌سازی ریسیلر (Edge Function)';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await supabase
          .from('profiles')
          .select('first_name, last_name, avatar_url, role')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null &&
          (profile['role'] == 'admin' || profile['role'] == 'super_admin')) {
        if (!mounted) return;
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      } else if (profile != null) {
        if (!mounted) return;
        final role = profile['role']?.toString() ?? 'student';
        Widget target = const StudentMainLayout();
        if (role == 'teacher') {
          target = const TeacherMainLayout();
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => target),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Admin access check non-fatal error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    await AuthHelper.logout(context);
  }

  bool get _isInSocialSection =>
      _currentIndex == 11 ||
      _currentIndex == 12 ||
      _currentIndex == 14 ||
      _currentIndex == 15;

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label,
    bool isWide,
  ) {
    final isSelected = _currentIndex == index;
    final isExpanded = MediaQuery.of(context).size.width >= 1024;

    if (!isExpanded) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryPink.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: primaryPink.withValues(alpha: 0.4), width: 1.5)
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected ? primaryPink : textGrey,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryPink.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          icon,
          color: isSelected ? primaryPink : textGrey,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryPink : textDark,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
        onTap: () => setState(() => _currentIndex = index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: primaryPink,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.adminInitializing,
                style: const TextStyle(
                  color: primaryPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 600;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final contentBottomPadding = bottomPadding > 0 ? bottomPadding + 85 : 85.0;

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Row(
          children: [
            Container(
              width: screenWidth >= 1024 ? 240 : 80,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/logo-without-b.png',
                    height: 40,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.school, color: primaryPink, size: 32),
                  ),
                  const SizedBox(height: 16),
                  _buildSidebarCreateButton(screenWidth >= 1024),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        _buildSidebarItem(
                          0,
                          Icons.dashboard_rounded,
                          context.l10n.overview,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          1,
                          Icons.school_rounded,
                          context.l10n.students,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          2,
                          Icons.psychology_rounded,
                          context.l10n.teachers,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          3,
                          Icons.menu_book_rounded,
                          context.l10n.courses,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          4,
                          Icons.class_rounded,
                          context.l10n.classes,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          5,
                          Icons.attach_money_rounded,
                          context.l10n.finance,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          6,
                          Icons.emoji_events_rounded,
                          context.l10n.achievements,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          7,
                          Icons.campaign_rounded,
                          context.l10n.announcements,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          8,
                          Icons.podcasts_rounded,
                          context.l10n.liveStudio,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          9,
                          Icons.support_agent_rounded,
                          context.l10n.supportRequests,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          10,
                          Icons.settings_rounded,
                          context.l10n.settings,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          12,
                          Icons.dynamic_feed_rounded,
                          context.l10n.feed,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          15,
                          Icons.video_library_rounded,
                          context.l10n.reels,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          13,
                          Icons.people_alt_rounded,
                          context.l10n.friends,
                          isWideScreen,
                        ),
                        _buildSidebarItem(
                          14,
                          Icons.person_rounded,
                          context.l10n.profile,
                          isWideScreen,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: _logout,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ],
        ),
      );
    }

    final bool isReels = _currentIndex == 15;
    final bool isCreatePost = _currentIndex == 11;
    SystemUiHelper.setSystemStyle(isReels: isReels);

    return Scaffold(
      backgroundColor: surfaceWhite,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: (isReels || _isInSocialSection || isCreatePost)
                    ? 0
                    : (MediaQuery.of(context).padding.top + 8),
                bottom: (_isInSocialSection || isCreatePost) ? 0 : contentBottomPadding,
              ),
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ),
          if (!isCreatePost)
            Positioned(
              bottom: bottomPadding > 0 ? bottomPadding + 4 : 12.0,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildModernBottomNav(),
                ),
              ),
            ),
          if (_isMenuOpen) Positioned.fill(child: _buildModernFullScreenMenu()),
        ],
      ),
    );
  }

  Widget _buildSidebarCreateButton(bool isExpanded) {
    final buttonWidget = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: isExpanded ? double.infinity : 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryPink, Color(0xFFE91E63)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryPink.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showCreateOptionsModal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 8),
                Text(
                  context.l10n.createPost,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!isExpanded) {
      return Tooltip(
        message: context.l10n.createPost,
        preferBelow: false,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }

  void _showCreateOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.createNewContent,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: lightPinkBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.video_library_rounded,
                    color: primaryPink,
                    size: 24,
                  ),
                ),
                title: Text(
                  "${context.l10n.reels} 🎬",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                subtitle: Text(
                  context.l10n.shareReelSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadReelScreen()),
                  );
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: lightPinkBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.article_rounded,
                    color: primaryPink,
                    size: 24,
                  ),
                ),
                title: Text(
                  context.l10n.createFeedPost,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                subtitle: Text(
                  context.l10n.sharePostSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 11); // Create Post index
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernBottomNav() {
    final bool isReels = _currentIndex == 15;
    if (_isInSocialSection) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildNavTab(
                12,
                context.l10n.feed,
                Icons.dynamic_feed_rounded,
                color: primaryPink,
              ),
            ),
            Expanded(
              child: _buildNavTab(
                15,
                context.l10n.reels,
                Icons.video_library_rounded,
                color: primaryPink,
              ),
            ),
            // دکمه وسط (+)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showCreateOptionsModal,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isReels ? Colors.white : primaryPink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: isReels ? Colors.black : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildNavTab(
                13,
                context.l10n.friends,
                Icons.people_alt_rounded,
                color: primaryPink,
              ),
            ),
            Expanded(
              child: _buildNavTab(
                14,
                context.l10n.profile,
                Icons.person_rounded,
                color: primaryPink,
              ),
            ),
          ],
        ),
      );
    }

    // نوار پایین برای بخش مدیریت ادمین (Admin Nav)
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: isReels
                ? Colors.black.withValues(alpha: 0.88)
                : surfaceWhite.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isReels
                  ? Colors.white12
                  : primaryPink.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildNavTab(
                  0,
                  context.l10n.overview,
                  Icons.dashboard_rounded,
                  color: primaryPink,
                ),
              ),
              Expanded(
                child: _buildNavTab(
                  1,
                  context.l10n.students,
                  Icons.school_rounded,
                  color: const Color(0xFF00897B),
                ),
              ),
              // دکمه پشتیبانی
              Expanded(
                child: _buildNavTab(
                  9,
                  context.l10n.support,
                  Icons.headset_mic_rounded,
                  color: const Color(0xFFE53935),
                ),
              ),
              Expanded(
                child: _buildNavTab(
                  12,
                  context.l10n.feed,
                  Icons.dynamic_feed_rounded,
                  color: primaryPink,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isMenuOpen = true),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _isMenuOpen ? lightPinkBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: primaryPink,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.l10n.menu,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: primaryPink,
                            letterSpacing: 0.8,
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
      ),
    );
  }

  Widget _buildNavTab(
    int index,
    String title,
    IconData icon, {
    required Color color,
  }) {
    bool isActive = _currentIndex == index && !_isMenuOpen;
    bool isReelsActive = _currentIndex == 15;

    Color activeBgColor = isReelsActive
        ? Colors.white12
        : color.withValues(alpha: 0.15);
    Color activeIconText = isReelsActive ? Colors.white : color;
    Color inactiveIconText = isReelsActive ? Colors.white54 : textGrey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _isMenuOpen = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? activeIconText : inactiveIconText,
              size: isActive ? 22 : 19,
            ),
            const SizedBox(height: 2),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isActive ? activeIconText : inactiveIconText,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFullScreenMenu() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
              child: Container(color: surfaceWhite.withValues(alpha: 0.97)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.adminCommandCenter,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.selectManagementModule,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isMenuOpen = false),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBorder.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: textDark,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.7,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                        itemCount: _menuItems.length,
                        itemBuilder: (context, index) {
                          final item = _menuItems[index];
                          final int targetIndex = item['index'];
                          bool isActive = _currentIndex == targetIndex;
                          final itemName = _getMenuItemName(
                            context,
                            targetIndex,
                          );

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentIndex = targetIndex;
                                _isMenuOpen = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isActive ? primaryPink : surfaceWhite,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isActive ? primaryPink : cardBorder,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  if (!isActive)
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : item['color'].withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item['icon'],
                                      color: isActive
                                          ? Colors.white
                                          : item['color'],
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          itemName,
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.white
                                                : textDark,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          context.l10n.module,
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.white70
                                                : textGrey,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: lightPinkBg.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: primaryPink.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: lightPinkBg,
                                backgroundImage:
                                    _userProfile?['avatar_url'] != null
                                    ? NetworkImage(_userProfile!['avatar_url'])
                                    : null,
                                child: _userProfile?['avatar_url'] == null
                                    ? const Icon(
                                        Icons.person,
                                        color: primaryPink,
                                        size: 20,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}",
                                      style: const TextStyle(
                                        color: textDark,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _userProfile?['role']
                                              ?.toString()
                                              .toUpperCase() ??
                                          context.l10n.administrator,
                                      style: const TextStyle(
                                        color: primaryPink,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                side: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: Text(
                                context.l10n.signOutSession,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              onPressed: _logout,
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
