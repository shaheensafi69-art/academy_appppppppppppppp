import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/student_overview_screen.dart';
import '../screens/student_announcements_screen.dart';
import '../screens/student_courses_screen.dart';
import '../screens/student_live_classes_screen.dart';
import '../screens/student_assignments_screen.dart';
import '../screens/student_quizzes_screen.dart';
import '../screens/student_trading_journal_screen.dart';
import '../screens/student_wallet_screen.dart';
import '../screens/student_achievements_screen.dart';
import '../screens/student_support_screen.dart';
import '../screens/student_feed_screen.dart';      // صفحه فید اجتماعی
import '../screens/student_friends_screen.dart';   // صفحه مدیریت دوستان

import 'certificates_screen.dart';
import 'wishlist_screen.dart';
import 'payments_screen.dart';
import 'scholarships_screen.dart';
import 'create_post_screen.dart';                // صفحه ساخت پست جدید
import 'settings_screen.dart';
import 'help_center_screen.dart';
import 'user_profile_screen.dart';            // صفحه پروفایل کاربر

import '../../../core/routing/auth_gate.dart';

class StudentMainLayout extends StatefulWidget {
  const StudentMainLayout({super.key});

  @override
  State<StudentMainLayout> createState() => _StudentMainLayoutState();
}

class _StudentMainLayoutState extends State<StudentMainLayout> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isMobileMenuOpen = false;
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color backgroundWhite = Colors.white;
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF111827);
  static const Color subTextColor = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFF3F4F6);
  static const Color lightPinkBg = Color(0xFFFCE4EC);

  late final List<Widget> _screens = [
    const StudentOverviewScreen(),         // 0
    const StudentAnnouncementsScreen(),    // 1
    const StudentCoursesScreen(),          // 2
    const WishlistScreen(),                // 3
    const StudentLiveClassesScreen(),      // 4
    const StudentAssignmentsScreen(),      // 5
    const StudentQuizzesScreen(),          // 6
    const CertificatesScreen(),            // 7
    const ScholarshipsScreen(),            // 8
    const PaymentsScreen(),                // 9
    const StudentTradingJournalScreen(),   // 10
    const CreatePostScreen(),              // 11 - صفحه ساخت پست جدید
    const StudentFeedScreen(),             // 12 - فید اجتماعی
    const StudentWalletScreen(),           // 13
    const StudentFriendsScreen(),          // 14 - صفحه دوستان
    const StudentAchievementsScreen(),     // 15
    _buildPlaceholderScreen("AI Assistant", Icons.smart_toy_rounded, "Smart assistant for your trading & studies."), // 16
    const HelpCenterScreen(),              // 17
    const StudentSupportScreen(),          // 18
    const UserProfileScreen(),          // 19 - پروفایل شخصی
    const SettingsScreen(),                // 20
  ];

  final List<Map<String, Object>> _menuItems = [
    {"index": 0, "name": "Overview", "icon": Icons.dashboard_rounded},
    {"index": 1, "name": "Announcements", "icon": Icons.campaign_rounded},
    {"index": 2, "name": "My Courses", "icon": Icons.menu_book_rounded},
    {"index": 3, "name": "Wishlist", "icon": Icons.favorite_rounded},
    {"index": 4, "name": "Live Campus", "icon": Icons.podcasts_rounded},
    {"index": 5, "name": "Assignments", "icon": Icons.assignment_rounded},
    {"index": 6, "name": "Exams & Quizzes", "icon": Icons.quiz_rounded},
    {"index": 7, "name": "Certificates", "icon": Icons.workspace_premium_rounded},
    {"index": 8, "name": "Scholarships", "icon": Icons.school_rounded},
    {"index": 9, "name": "Payments & Invoices", "icon": Icons.receipt_long_rounded},
    {"index": 10, "name": "Trading Journal", "icon": Icons.show_chart_rounded},
    {"index": 11, "name": "Create Post", "icon": Icons.add_rounded},
    {"index": 12, "name": "Social Feed", "icon": Icons.dynamic_feed_rounded},
    {"index": 13, "name": "Wallet & Referral", "icon": Icons.account_balance_wallet_rounded},
    {"index": 14, "name": "Friends & Network", "icon": Icons.people_alt_rounded},
    {"index": 15, "name": "Achievements", "icon": Icons.emoji_events_rounded},
    {"index": 16, "name": "AI Assistant (Soon)", "icon": Icons.smart_toy_rounded, "soon": true},
    {"index": 17, "name": "Help Center", "icon": Icons.help_outline_rounded},
    {"index": 18, "name": "Support Tickets", "icon": Icons.support_agent_rounded},
    {"index": 19, "name": "My Profile", "icon": Icons.person_rounded},
    {"index": 20, "name": "App Settings", "icon": Icons.settings_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStudentAccess();
    });
  }

  Future<void> _checkStudentAccess() async {
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

  Widget _buildPlaceholderScreen(String title, IconData icon, String subtitle) {
    return Scaffold(
      backgroundColor: backgroundWhite,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: lightPinkBg, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: primaryPink),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: subTextColor, fontSize: 11), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: lightPinkBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                ),
                child: const Text("Coming Soon 🚀", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
              )
            ],
          ),
        ),
      ),
    );
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
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text("INITIALIZING STUDENT PORTAL...", style: TextStyle(color: subTextColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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

  // تشخیص اینکه آیا کاربر در بخش اجتماعی (فید، دوستان، پروفایل یا ساخت پست) است یا خیر
  bool get _isInSocialSection => _currentIndex == 11 || _currentIndex == 12 || _currentIndex == 14 || _currentIndex == 19;

  Widget _buildFloatingBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.92),
            border: Border.all(color: primaryPink.withOpacity(0.18), width: 1.5),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: primaryPink.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _isInSocialSection
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildNavItem(12, "Feed", Icons.dynamic_feed_rounded)),
                    Expanded(child: _buildNavItem(14, "Friends", Icons.people_alt_rounded)),
                    // دکمه وسط (+) که مستقیماً به صفحه CreatePostScreen (ایندکس 11) هدایت می‌کند
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _currentIndex = 11),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryPink,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              SizedBox(height: 1),
                              Text("POST", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _buildNavItem(19, "Profile", Icons.person_rounded)),
                    // دکمه خروج از بخش اجتماعی و بازگشت به صفحه اصلی
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _currentIndex = 0),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 19),
                            SizedBox(height: 1),
                            Text("EXIT", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 0.8)),
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
                    Expanded(child: _buildNavItem(4, "Live", Icons.podcasts_rounded)),
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
                            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.grid_view_rounded, color: primaryPink, size: 20),
                              const SizedBox(height: 1),
                              Text("MENU", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 0.8)),
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
            Icon(
              icon,
              size: isActive ? 22 : 19,
              color: isActive ? primaryPink : subTextColor,
            ),
            const SizedBox(height: 1),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("STUDENT PORTAL MENU", style: TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        GestureDetector(
                          onTap: () => setState(() => _isMobileMenuOpen = false),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: primaryPink.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: primaryPink, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _menuItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        final int screenIndex = item['index'] as int;
                        final bool isSelected = _currentIndex == screenIndex;
                        final bool isSoon = item['soon'] == true;

                        return GestureDetector(
                          onTap: () {
                            if (!isSoon) {
                              setState(() {
                                _currentIndex = screenIndex;
                                _isMobileMenuOpen = false;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryPink.withOpacity(0.15) : Colors.grey.shade50,
                              border: Border.all(color: isSelected ? primaryPink.withOpacity(0.4) : borderColor, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? primaryPink : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 16,
                                    color: isSelected ? Colors.white : primaryPink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['name'] as String,
                                    style: TextStyle(
                                      color: isSelected ? primaryPink : textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (isSoon)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(6)),
                                    child: const Text("SOON", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: primaryPink)),
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: isSelected ? primaryPink : subTextColor,
                                  ),
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
                        _currentIndex = 19;
                        _isMobileMenuOpen = false;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: lightPinkBg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryPink.withOpacity(0.2),
                            backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                            child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: primaryPink, size: 16) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${_userProfile?['first_name'] ?? 'Student'} ${_userProfile?['last_name'] ?? ''}", style: const TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 1),
                                Text("BAL: \$${_formatNumber(_userProfile?['wallet_balance'])}", style: const TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.12),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 14),
                              label: const Text("LOG OUT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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

  String _formatNumber(dynamic val) {
    try {
      return (val ?? 0).toDouble().toStringAsFixed(2);
    } catch (_) {
      return "0.00";
    }
  }
}