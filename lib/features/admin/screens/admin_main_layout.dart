import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  late final List<Widget> _screens = [
    const AdminDashboardScreen(), // 0: Overview
    const ManageStudentsScreen(), // 1: Students
    const ManageTeachersScreen(), // 2: Faculty
    const CoursesScreen(),        // 3: Courses
    const ClassesScreen(),        // 4: Classes
    const FinanceScreen(),        // 5: Finance
    const AwardsScreen(),         // 6: Honors
    const AnnouncementsScreen(),  // 7: Notices
    const LiveClassesScreen(),    // 8: Live Studio
    const TicketsScreen(),        // 9: Tickets
    const AdminSettingsScreen(),  // 10: Settings
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {"name": "Overview", "icon": Icons.dashboard_rounded, "color": primaryPink},
    {"name": "Students", "icon": Icons.school_rounded, "color": Colors.green},
    {"name": "Faculty", "icon": Icons.psychology_rounded, "color": Colors.indigo},
    {"name": "Courses", "icon": Icons.menu_book_rounded, "color": Colors.purple},
    {"name": "Classes", "icon": Icons.class_rounded, "color": Colors.cyan},
    {"name": "Finance", "icon": Icons.payments_rounded, "color": Colors.teal},
    {"name": "Honors", "icon": Icons.emoji_events_rounded, "color": Colors.amber},
    {"name": "Notices", "icon": Icons.campaign_rounded, "color": Colors.orange},
    {"name": "Live Studio", "icon": Icons.live_tv_rounded, "color": Colors.redAccent},
    {"name": "Tickets", "icon": "🎧", "color": primaryPink},
    {"name": "Settings", "icon": "⚙️", "color": textGrey},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAccess();
    });
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

      if (profile != null) {
        if (profile['role'] != 'admin' && profile['role'] != 'super_admin') {
          _logout();
          return;
        }
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink),
              const SizedBox(height: 16),
              Text(
                "INITIALIZING COMMAND CENTER...",
                style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final contentTopPadding = 16.0;
    final contentBottomPadding = bottomPadding + 85;

    return Scaffold(
      backgroundColor: surfaceWhite,
      extendBody: true, 
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. محتوای صفحات
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: contentTopPadding, bottom: contentBottomPadding),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),

          // 2. نوار ناوبری پایین کاملاً فیکس‌شده برای تمام سایزها
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 6 : 16.0,
            left: 12,
            right: 12,
            child: _buildFloatingBottomNav(),
          ),

          // 3. منوی شیشه‌ای تمام‌صفحه پیشرفته
          if (_isMenuOpen)
            Positioned.fill(
              child: _buildFullScreenMenu(),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: surfaceWhite.withOpacity(0.95),
            border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildNavItem(0, "Overview", Icons.dashboard_rounded)),
              Expanded(child: _buildNavItem(1, "Students", Icons.school_rounded)),
              Expanded(child: _buildNavItem(2, "Faculty", Icons.psychology_rounded)),
              Expanded(child: _buildNavItem(3, "Courses", Icons.menu_book_rounded)),
              // دکمه منوی اصلی فیکس‌شده
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isMenuOpen = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: primaryPink,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
                        SizedBox(height: 2),
                        Text("MENU", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
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
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? lightPinkBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? primaryPink : textGrey, size: isActive ? 22 : 19),
            const SizedBox(height: 2),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isActive ? primaryPink : textGrey,
                letterSpacing: 0.3,
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
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: surfaceWhite.withOpacity(0.98),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("COMMAND CENTER MENU", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        GestureDetector(
                          onTap: () => setState(() => _isMenuOpen = false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: cardBorder, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: textDark, size: 20),
                          ),
                        )
                      ],
                    ),
                  ),

                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.7,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                              _isMenuOpen = false;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              border: Border.all(color: cardBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                item['icon'] is IconData
                                    ? Icon(item['icon'], color: item['color'], size: 28)
                                    : Text(item['icon'], style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 8),
                                Text(item['name'].toUpperCase(), style: TextStyle(color: item['color'], fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: lightPinkBg.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: lightPinkBg,
                              backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                              child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: primaryPink, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_userProfile?['first_name']} ${_userProfile?['last_name']}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                  Text(_userProfile?['role']?.toString().toUpperCase() ?? 'ADMIN', style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
                              elevation: 0,
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text("SECURE SIGN OUT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
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