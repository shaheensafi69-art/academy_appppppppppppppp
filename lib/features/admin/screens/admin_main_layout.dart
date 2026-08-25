import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'tickets_screen.dart';
import 'settings_screen.dart';

import '../../dashboard/screens/student_feed_screen.dart';
import '../../dashboard/screens/student_friends_screen.dart';
import 'create_post_screen.dart';
import 'user_profile_screen.dart';
import '../../reels/screens/student_reels_screen.dart';
import '../../reels/screens/upload_reel_screen.dart';

import '../../../core/routing/auth_gate.dart';

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

  List<Widget> get _screens => [
    const AdminDashboardScreen(), // 0: Overview
    const ManageStudentsScreen(), // 1: Students
    const ManageTeachersScreen(), // 2: Faculty
    const CoursesScreen(), // 3: Courses
    const ClassesScreen(), // 4: Classes
    const FinanceScreen(), // 5: Finance
    const AwardsScreen(), // 6: Honors
    const AnnouncementsScreen(), // 7: Notices
    const LiveClassesScreen(), // 8: Live Studio
    const TicketsScreen(), // 9: Tickets
    const AdminSettingsScreen(), // 10: Settings
    CreatePostScreen(
      onPostSuccess: () => setState(() => _currentIndex = 12),
    ), // 11: Create Post
    const StudentFeedScreen(), // 12: Academy Feed (فید اجتماعی یکپارچه)
    const StudentFriendsScreen(), // 13: Friends & Network (شبکه یکپارچه)
    UserProfileScreen(
      onExit: () => setState(() => _currentIndex = 0),
    ), // 14: Admin Profile
    StudentReelsScreen(isActive: _currentIndex == 15), // 15: Educational Reels
  ];

  // لیست گزینه‌های منوی کامل ادمین
  final List<Map<String, dynamic>> _menuItems = [
    {
      "name": "Overview",
      "icon": Icons.dashboard_rounded,
      "index": 0,
      "color": primaryPink,
    },
    {
      "name": "Students",
      "icon": Icons.school_rounded,
      "index": 1,
      "color": const Color(0xFF00897B),
    },
    {
      "name": "Faculty",
      "icon": Icons.psychology_rounded,
      "index": 2,
      "color": const Color(0xFF3949AB),
    },
    {
      "name": "Courses",
      "icon": Icons.menu_book_rounded,
      "index": 3,
      "color": const Color(0xFF7B1FA2),
    },
    {
      "name": "Classes",
      "icon": Icons.class_rounded,
      "index": 4,
      "color": const Color(0xFF00ACC1),
    },
    {
      "name": "Finance",
      "icon": Icons.payments_rounded,
      "index": 5,
      "color": const Color(0xFF2E7D32),
    },
    {
      "name": "Honors",
      "icon": Icons.emoji_events_rounded,
      "index": 6,
      "color": const Color(0xFFFFA000),
    },
    {
      "name": "Notices",
      "icon": Icons.campaign_rounded,
      "index": 7,
      "color": const Color(0xFFFB8C00),
    },
    {
      "name": "Live Studio",
      "icon": Icons.live_tv_rounded,
      "index": 8,
      "color": const Color(0xFFE53935),
    },
    {
      "name": "Academy Feed",
      "icon": Icons.dynamic_feed_rounded,
      "index": 12,
      "color": const Color(0xFFD81B60),
    },
    {
      "name": "Support Tickets",
      "icon": Icons.headset_mic_rounded,
      "index": 9,
      "color": primaryPink,
    },
    {
      "name": "Settings",
      "icon": Icons.settings_rounded,
      "index": 10,
      "color": textGrey,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _logout();
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
      } else {
        _logout();
      }
    } catch (e) {
      _logout();
    }
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    }
  }

  // بررسی اینکه ادمین در بخش سوشال (فید، نتورک، پست، پروفایل) است یا بخش مدیریتی
  bool get _isInSocialSection =>
      _currentIndex == 12 ||
      _currentIndex == 13 ||
      _currentIndex == 14 ||
      _currentIndex == 15;

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
                "INITIALIZING COMMAND CENTER...",
                style: TextStyle(
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

    final bool isReels = _currentIndex == 15;
    if (isReels) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final contentBottomPadding = bottomPadding > 0 ? bottomPadding + 85 : 85.0;

    return Scaffold(
      backgroundColor: surfaceWhite,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: (isReels || _isInSocialSection)
                    ? 0
                    : (MediaQuery.of(context).padding.top + 8),
                bottom: _isInSocialSection ? 0 : contentBottomPadding,
              ),
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ),
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
              const Text(
                "Create New Content 🚀",
                style: TextStyle(
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
                title: const Text(
                  "Upload Educational Reel 🎬",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                subtitle: const Text(
                  "Share short trading or coding videos with peers",
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
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
                title: const Text(
                  "Create Feed Post 📝",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                subtitle: const Text(
                  "Share text, questions, or images on the academy feed",
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
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
                "FEED",
                Icons.dynamic_feed_rounded,
                color: primaryPink,
              ),
            ),
            Expanded(
              child: _buildNavTab(
                15,
                "REELS",
                Icons.video_library_rounded,
                color: primaryPink,
              ),
            ),
            // دکمه وسط (+) با انتخاب دوگانه ریلز یا پست معمولی (Instagram Style)
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
                "FRIENDS",
                Icons.people_alt_rounded,
                color: primaryPink,
              ),
            ),
            Expanded(
              child: _buildNavTab(
                14,
                "PROFILE",
                Icons.person_rounded,
                color: primaryPink,
              ),
            ),
          ],
        ),
      );
    }

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
                  "Overview",
                  Icons.dashboard_rounded,
                  color: primaryPink,
                ),
              ),
              Expanded(
                child: _buildNavTab(
                  1,
                  "Students",
                  Icons.school_rounded,
                  color: const Color(0xFF00897B),
                ),
              ),
              Expanded(
                child: _buildNavTab(
                  12,
                  "Feed",
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: primaryPink,
                          size: 22,
                        ),
                        SizedBox(height: 3),
                        Text(
                          "MENU",
                          style: TextStyle(
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COMMAND CENTER",
                            style: TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Select a management module",
                            style: TextStyle(
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
                                          item['name'],
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
                                          "Module",
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
                                          'ADMINISTRATOR',
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
                              label: const Text(
                                "SIGN OUT SESSION",
                                style: TextStyle(
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
