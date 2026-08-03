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

  // پالت رنگی حرفه‌ای هماهنگ با پنل‌های دیگر
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);

  // لیست اسکرین‌های ادمین
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

  // لیست گزینه‌های منوی کامل ادمین
  final List<Map<String, dynamic>> _menuItems = [
    {"name": "Overview", "icon": Icons.dashboard_rounded, "index": 0, "color": primaryPink},
    {"name": "Students", "icon": Icons.school_rounded, "index": 1, "color": const Color(0xFF00897B)},
    {"name": "Faculty", "icon": Icons.psychology_rounded, "index": 2, "color": const Color(0xFF3949AB)},
    {"name": "Courses", "icon": Icons.menu_book_rounded, "index": 3, "color": const Color(0xFF7B1FA2)},
    {"name": "Classes", "icon": Icons.class_rounded, "index": 4, "color": const Color(0xFF00ACC1)},
    {"name": "Finance", "icon": Icons.payments_rounded, "index": 5, "color": const Color(0xFF2E7D32)},
    {"name": "Honors", "icon": Icons.emoji_events_rounded, "index": 6, "color": const Color(0xFFFFA000)},
    {"name": "Notices", "icon": Icons.campaign_rounded, "index": 7, "color": const Color(0xFFFB8C00)},
    {"name": "Live Studio", "icon": Icons.live_tv_rounded, "index": 8, "color": const Color(0xFFE53935)},
    {"name": "Support", "icon": Icons.headset_mic_rounded, "index": 9, "color": primaryPink},
    {"name": "Settings", "icon": Icons.settings_rounded, "index": 10, "color": textGrey},
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
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
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
    final contentBottomPadding = bottomPadding + 85;

    return Scaffold(
      backgroundColor: surfaceWhite,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. محتوای اصلی صفحات
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: contentBottomPadding),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),

          // 2. نوار ناوبری پایین اختصاصی (دقیقاً شامل 4 دکمه: Overview, Students, Faculty, Menu)
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 8 : 16.0,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildModernBottomNav(),
              ),
            ),
          ),

          // 3. منوی تمام‌صفحه جدید با دیزاین لوکس
          if (_isMenuOpen)
            Positioned.fill(
              child: _buildModernFullScreenMenu(),
            ),
        ],
      ),
    );
  }

  // طراحی جدید و فیکس‌شده نوار ناوبری با ۴ دکمه اصلی
  Widget _buildModernBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceWhite.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Overview Button
              Expanded(child: _buildNavTab(0, "Overview", Icons.dashboard_rounded)),
              
              // 2. Students Button
              Expanded(child: _buildNavTab(1, "Students", Icons.school_rounded)),
              
              // 3. Faculty Button
              Expanded(child: _buildNavTab(2, "Faculty", Icons.psychology_rounded)),
              
              // 4. Menu Button (برای دسترسی به بقیه بخش‌ها)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isMenuOpen = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _isMenuOpen ? lightPinkBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_view_rounded, color: primaryPink, size: 22),
                        const SizedBox(height: 3),
                        Text(
                          "MENU",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: primaryPink,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  // ویجت کمکی برای تب‌های ناوبری
  Widget _buildNavTab(int index, String title, IconData icon) {
    bool isActive = _currentIndex == index && !_isMenuOpen;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _isMenuOpen = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? lightPinkBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryPink : textGrey,
              size: isActive ? 22 : 20,
            ),
            const SizedBox(height: 3),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: isActive ? primaryPink : textGrey,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // دیزاین کاملاً جدید و یکدست برای منوی تمام‌صفحه ادمین
  Widget _buildModernFullScreenMenu() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
              child: Container(color: surfaceWhite.withOpacity(0.97)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // هدر منو
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("COMMAND CENTER", style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          SizedBox(height: 2),
                          Text("Select a management module", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isMenuOpen = false),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: cardBorder, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: textDark, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // لیست شبکه‌ای تمام گزینه‌های منو
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                border: Border.all(color: isActive ? primaryPink : cardBorder, width: 1.5),
                                boxShadow: [
                                  if (!isActive)
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white.withOpacity(0.2) : item['color'].withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(item['icon'], color: isActive ? Colors.white : item['color'], size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: TextStyle(
                                            color: isActive ? Colors.white : textDark,
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
                                            color: isActive ? Colors.white70 : textGrey,
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
                
                // پروفایل و دکمه خروج در پایین منو
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Container(
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
                                    Text("${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                    Text(_userProfile?['role']?.toString().toUpperCase() ?? 'ADMINISTRATOR', style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
                                backgroundColor: Colors.redAccent.withOpacity(0.1),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text("SIGN OUT SESSION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
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