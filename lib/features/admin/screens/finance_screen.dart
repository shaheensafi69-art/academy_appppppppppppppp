import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _fetchFinanceData();
  }

  Future<void> _fetchFinanceData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch Teachers Wallets از جدول profiles
      final facultyData = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url, wallet_balance")
          .inFilter("role", ["teacher", "super_admin", "mentor"])
          .order("wallet_balance", ascending: false);

      teachers = (facultyData as List).map((t) => TeacherWallet.fromJson(t)).toList();
    
      // 2. Fetch All Transactions از جدول transactions
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("AUDITING FINANCIAL RECORDS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentStats = stats;
    final currentTeachers = filteredTeachers;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
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
                          "FINANCIAL LEDGER",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.account_balance_wallet_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Financial Ledger",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Audit global platform revenue and manage faculty payouts securely.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= METRICS GRID =================
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildMetricCard("Gross Revenue", "\$${currentStats['totalGrossRevenue']!.toStringAsFixed(0)}", Icons.trending_up_rounded, Colors.green.shade700),
                _buildMetricCard("Faculty Liability", "\$${currentStats['totalFacultyLiability']!.toStringAsFixed(0)}", Icons.wallet_rounded, Colors.amber.shade800),
                _buildMetricCard("Distributed Payouts", "\$${currentStats['totalPayoutsDistributed']!.toStringAsFixed(0)}", Icons.credit_card_rounded, Colors.indigo),
                _buildMetricCard("Net Profit (Est.)", "\$${currentStats['platformNetProfit']!.toStringAsFixed(0)}", Icons.business_center_rounded, primaryPink),
              ],
            ),
            const SizedBox(height: 24),

            // ================= TABS NAVIGATION =================
            Row(
              children: [
                Expanded(child: _buildTabButton("Faculty", "faculty")),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton("Inflows", "inflows")),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton("Outflows", "outflows")),
              ],
            ),
            const SizedBox(height: 16),

            // ================= TAB CONTENTS =================
            if (activeTab == "faculty") ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cardBorder.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: primaryPink, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => searchQuery = val),
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "Find instructor...",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              currentTeachers.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: const Text("No instructors found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentTeachers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final teacher = currentTeachers[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: lightPinkBg,
                                backgroundImage: teacher.avatarUrl != null ? NetworkImage(teacher.avatarUrl!) : null,
                                child: teacher.avatarUrl == null ? Text(teacher.firstName[0], style: const TextStyle(color: primaryPink, fontSize: 12, fontWeight: FontWeight.bold)) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${teacher.firstName} ${teacher.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text("\$${teacher.walletBalance.toStringAsFixed(2)} Unpaid", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: lightPinkBg,
                                  foregroundColor: primaryPink,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: teacher.walletBalance > 0 ? () {
                                  setState(() {
                                    selectedTeacher = teacher;
                                    payoutAmount = teacher.walletBalance;
                                    message = null;
                                  });
                                } : null,
                                child: const Text("Settle", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ] else if (activeTab == "inflows") ...[
              studentPayments.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: const Text("No payment records found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: studentPayments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = studentPayments[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.arrow_downward_rounded, color: Colors.green.shade700, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${tx.user?['first_name'] ?? 'User'} ${tx.user?['last_name'] ?? ''}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(tx.transactionType.toUpperCase(), style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Text("+\$${tx.amount.toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
            ] else if (activeTab == "outflows") ...[
              payoutHistory.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: const Text("No payouts processed yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payoutHistory.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = payoutHistory[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: primaryPink.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.arrow_upward_rounded, color: primaryPink, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Paid to: ${tx.user?['first_name'] ?? 'Faculty'} ${tx.user?['last_name'] ?? ''}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(DateFormatter(tx.createdAt).formatted, style: const TextStyle(color: textGrey, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Text("-\$${tx.amount.abs().toStringAsFixed(2)}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),

      // Payout Modal Overlay
      bottomSheet: selectedTeacher != null
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Process Payout: ${selectedTeacher!.firstName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                      GestureDetector(
                        onTap: () {
                          if (!isProcessingPayout) setState(() => selectedTeacher = null);
                        },
                        child: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message!['type'] == 'success' ? Colors.green.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: message!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3), width: 1.5),
                      ),
                      child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text("TRANSFER AMOUNT (USD)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: payoutAmount.toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: payoutAmount.toString().length)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      payoutAmount = double.tryParse(val) ?? 0;
                    },
                    style: const TextStyle(color: primaryPink, fontSize: 18, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      prefixText: "\$ ",
                      prefixStyle: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isProcessingPayout ? null : handleProcessPayout,
                      child: isProcessingPayout
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text("CONFIRM & SETTLE 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildTabButton(String label, String tabKey) {
    bool isActive = activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => activeTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? lightPinkBg : cardBorder.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? primaryPink : cardBorder, width: isActive ? 1.5 : 1),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isActive ? primaryPink : textGrey)),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
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
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
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