import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:safi_academy_app/features/admin/screens/finance_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'finance_screen.dart';

// Define a custom color for emeraldAccent
const Color emeraldAccent = Color(0xFF00C853);
class TeacherWallet {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;
  final double walletBalance;

  TeacherWallet({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
    required this.walletBalance,
  });

  factory TeacherWallet.fromJson(Map<String, dynamic> json) {
    return TeacherWallet(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      walletBalance: (json['wallet_balance'] ?? 0).toDouble(),
    );
  }
}

class FinancialTransaction {
  final String id;
  final double amount;
  final String transactionType;
  final String status;
  final String createdAt;
  final Map<String, dynamic>? user;

  FinancialTransaction({
    required this.id,
    required this.amount,
    required this.transactionType,
    required this.status,
    required this.createdAt,
    this.user,
  });

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'];
    Map<String, dynamic>? formattedUser;
    if (userObj != null) {
      formattedUser = userObj is List ? (userObj.isNotEmpty ? userObj[0] : null) : userObj;
    }

    return FinancialTransaction(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      transactionType: json['transaction_type'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      user: formattedUser,
    );
  }
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String activeTab = "faculty"; // "faculty" | "inflows" | "outflows"
  String searchQuery = "";

  List<TeacherWallet> teachers = [];
  List<FinancialTransaction> studentPayments = [];
  List<FinancialTransaction> payoutHistory = [];

  // Payout Modal State
  TeacherWallet? selectedTeacher;
  double payoutAmount = 0;
  bool isProcessingPayout = false;
  Map<String, String>? message;

  @override
  void initState() {
    super.initState();
    _fetchFinanceData();
  }

  Future<void> _fetchFinanceData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch Teachers Wallets
      final facultyData = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url, wallet_balance")
          .inFilter("role", ["teacher", "super_admin"])
          .order("wallet_balance", ascending: false);

      teachers = (facultyData as List).map((t) => TeacherWallet.fromJson(t)).toList();
    
      // 2. Fetch All Transactions
      final txData = await supabase
          .from("transactions")
          .select("id, amount, transaction_type, status, created_at, user:profiles!student_id(first_name, last_name, email, avatar_url)")
          .order("created_at", ascending: false);

      List<FinancialTransaction> formattedTxs = (txData as List).map((tx) => FinancialTransaction.fromJson(tx)).toList();

