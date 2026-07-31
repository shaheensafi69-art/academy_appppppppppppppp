import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'courses_screen.dart';
import 'finance_screen.dart';

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
  List<Map<String, dynamic>> recentActivities = [];

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchCoreStatsAndActivity();
  }

  Future<void> _fetchCoreStatsAndActivity() async {
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
        // دریافت آخرین تراکنش‌ها یا ثبت‌نام‌ها برای بخش فعالیت‌های اخیر
        supabase.from('transactions').select('id, amount, transaction_type, status, created_at').order('created_at', ascending: false).limit(5),
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

      recentActivities = List<Map<String, dynamic>>.from(results[6]);
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text(
                "SYNCING SYSTEM METRICS...",
                style: TextStyle(
                  color: textGrey,
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

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "COMMAND CENTER",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.admin_panel_settings_rounded, color: primaryPink, size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text("Welcome back, ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
                      Text(
                        adminName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryPink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Live performance overview of your academy.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStatItem("Active Courses", stats.activeCourses.toString(), Icons.menu_book_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStatItem("Total Faculty", stats.totalTeachers.toString(), Icons.psychology_rounded)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Main Metrics Grid
            const Text("SYSTEM METRICS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildMetricCard("Total Students", stats.totalStudents.toString(), Icons.people_alt_rounded, Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen()));
                }),
                _buildMetricCard("Gross Revenue", "\$${stats.totalRevenue.toInt()}", Icons.account_balance_wallet_rounded, Colors.green.shade700, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
                }),
                _buildMetricCard("Open Tickets", stats.activeTickets.toString(), Icons.support_agent_rounded, Colors.amber.shade800, () {}),
                _buildMetricCard("Pending Payouts", stats.pendingWithdrawals.toString(), Icons.pending_actions_rounded, primaryPink, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
                }),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Section Title: Recent System Activity
            Row(
              children: [
                const Text(
                  "RECENT TRANSACTIONS FEED",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1.5, color: cardBorder)),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Activity List
            recentActivities.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentActivities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final act = recentActivities[index];
                      bool isCompleted = act['status'] == 'COMPLETED';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isCompleted ? Colors.green : Colors.amber).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.arrow_downward_rounded : Icons.hourglass_top_rounded,
                                    color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (act['transaction_type'] ?? 'Transaction').toString().toUpperCase(),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      act['created_at'] != null ? act['created_at'].toString().split('T')[0] : 'Recent',
                                      style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              "\$${act['amount'] ?? 0}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No recent financial activity recorded.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 12),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}