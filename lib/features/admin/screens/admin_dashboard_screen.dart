import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'courses_screen.dart';
import 'live_classes_screen.dart';
import 'finance_screen.dart';
import 'announcements_screen.dart';

class AdminStats {
  final int totalStudents;
  final int activeTickets;
  final double totalRevenue;
  final int pendingWithdrawals;
  final int totalTeachers;
  final int activeCourses;

  AdminStats({
    required this.totalStudents,
    required this.activeTickets,
    required this.totalRevenue,
    required this.pendingWithdrawals,
    required this.totalTeachers,
    required this.activeCourses,
  });
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String adminName = "";
  late AdminStats stats;

  @override
  void initState() {
    super.initState();
    _fetchCoreStats();
  }

  Future<void> _fetchCoreStats() async {
    setState(() => isLoading = true);

    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        final profile = await supabase
            .from('profiles')
            .select('first_name')
            .eq('id', session.user.id)
            .maybeSingle();
        if (profile != null) {
          adminName = profile['first_name'] ?? 'Admin';
        }
      }

      final results = await Future.wait([
        supabase.from('profiles').select('id').eq('role', 'student'),
        supabase.from('profiles').select('id').inFilter('role', ['teacher', 'mentor']),
        supabase.from('courses').select('id').eq('is_published', true),
        supabase.from('tickets').select('id').eq('status', 'open'),
        supabase.from('transactions').select('id').eq('transaction_type', 'withdrawal').eq('status', 'PENDING'),
        supabase.from('transactions').select('amount').eq('status', 'COMPLETED').inFilter('transaction_type', ['deposit', 'payment', 'course_fee']),
      ]);

      final revenueData = results[5] as List<dynamic>;
      double realTotalRevenue = 0;
      for (var item in revenueData) {
        realTotalRevenue += (item['amount'] ?? 0).toDouble();
      }

      stats = AdminStats(
        totalStudents: (results[0] as List).length,
        totalTeachers: (results[1] as List).length,
        activeCourses: (results[2] as List).length,
        activeTickets: (results[3] as List).length,
        pendingWithdrawals: (results[4] as List).length,
        totalRevenue: realTotalRevenue,
      );
    } catch (e) {
      debugPrint("Error fetching admin stats: $e");
      stats = AdminStats(totalStudents: 0, activeTickets: 0, totalRevenue: 0, pendingWithdrawals: 0, totalTeachers: 0, activeCourses: 0);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.pinkAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text(
                "SYNCING SYSTEM METRICS...",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.pink.withOpacity(0.12), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.purple.withOpacity(0.12), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          // استفاده از SingleChildScrollView بدون نیاز به SafeArea اضافی چون پدینگ کل صفحه در Layout مدیریت می‌شود
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Banner
                _buildGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
                            ),
                            child: const Text(
                              "COMMAND CENTER",
                              style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.pinkAccent, letterSpacing: 1.2),
                            ),
                          ),
                          const Icon(Icons.shield_outlined, color: Colors.pinkAccent, size: 16),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("Welcome back, ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white70)),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.pinkAccent, Colors.purpleAccent],
                            ).createShader(bounds),
                            child: Text(
                              adminName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Live performance overview of your academy.",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _buildMiniStatItem("Active Courses", stats.activeCourses.toString(), Icons.menu_book_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildMiniStatItem("Total Faculty", stats.totalTeachers.toString(), Icons.psychology_rounded)),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Main Metrics Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    _buildMetricCard("Total Students", stats.totalStudents.toString(), Icons.people_alt_rounded, Colors.tealAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen()));
                    }),
                    _buildMetricCard("Gross Revenue", "\$${stats.totalRevenue.toInt()}", Icons.account_balance_wallet_rounded, Colors.greenAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
                    }),
                    _buildMetricCard("Open Tickets", stats.activeTickets.toString(), Icons.support_agent_rounded, Colors.amber, () {}),
                    _buildMetricCard("Pending Payouts", stats.pendingWithdrawals.toString(), Icons.pending_actions_rounded, Colors.pinkAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Section Title
                Row(
                  children: [
                    const Text(
                      "SYSTEM WORKSPACES",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Quick Links Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    _buildQuickLinkCard("Student Desk", "Manage enrollments", Icons.people_rounded, Colors.teal, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen()));
                    }),
                    _buildQuickLinkCard("Faculty Office", "Instructors", Icons.person_search_rounded, Colors.indigo, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTeachersScreen()));
                    }),
                    _buildQuickLinkCard("Course Builder", "Create courses", Icons.auto_stories_rounded, Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesScreen()));
                    }),
                    _buildQuickLinkCard("Live Studio", "Monitor streams", Icons.podcasts_rounded, Colors.redAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveClassesScreen()));
                    }),
                    _buildQuickLinkCard("Finance", "Transactions", Icons.paid_rounded, Colors.green, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
                    }),
                    _buildQuickLinkCard("Broadcast", "Announcements", Icons.campaign_rounded, Colors.orange, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
                    }),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMiniStatItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _buildGlassCard(
        borderColor: color.withOpacity(0.15),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 10),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color == Colors.tealAccent ? Colors.white : color)),
                const SizedBox(height: 1),
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinkCard(String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _buildGlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 1),
                Text(desc.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
              ],
            )
          ],
        ),
      ),
    );
  }
}