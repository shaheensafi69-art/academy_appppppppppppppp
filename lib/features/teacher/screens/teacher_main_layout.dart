import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_overview_screen.dart';
import 'teacher_announcements_screen.dart';
import 'teacher_courses_curriculum_screen.dart';
import 'teacher_live_classes_screen.dart';
import 'teacher_all_students_screen.dart';
import 'teacher_assignments_screen.dart';
import 'teacher_quizzes_overview_screen.dart';
import 'teacher_trading_journal_screen.dart';
import 'teacher_achievements_screen.dart';
import 'teacher_certificates_screen.dart';
import 'teacher_about_help_center_screen.dart';
import 'teacher_settings_screen.dart';
import 'user_profile_screen.dart';
// صفحات اختصاصی بخش فید و سوشال
import 'teacher_feed_screen.dart'; 
import 'teacher_friends_screen.dart'; 
import 'create_post_screen.dart'; 

import '../../../core/routing/auth_gate.dart';

class TeacherMainLayout extends StatefulWidget {
  const TeacherMainLayout({super.key});

  @override
  State<TeacherMainLayout> createState() => _TeacherMainLayoutState();
}

class _TeacherMainLayoutState extends State<TeacherMainLayout> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isMobileMenuOpen = false;
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  late final List<Widget> _screens = [
    const TeacherOverviewScreen(),          // 0
    const TeacherAnnouncementsScreen(),     // 1
    const TeacherCoursesCurriculumScreen(), // 2
    const TeacherLiveClassesScreen(),       // 3
    const TeacherAllStudentsScreen(),       // 4
    const TeacherAssignmentsScreen(),       // 5
    const TeacherQuizzesOverviewScreen(),   // 6
    const TeacherTradingJournalScreen(),    // 7
    const TeacherAchievementsScreen(),      // 8
    const TeacherCertificatesScreen(),      // 9
    const TeacherAboutHelpCenterScreen(),   // 10
    CreatePostScreen(onPostSuccess: () => setState(() => _currentIndex = 12)), // 11
    const TeacherFeedScreen(),              // 12
    const UserProfileScreen(),           // 13
    const TeacherSettingsScreen(),          // 14
    const TeacherFriendsScreen(),           // 15 - صفحه شبکه و اساتید
  ];

  final List<Map<String, Object>> _menuItems = [
    {"index": 0, "name": "Overview", "icon": Icons.dashboard_rounded},
    {"index": 1, "name": "Announcements", "icon": Icons.campaign_rounded},
    {"index": 2, "name": "My Courses", "icon": Icons.menu_book_rounded},
    {"index": 3, "name": "Live Classes", "icon": Icons.podcasts_rounded},
    {"index": 4, "name": "My Students", "icon": Icons.group_rounded},
    {"index": 5, "name": "Assignments", "icon": Icons.assignment_rounded},
    {"index": 6, "name": "Exams & Quizzes", "icon": Icons.quiz_rounded},
    {"index": 7, "name": "Trading Journal", "icon": Icons.show_chart_rounded},
    {"index": 8, "name": "Achievements", "icon": Icons.emoji_events_rounded},
    {"index": 9, "name": "Certificates", "icon": Icons.workspace_premium_rounded},
    {"index": 10, "name": "Help Center", "icon": Icons.help_outline_rounded},
    {"index": 11, "name": "Create Post", "icon": Icons.add_rounded},
    {"index": 12, "name": "Academy Feed", "icon": Icons.dynamic_feed_rounded},
    {"index": 15, "name": "Faculty & Network", "icon": Icons.people_alt_rounded},
    {"index": 13, "name": "My Profile", "icon": Icons.person_rounded},
    {"index": 14, "name": "App Settings", "icon": Icons.settings_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTeacherAccess();
    });
  }

  Future<void> _checkTeacherAccess() async {
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

      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logout();
    }
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryPink, strokeWidth: 3),
              SizedBox(height: 16),
              Text("INITIALIZING INSTRUCTOR PORTAL...", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottomMargin = bottomPadding > 0 ? bottomPadding + 4 : 12.0;

    return Scaffold(
      backgroundColor: surfaceWhite,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 85),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),
          Positioned(
            bottom: floatBottomMargin,
            left: 16,
            right: 16,
            child: _buildFloatingBottomNav(),
          ),
          if (_isMobileMenuOpen)
            Positioned.fill(
              child: _buildFullScreenMenu(),
            ),
        ],
      ),
    );
  }

  bool get _isInSocialSection => _currentIndex == 11 || _currentIndex == 12 || _currentIndex == 13 || _currentIndex == 15;

  Widget _buildFloatingBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceWhite.withOpacity(0.92),
            border: Border.all(color: primaryPink.withOpacity(0.18), width: 1.5),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 8))],
          ),
          child: _isInSocialSection
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildNavItem(12, "Feed", Icons.dynamic_feed_rounded)),
                    Expanded(child: _buildNavItem(15, "Network", Icons.people_alt_rounded)),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _currentIndex = 11),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: primaryPink, borderRadius: BorderRadius.circular(20)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              SizedBox(height: 2),
                              Text("POST", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _buildNavItem(13, "Profile", Icons.person_rounded)),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _currentIndex = 0),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(height: 2),
                            Text("EXIT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 0.8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildNavItem(0, "Overview", Icons.dashboard_rounded)),
                    Expanded(child: _buildNavItem(2, "Courses", Icons.menu_book_rounded)),
                    Expanded(child: _buildNavItem(3, "Live", Icons.podcasts_rounded)),
                    Expanded(child: _buildNavItem(12, "Feed", Icons.dynamic_feed_rounded)),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _isMobileMenuOpen = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: lightPinkBg.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.grid_view_rounded, color: primaryPink, size: 20),
                              SizedBox(height: 2),
                              Text("MENU", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 0.8)),
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

  Widget _buildNavItem(int index, String title, IconData icon) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? lightPinkBg : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isActive ? 22 : 20, color: isActive ? primaryPink : textGrey),
            const SizedBox(height: 2),
            Text(
              title.toUpperCase(),
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isActive ? primaryPink : textGrey, letterSpacing: 0.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenMenu() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: surfaceWhite.withOpacity(0.97),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("INSTRUCTOR PORTAL MENU", style: TextStyle(color: primaryPink, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        GestureDetector(
                          onTap: () => setState(() => _isMobileMenuOpen = false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: primaryPink.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: primaryPink, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _menuItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        final int screenIndex = item['index'] as int;
                        final bool isSelected = _currentIndex == screenIndex;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = screenIndex;
                              _isMobileMenuOpen = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryPink.withOpacity(0.15) : cardBorder.withOpacity(0.5),
                              border: Border.all(color: isSelected ? primaryPink.withOpacity(0.4) : cardBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? primaryPink : surfaceWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                                  ),
                                  child: Icon(item['icon'] as IconData, size: 18, color: isSelected ? Colors.white : primaryPink),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(item['name'] as String, style: TextStyle(color: isSelected ? primaryPink : textDark, fontSize: 13, fontWeight: FontWeight.w900)),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isSelected ? primaryPink : textGrey),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 13; 
                        _isMobileMenuOpen = false;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: lightPinkBg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryPink.withOpacity(0.2),
                            backgroundImage: _userProfile?['avatar_url'] != null && _userProfile!['avatar_url'].toString().isNotEmpty ? NetworkImage(_userProfile!['avatar_url']) : null,
                            child: _userProfile?['avatar_url'] == null || _userProfile!['avatar_url'].toString().isEmpty ? const Icon(Icons.person, color: primaryPink, size: 20) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${_userProfile?['first_name'] ?? 'Instructor'} ${_userProfile?['last_name'] ?? ''}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                const Text("Faculty Member", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.12),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text("SIGN OUT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              onPressed: _logout,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}