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

import 'certificates_screen.dart';
import 'wishlist_screen.dart';
import 'payments_screen.dart';
import 'scholarships_screen.dart';
import 'discussion_forum_screen.dart';
import 'settings_screen.dart';         // صفحه تنظیمات اپلیکیشن
import 'help_center_screen.dart';
import 'student_profile_screen.dart'; // صفحه پروفایل شخصی و اطلاعات کامل

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

  // لیست صفحات پورتال (ترتیب ایندکس‌ها باید با _menuItems همخوانی داشته باشد)
  late final List<Widget> _screens = [
    const StudentOverviewScreen(),          // 0
    const StudentAnnouncementsScreen(),     // 1
    const StudentCoursesScreen(),           // 2
    const WishlistScreen(),                 // 3
    const StudentLiveClassesScreen(),       // 4
    const StudentAssignmentsScreen(),       // 5
    const StudentQuizzesScreen(),           // 6
    const CertificatesScreen(),             // 7
    const ScholarshipsScreen(),             // 8
    const PaymentsScreen(),                 // 9
    const StudentTradingJournalScreen(),    // 10
    const DiscussionForumScreen(),          // 11
    const StudentWalletScreen(),            // 12
    const StudentAchievementsScreen(),      // 13
    _buildPlaceholderScreen("AI Assistant", Icons.smart_toy_rounded, "Smart assistant for your trading & studies."), // 14
    const HelpCenterScreen(),               // 15
    const StudentSupportScreen(),           // 16
    const StudentSettingsScreen(),          // 17 - صفحه پروفایل شخصی کامل
    const SettingsScreen(),                 // 18 - صفحه تنظیمات اپلیکیشن و امنیت
  ];

  // لیست منوها شامل پروفایل و تنظیمات به صورت مجزا
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
    {"index": 11, "name": "Discussion Forum", "icon": Icons.forum_rounded},
    {"index": 12, "name": "Wallet & Referral", "icon": Icons.account_balance_wallet_rounded},
    {"index": 13, "name": "Achievements", "icon": Icons.emoji_events_rounded},
    {"index": 14, "name": "AI Assistant (Soon)", "icon": Icons.smart_toy_rounded, "soon": true},
    {"index": 15, "name": "Help Center", "icon": Icons.help_outline_rounded},
    {"index": 16, "name": "Support Tickets", "icon": Icons.support_agent_rounded},
    {"index": 17, "name": "My Profile", "icon": Icons.person_rounded},         // ایندکس ۱۷ برای پروفایل
    {"index": 18, "name": "App Settings", "icon": Icons.settings_rounded},   // ایندکس ۱۸ برای تنظیمات
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
            border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
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
              Expanded(child: _buildNavItem(4, "Live", Icons.podcasts_rounded)),
              Expanded(child: _buildNavItem(12, "Wallet", Icons.account_balance_wallet_rounded)),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                  
                  // لیست منوها
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

                  // کارت پروفایل کاملاً فعال و کلیک‌پذیر در پایین منو
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 17; // رفتن به صفحه پروفایل (StudentSettingsScreen)
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