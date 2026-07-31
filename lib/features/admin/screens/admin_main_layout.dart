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
    {"name": "Overview", "icon": "📊", "color": Colors.blue},
    {"name": "Students", "icon": "👨‍🎓", "color": Colors.green},
    {"name": "Faculty", "icon": "👨‍🏫", "color": Colors.indigo},
    {"name": "Courses", "icon": "📚", "color": Colors.purple},
    {"name": "Classes", "icon": "🏫", "color": Colors.cyan},
    {"name": "Finance", "icon": "💰", "color": Colors.greenAccent},
    {"name": "Honors", "icon": "🏆", "color": Colors.amber},
    {"name": "Notices", "icon": "📢", "color": Colors.orange},
    {"name": "Live Studio", "icon": "🔴", "color": Colors.red},
    {"name": "Tickets", "icon": "🎧", "color": Colors.pink},
    {"name": "Settings", "icon": "⚙️", "color": Colors.grey},
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
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.pinkAccent),
              const SizedBox(height: 16),
              Text(
                "INITIALIZING COMMAND CENTER...",
                style: TextStyle(color: Colors.pinkAccent.shade100, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // محاسبه دقیق فضای خالی بالا (هدر) و پایین (نوار ناوبری) به صورت استاندارد
    final contentTopPadding = topPadding + 68;
    final contentBottomPadding = bottomPadding + 75;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      extendBody: true, 
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. محتوای صفحات با پدینگ کاملاً خودکار و هوشمند بدون نیاز به مارجین در صفحات داخلی
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: contentTopPadding, bottom: contentBottomPadding),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),

          // 2. هدر شناور بالای صفحه
          Positioned(
            top: topPadding + 6,
            left: 14,
            right: 14,
            child: _buildSurpriseHeader(),
          ),

          // 3. نوار ناوبری پایین شناور
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 4 : 12.0,
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

  Widget _buildSurpriseHeader() {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 10),
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
                            backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                            backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                            child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.pinkAccent, size: 10) : null,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 75),
                            child: Text(
                              _userProfile?['first_name'] ?? 'Admin',
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
                    onTap: () => setState(() => _currentIndex = 7),
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
                              color: Colors.pinkAccent,
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
              _buildNavItem(1, "Students", "👨‍🎓"),
              _buildNavItem(2, "Finance", "💰"),
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: isActive ? 20 : 16, shadows: isActive ? [const Shadow(color: Colors.pinkAccent, blurRadius: 8)] : [])),
            const SizedBox(height: 1),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isActive ? Colors.pinkAccent : Colors.grey.shade500,
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
                        const Text("COMMAND CENTER MENU", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                              _isMenuOpen = false;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: item['color'].withOpacity(0.08),
                              border: Border.all(color: item['color'].withOpacity(0.15)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item['icon'], style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 6),
                                Text(item['name'].toUpperCase(), style: TextStyle(color: item['color'], fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
                              backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                              backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage(_userProfile!['avatar_url']) : null,
                              child: _userProfile?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.pinkAccent, size: 18) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_userProfile?['first_name']} ${_userProfile?['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(_userProfile?['role']?.toString().toUpperCase() ?? 'ADMIN', style: const TextStyle(color: Colors.pinkAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
}             