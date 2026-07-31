import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ایمپورت صفحات پنل استاد
import '../screens/teacher_overview_screen.dart';
import '../screens/teacher_announcements_screen.dart';
import '../screens/teacher_courses_curriculum_screen.dart';
import '../screens/teacher_live_classes_screen.dart';
import '../screens/teacher_all_students_screen.dart';
import '../screens/teacher_assignments_screen.dart';
import '../screens/teacher_quizzes_overview_screen.dart';
import '../screens/teacher_trading_journal_screen.dart';
import '../screens/teacher_achievements_screen.dart';
import '../screens/teacher_settings_screen.dart';
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

  // پالت رنگی اختصاصی لایت (سفید و صورتی غلیظ)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color backgroundWhite = Colors.white;
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF1A1A1A);
  static const Color subTextColor = Color(0xFF666666);
  static const Color borderColor = Color(0xFFE0E0E0);

  // لیست کامل صفحات پنل استاد به ترتیب منو
  late final List<Widget> _screens = [
    const TeacherOverviewScreen(),          // 0: Overview
    const TeacherAnnouncementsScreen(),     // 1: Announcements
    const TeacherCoursesCurriculumScreen(), // 2: My Courses
    const TeacherLiveClassesScreen(),       // 3: Live Classes
    const TeacherAllStudentsScreen(),       // 4: My Students
    const TeacherAssignmentsScreen(),       // 5: Assignments
    const TeacherQuizzesOverviewScreen(),   // 6: Exams & Quizzes
    const TeacherTradingJournalScreen(),    // 7: Trading Journal
    const TeacherAchievementsScreen(),      // 8: Achievements
    const TeacherSettingsScreen(),          // 9: Settings
  ];

  // دیتای منو
  final List<Map<String, Object>> _menuItems = [
    {"index": 0, "name": "Overview", "icon": Icons.dashboard_rounded},
    {"index": 1, "name": "Announcements", "icon": Icons.campaign_rounded},
    {"index": 2, "name": "My Courses", "icon": Icons.menu_book_rounded},
    {"index": 3, "name": "Live Classes", "icon": Icons.live_tv_rounded},
    {"index": 4, "name": "My Students", "icon": Icons.group_rounded},
    {"index": 5, "name": "Assignments", "icon": Icons.assignment_rounded},
    {"index": 6, "name": "Exams & Quizzes", "icon": Icons.quiz_rounded},
    {"index": 7, "name": "Trading Journal", "icon": Icons.trending_up_rounded},
    {"index": 8, "name": "Achievements", "icon": Icons.emoji_events_rounded},
    {"index": 9, "name": "Settings", "icon": Icons.settings_rounded},
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
          .select('first_name, last_name, avatar_url, wallet_balance, role')
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
      return Scaffold(
        backgroundColor: backgroundWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink),
              const SizedBox(height: 16),
              Text(
                "INITIALIZING INSTRUCTOR PORTAL...",
                style: TextStyle(color: primaryPink.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottomMargin = bottomPadding > 0 ? bottomPadding + 4 : 12.0;

    return Scaffold(
      backgroundColor: backgroundWhite,
      extendBody: true,
      body: Stack(
        children: [
          // هاله نوری ملایم صورتی در پس‌زمینه سفید
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.04), blurRadius: 100, spreadRadius: 40),
                ],
              ),
            ),
          ),

          // ۱. محتوای صفحات
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 85,
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),

          // ۲. نوار ناوبری پایین با ۴ دکمه فیکس و منظم
          Positioned(
            bottom: floatBottomMargin,
            left: 16,
            right: 16,
            child: _buildFloatingBottomNav(),
          ),

          // ۳. منوی تمام‌صفحه
          if (_isMobileMenuOpen)
            Positioned.fill(
              child: _buildFullScreenMenu(),
            ),
        ],
      ),
    );
  }

  // استفاده از Expanded برای توزیع کاملاً مساوی و فیکس ۴ آیتم نویگیشن بار
  Widget _buildFloatingBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.95),
            border: Border.all(color: primaryPink.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(0, "Overview", Icons.dashboard_rounded)),
              Expanded(child: _buildNavItem(2, "Courses", Icons.menu_book_rounded)),
              Expanded(child: _buildNavItem(4, "Students", Icons.group_rounded)),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isMobileMenuOpen = true),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_view_rounded, color: subTextColor, size: 22),
                      const SizedBox(height: 2),
                      Text("MENU", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: subTextColor, letterSpacing: 0.8)),
                    ],
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
      child: Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isActive ? 24 : 20,
              color: isActive ? primaryPink : subTextColor,
            ),
            const SizedBox(height: 2),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isActive ? primaryPink : subTextColor,
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

  Widget _buildFullScreenMenu() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: backgroundWhite.withOpacity(0.97),
            child: SafeArea(
              child: Column(
                children: [
                  // هدر منو
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("INSTRUCTOR PORTAL MENU", style: TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                  
                  // لیست منوها
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _menuItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryPink.withOpacity(0.15) : Colors.grey.shade50,
                              border: Border.all(color: isSelected ? primaryPink.withOpacity(0.4) : borderColor),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? primaryPink : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 18,
                                    color: isSelected ? Colors.white : primaryPink,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item['name'] as String,
                                    style: TextStyle(
                                      color: isSelected ? primaryPink : textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: isSelected ? primaryPink : subTextColor,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // بخش پروفایل و خروج
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: primaryPink.withOpacity(0.15),
                              backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                              child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: primaryPink, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}", style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text("BALANCE: \$${_userProfile?['wallet_balance'] != null ? (_userProfile!['wallet_balance'] as num).toDouble().toStringAsFixed(2) : '0.00'}", style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.15),
                              foregroundColor: Colors.redAccent,
                              elevation: 0,
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text("SECURE SIGN OUT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            onPressed: _logout,
                          ),
                        ),
                      ],
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