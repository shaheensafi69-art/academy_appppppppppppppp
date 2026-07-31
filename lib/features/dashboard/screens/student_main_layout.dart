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
import '../screens/student_settings_screen.dart';
import '../../../core/routing/auth_gate.dart';

class StudentMainLayout extends StatefulWidget {
  const StudentMainLayout({super.key});

  @override
  State<StudentMainLayout> createState() => _StudentMainLayoutState();
}

class _StudentMainLayoutState extends State<StudentMainLayout> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isMenuOpen = false;
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;

  // لیست کامل صفحات پنل دانشجو به ترتیب منو
  late final List<Widget> _screens = [
    const StudentOverviewScreen(),          // 0: Overview
    const StudentAnnouncementsScreen(),   // 1: Announcements
    const StudentCoursesScreen(),         // 2: My Courses
    const StudentLiveClassesScreen(),     // 3: Live Campus
    const StudentAssignmentsScreen(),     // 4: Assignments
    const StudentQuizzesScreen(),         // 5: Exams & Quizzes
    const StudentTradingJournalScreen(),  // 6: Trading Journal
    const StudentWalletScreen(),          // 7: Wallet & Referral
    const StudentAchievementsScreen(),    // 8: Achievements
    _buildPlaceholderScreen("AI Assistant", "🤖", "Smart assistant for your trading & studies."), // 9: AI Assistant (Coming Soon)
    const StudentSupportScreen(),         // 10: Support Tickets
    const StudentSettingsScreen(),        // 11: Settings
  ];

  // دیتای منوی تمام‌صفحه با برچسب Coming Soon برای دستیار هوش مصنوعی
  final List<Map<String, dynamic>> _menuItems = [
    {"name": "Overview", "icon": "📊", "color": Colors.blue},
    {"name": "Announcements", "icon": "📢", "color": Colors.indigo},
    {"name": "My Courses", "icon": "📚", "color": Colors.green},
    {"name": "Live Campus", "icon": "🔴", "color": Colors.red},
    {"name": "Assignments", "icon": "📝", "color": Colors.orange},
    {"name": "Exams & Quizzes", "icon": "🎯", "color": Colors.purple},
    {"name": "Trading Journal", "icon": "📈", "color": Colors.cyan},
    {"name": "Wallet & Referral", "icon": "💰", "color": Colors.amber},
    {"name": "Achievements", "icon": "🏆", "color": Colors.amberAccent},
    {"name": "AI Assistant", "icon": "🤖", "color": Colors.pink, "soon": true},
    {"name": "Support Tickets", "icon": "🎧", "color": Colors.teal},
    {"name": "Settings", "icon": "⚙️", "color": Colors.grey},
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

  Widget _buildPlaceholderScreen(String title, String emoji, String subtitle) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.yellow.withOpacity(0.2)),
                ),
                child: const Text("Coming Soon 🚀", style: TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.yellowAccent),
              const SizedBox(height: 16),
              Text(
                "INITIALIZING STUDENT PORTAL...",
                style: TextStyle(color: Colors.yellowAccent.shade100, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottomMargin = bottomPadding > 0 ? bottomPadding + 4 : 12.0;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 🌟 هاله‌های نوری پویا طلایی رنگ پس‌زمینه
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.yellow.withOpacity(0.12), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          // 1. محتوای صفحات با پدینگ استاندارد فول‌اسکرین
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 68,
                bottom: 85,
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),

          // 2. هدر شناور بالای صفحه (کاملاً شیشه‌ای و بدون قاب سیاه)
          Positioned(
            top: topPadding + 6,
            left: 14,
            right: 14,
            child: _buildStudentHeader(),
          ),

          // 3. نوار ناوبری پایین شناور هوشمند
          Positioned(
            bottom: floatBottomMargin,
            left: 16,
            right: 16,
            child: _buildFloatingBottomNav(),
          ),

          // 4. منوی شیشه‌ای تمام‌صفحه (Drawer)
          if (_isMenuOpen)
            Positioned.fill(
              child: _buildFullScreenMenu(),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // لوگو و نام آکادمی
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.yellowAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.yellowAccent.withOpacity(0.2)),
                    ),
                    child: Image.asset('assets/logo-without-b.png', height: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "SAFI",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ],
              ),

              // پروفایل دانشجو (اتصال به Settings) و زنگوله (اتصال به Announcements)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 11), // Settings
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.yellowAccent.withOpacity(0.2),
                            backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                            child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.yellowAccent, size: 10) : null,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 75),
                            child: Text(
                              _userProfile?['first_name'] ?? 'Student',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 1), // Announcements
                    child: Stack(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: Colors.grey, size: 15),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.yellowAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, "Overview", "📊"),
              _buildNavItem(2, "Courses", "📚"),
              _buildNavItem(3, "Live", "🔴"),
              _buildNavItem(7, "Wallet", "💰"),
              GestureDetector(
                onTap: () => setState(() => _isMenuOpen = true),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("⚙️", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 1),
                    Text("MENU", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 0.8)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, String icon) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: isActive ? 20 : 16, shadows: isActive ? [const Shadow(color: Colors.yellowAccent, blurRadius: 8)] : [])),
            const SizedBox(height: 1),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isActive ? Colors.yellowAccent : Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
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
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: const Color(0xFF030305).withOpacity(0.95),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("STUDENT PORTAL MENU", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        GestureDetector(
                          onTap: () => setState(() => _isMenuOpen = false),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.grey, size: 18),
                          ),
                        )
                      ],
                    ),
                  ),

                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        bool isSoon = item['soon'] == true;
                        return GestureDetector(
                          onTap: () {
                            if (!isSoon) {
                              setState(() {
                                _currentIndex = index;
                                _isMenuOpen = false;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: item['color'].withOpacity(isSoon ? 0.03 : 0.08),
                              border: Border.all(color: item['color'].withOpacity(isSoon ? 0.06 : 0.15)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(item['icon'], style: TextStyle(fontSize: 28, color: isSoon ? Colors.grey : null)),
                                      const SizedBox(height: 6),
                                      Text(item['name'].toUpperCase(), style: TextStyle(color: isSoon ? Colors.grey : item['color'], fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                                if (isSoon)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.yellowAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.yellowAccent.withOpacity(0.2)),
                                      ),
                                      child: const Text("SOON", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.yellowAccent)),
                                    ),
                                  )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.yellowAccent.withOpacity(0.2),
                              backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                              child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.yellowAccent, size: 18) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_userProfile?['first_name']} ${_userProfile?['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("BALANCE: \$${_userProfile?['wallet_balance'] != null ? NumberFormatField(_userProfile!['wallet_balance']) : '0.00'}", style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.1),
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text("SECURE SIGN OUT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
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

  String NumberFormatField(dynamic val) {
    try {
      return (val ?? 0).toDouble().toStringAsFixed(2);
    } catch (_) {
      return "0.00";
    }
  }
}