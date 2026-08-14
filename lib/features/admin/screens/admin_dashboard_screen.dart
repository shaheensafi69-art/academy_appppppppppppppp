import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_students_screen.dart';
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

  factory AdminStats.fromMap(Map<String, dynamic> map) {
    return AdminStats(
      totalStudents: map['totalStudents'] ?? 0,
      activeTickets: map['activeTickets'] ?? 0,
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      pendingWithdrawals: map['pendingWithdrawals'] ?? 0,
      totalTeachers: map['totalTeachers'] ?? 0,
      activeCourses: map['activeCourses'] ?? 0,
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String adminName = "Administrator";
  AdminStats stats = AdminStats(totalStudents: 0, activeTickets: 0, totalRevenue: 0, pendingWithdrawals: 0, totalTeachers: 0, activeCourses: 0);
  List<Map<String, dynamic>> recentActivities = [];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
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

      final statsRes = await supabase.rpc('get_admin_dashboard_stats');
      if (statsRes != null) {
        stats = AdminStats.fromMap(statsRes);
      }

      final txRes = await supabase
          .from('transactions')
          .select('id, amount, transaction_type, status, created_at')
          .order('created_at', ascending: false)
          .limit(6);

      recentActivities = List<Map<String, dynamic>>.from(txRes);
    } catch (e) {
      debugPrint("Error fetching dashboard metrics: $e");
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
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 3),
              const SizedBox(height: 16),
              const Text(
                "INITIALIZING COMMAND CENTER...",
                style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFF0F5).withValues(alpha: 0.5), surfaceWhite],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: primaryPink,
            onRefresh: _fetchDashboardData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= ۱. بنر خوش‌آمدگویی و آمار کلیدی =================
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: primaryPink.withValues(alpha: 0.06), blurRadius: 25, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: lightPinkBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: primaryPink.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    "SYSTEM COMMAND CENTER",
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryPink.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.admin_panel_settings_rounded, color: primaryPink, size: 22),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text("Welcome back, ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark)),
                                Text(adminName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryPink)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Live performance overview and global academy control.",
                              style: TextStyle(fontSize: 12, color: textGrey, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, boxConstraints) {
                                bool isWide = boxConstraints.maxWidth > 500;
                                return Flex(
                                  direction: isWide ? Axis.horizontal : Axis.vertical,
                                  children: [
                                    Expanded(
                                      flex: isWide ? 1 : 0,
                                      child: _buildMiniStatItem("Active Courses", stats.activeCourses.toString(), Icons.menu_book_rounded),
                                    ),
                                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                                    Expanded(
                                      flex: isWide ? 1 : 0,
                                      child: _buildMiniStatItem("Total Faculty", stats.totalTeachers.toString(), Icons.psychology_rounded),
                                    ),
                                  ],
                                );
                              },
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ================= ۲. متریک‌های سیستم (کاملاً ریسپانسیو) =================
                      const Text("SYSTEM METRICS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraintsGrid) {
                          bool isWide = constraintsGrid.maxWidth > 600;

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(child: _buildMetricCard("Total Students", stats.totalStudents.toString(), Icons.people_alt_rounded, const Color(0xFF00897B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen())))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildMetricCard("Gross Revenue", "\$${stats.totalRevenue.toInt()}", Icons.account_balance_wallet_rounded, const Color(0xFF2E7D32), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildMetricCard("Open Tickets", stats.activeTickets.toString(), Icons.support_agent_rounded, const Color(0xFFF57C00), () {})),
                                const SizedBox(width: 12),
                                Expanded(child: _buildMetricCard("Pending Payouts", stats.pendingWithdrawals.toString(), Icons.pending_actions_rounded, primaryPink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())))),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard("Total Students", stats.totalStudents.toString(), Icons.people_alt_rounded, const Color(0xFF00897B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen())))),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildMetricCard("Gross Revenue", "\$${stats.totalRevenue.toInt()}", Icons.account_balance_wallet_rounded, const Color(0xFF2E7D32), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())))),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard("Open Tickets", stats.activeTickets.toString(), Icons.support_agent_rounded, const Color(0xFFF57C00), () {})),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildMetricCard("Pending Payouts", stats.pendingWithdrawals.toString(), Icons.pending_actions_rounded, primaryPink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())))),
                                  ],
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 32),

                      // ================= ۳. فید تراکنش‌های اخیر =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "RECENT TRANSACTIONS",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
                            child: const Text("View All", style: TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      recentActivities.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recentActivities.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final act = recentActivities[index];
                                bool isCompleted = act['status'] == 'COMPLETED';

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: cardBorder, width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: (isCompleted ? Colors.green : Colors.amber).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                isCompleted ? Icons.arrow_downward_rounded : Icons.hourglass_top_rounded,
                                                color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    (act['transaction_type'] ?? 'Transaction').toString().toUpperCase().replaceAll('_', ' '),
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    act['created_at'] != null ? act['created_at'].toString().split('T')[0] : 'Recent',
                                                    style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "\$${(act['amount'] ?? 0).toDouble().toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isCompleted ? Colors.green : Colors.amber).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              (act['status'] ?? 'PENDING').toString().toUpperCase(),
                                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(40),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorder, width: 1.5),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: textGrey),
                                  SizedBox(height: 12),
                                  Text("No recent financial activity recorded.", style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                      const SizedBox(height: 100), // فاصله برای Bottom Nav
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: lightPinkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryPink, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}