      studentPayments = formattedTxs.where((tx) => ["deposit", "payment", "course_fee"].contains(tx.transactionType)).toList();
      payoutHistory = formattedTxs.where((tx) => tx.transactionType == "withdrawal").toList();
    
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error fetching finance data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleProcessPayout() async {
    if (selectedTeacher == null) return;
    if (payoutAmount <= 0 || payoutAmount > selectedTeacher!.walletBalance) {
      setState(() {
        message = {'type': 'error', 'text': 'Invalid payout amount.'};
      });
      return;
    }

    setState(() {
      isProcessingPayout = true;
      message = null;
    });

    try {
      double newBalance = selectedTeacher!.walletBalance - payoutAmount;

      await supabase
          .from("profiles")
          .update({'wallet_balance': newBalance})
          .eq("id", selectedTeacher!.id);

      final newTxData = await supabase
          .from("transactions")
          .insert({
            'student_id': selectedTeacher!.id,
            'amount': -payoutAmount,
            'transaction_type': 'withdrawal',
            'status': 'COMPLETED',
            'reference_id': 'PAYOUT-${DateTime.now().millisecondsSinceEpoch}'
          })
          .select("id, amount, transaction_type, status, created_at, user:profiles!student_id(first_name, last_name, email, avatar_url)")
          .single();

      final newTx = FinancialTransaction.fromJson(newTxData);

      setState(() {
        teachers = teachers.map((t) => t.id == selectedTeacher!.id ? TeacherWallet(id: t.id, firstName: t.firstName, lastName: t.lastName, email: t.email, avatarUrl: t.avatarUrl, walletBalance: newBalance) : t).toList();
        payoutHistory.insert(0, newTx);
        message = {'type': 'success', 'text': 'Successfully paid \$${payoutAmount.toStringAsFixed(2)} to ${selectedTeacher!.firstName}.'};
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            selectedTeacher = null;
            message = null;
            payoutAmount = 0;
          });
        }
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to process payout: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isProcessingPayout = false);
    }
  }

  Map<String, double> get stats {
    double totalGrossRevenue = studentPayments.where((tx) => tx.status == 'COMPLETED').fold(0, (acc, tx) => acc + tx.amount);
    double totalFacultyLiability = teachers.fold(0, (acc, t) => acc + t.walletBalance);
    double totalPayoutsDistributed = payoutHistory.fold(0, (acc, tx) => acc + tx.amount.abs());
    double platformNetProfit = totalGrossRevenue - totalPayoutsDistributed - totalFacultyLiability;

    return {
      'totalGrossRevenue': totalGrossRevenue,
      'totalFacultyLiability': totalFacultyLiability,
      'totalPayoutsDistributed': totalPayoutsDistributed,
      'platformNetProfit': platformNetProfit,
    };
  }

  List<TeacherWallet> get filteredTeachers {
    if (searchQuery.isEmpty) return teachers;
    final query = searchQuery.toLowerCase();
    return teachers.where((t) => t.firstName.toLowerCase().contains(query) || t.lastName.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // This line is fine
            children: [
              CircularProgressIndicator(color: emeraldAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("AUDITING FINANCIAL RECORDS...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentStats = stats;
    final currentTeachers = filteredTeachers;

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
                  BoxShadow(color: emeraldAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
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
                                color: emeraldAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: emeraldAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "FINANCIAL LEDGER",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: emeraldAccent, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.account_balance_wallet_rounded, color: emeraldAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Financial Ledger",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Audit global platform revenue and manage faculty payouts securely.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= METRICS GRID =================
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      _buildMetricCard("Gross Revenue", "\$${currentStats['totalGrossRevenue']!.toStringAsFixed(0)}", Icons.trending_up_rounded, emeraldAccent),
                      _buildMetricCard("Faculty Liability", "\$${currentStats['totalFacultyLiability']!.toStringAsFixed(0)}", Icons.wallet_rounded, Colors.amberAccent),
                      _buildMetricCard("Distributed Payouts", "\$${currentStats['totalPayoutsDistributed']!.toStringAsFixed(0)}", Icons.credit_card_rounded, Colors.blueAccent),
                      _buildMetricCard("Net Profit (Est.)", "\$${currentStats['platformNetProfit']!.toStringAsFixed(0)}", Icons.business_center_rounded, Colors.greenAccent),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ================= TABS NAVIGATION =================
                  Row(
                    children: [
                      Expanded(child: _buildTabButton("Faculty", "faculty")),
                      const SizedBox(width: 6),
                      Expanded(child: _buildTabButton("Inflows", "inflows")),
                      const SizedBox(width: 6),
                      Expanded(child: _buildTabButton("Outflows", "outflows")),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= TAB CONTENTS =================
                  if (activeTab == "faculty") ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => searchQuery = val),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: "Find instructor...",
                                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    currentTeachers.isEmpty
                        ? Container(padding: const EdgeInsets.all(30), alignment: Alignment.center, child: const Text("No instructors found.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentTeachers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final teacher = currentTeachers[index];
                              return _buildGlassCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.black,
                                      backgroundImage: teacher.avatarUrl != null ? NetworkImage(teacher.avatarUrl!) : null,
                                      child: teacher.avatarUrl == null ? Text(teacher.firstName[0], style: const TextStyle(color: emeraldAccent, fontSize: 12)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${teacher.firstName} ${teacher.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), // This line is fine
                                          const SizedBox(height: 2),
                                          Text("\$${teacher.walletBalance.toStringAsFixed(2)} Unpaid", style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: emeraldAccent.withOpacity(0.15),
                                        foregroundColor: emeraldAccent,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: teacher.walletBalance > 0 ? () {
                                        setState(() {
                                          selectedTeacher = teacher;
                                          payoutAmount = teacher.walletBalance;
                                          message = null;
                                        });
                                      } : null,
                                      child: const Text("Settle", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ] else if (activeTab == "inflows") ...[
                    studentPayments.isEmpty
                        ? Container(padding: const EdgeInsets.all(30), alignment: Alignment.center, child: const Text("No payment records found.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: studentPayments.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final tx = studentPayments[index];
                              return _buildGlassCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${tx.user?['first_name'] ?? 'User'} ${tx.user?['last_name'] ?? ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          Text(tx.transactionType.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                    Text("+\$${tx.amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ] else if (activeTab == "outflows") ...[
                    payoutHistory.isEmpty
                        ? Container(padding: const EdgeInsets.all(30), alignment: Alignment.center, child: const Text("No payouts processed yet.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: payoutHistory.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final tx = payoutHistory[index];
                              return _buildGlassCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_upward, color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Paid to: ${tx.user?['first_name'] ?? 'Faculty'} ${tx.user?['last_name'] ?? ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          Text(DateFormatter(tx.createdAt).formatted, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                    Text("-\$${tx.amount.abs().toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Payout Modal
          if (selectedTeacher != null)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (!isProcessingPayout) setState(() => selectedTeacher = null);
                    },
                    child: Container(color: Colors.black.withOpacity(0.8)),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Process Payout: ${selectedTeacher!.firstName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                              GestureDetector(
                                onTap: () {
                                  if (!isProcessingPayout) setState(() => selectedTeacher = null);
                                },
                                child: const Icon(Icons.close, color: Colors.grey, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (message != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: message!['type'] == 'success' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const Text("TRANSFER AMOUNT (USD)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(text: payoutAmount.toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: payoutAmount.toString().length)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              payoutAmount = double.tryParse(val) ?? 0;
                            },
                            style: const TextStyle(color: emeraldAccent, fontSize: 18, fontWeight: FontWeight.w900),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: emeraldAccent, width: 1.5)),
                              prefixText: "\$ ",
                              prefixStyle: const TextStyle(color: emeraldAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom( // This line is fine
                                backgroundColor: emeraldAccent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isProcessingPayout ? null : handleProcessPayout,
                              child: isProcessingPayout
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : const Text("CONFIRM & SETTLE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                            ),
                          ),
                        ],
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

  Widget _buildTabButton(String label, String tabKey) {
    bool isActive = activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => activeTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration( // This line is fine
          color: isActive ? emeraldAccent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10), // This line is fine
          border: Border.all(color: isActive ? emeraldAccent.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isActive ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 1),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }
}

class DateFormatter {
  final String dateStr;
  DateFormatter(this.dateStr);
  String get formatted {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return dateStr;
    }
  }
}