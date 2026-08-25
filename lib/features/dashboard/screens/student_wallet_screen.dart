import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionItem {
  final String id;
  final double amount;
  final String currency;
  final String transactionType; 
  final String status; 
  final String createdAt;

  TransactionItem({
    required this.id,
    required this.amount,
    required this.currency,
    required this.transactionType,
    required this.status,
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      transactionType: json['transaction_type'] ?? 'DEPOSIT',
      status: json['status'] ?? 'COMPLETED',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class ReferralItem {
  final String id;
  final double rewardAmount;
  final bool isPaid;
  final String createdAt;
  final String referredName;

  ReferralItem({
    required this.id,
    required this.rewardAmount,
    required this.isPaid,
    required this.createdAt,
    required this.referredName,
  });
}

class StudentWalletScreen extends StatefulWidget {
  const StudentWalletScreen({super.key});

  @override
  State<StudentWalletScreen> createState() => _StudentWalletScreenState();
}

class _StudentWalletScreenState extends State<StudentWalletScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String activeTab = "referrals"; // "referrals" or "transactions"

  Map<String, dynamic> wallet = {
    'balance': 0.0,
    'referralCode': '...',
    'totalRewards': 0.0,
    'invitedBy': '',
  };

  List<TransactionItem> transactions = [];
  List<ReferralItem> referrals = [];

  bool isLinkCopied = false;
  bool isCodeCopied = false;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // ۱. واکشی اطلاعات پروفایل
      final profile = await supabase
          .from("profiles")
          .select("wallet_balance, referral_code, referred_by")
          .eq("id", userId)
          .single();

      String invitedByName = "";
      if (profile['referred_by'] != null) {
        final referrerData = await supabase
            .from("profiles")
            .select("first_name, last_name")
            .eq("id", profile['referred_by'])
            .maybeSingle();

        if (referrerData != null) {
          invitedByName = "${referrerData['first_name']} ${referrerData['last_name']}";
        }
      }

      // ۲. واکشی تراکنش‌ها
      final txData = await supabase
          .from("transactions")
          .select("*")
          .eq("student_id", userId)
          .order("created_at", ascending: false);

      // ۳. واکشی رفرال‌ها
      final backupRefData = await supabase
          .from("referrals")
          .select("id, reward_amount, is_paid, created_at, referred_student_id")
          .eq("referrer_id", userId)
          .order("created_at", ascending: false);

      double totalRefRewards = 0;
      List<ReferralItem> formattedRefs = [];

      if ((backupRefData as List).isNotEmpty) {
        // لیست شناسه‌های دانشجویان دعوت شده (بدون مقادیر نال)
        final studentIds = backupRefData
            .map((ref) => ref['referred_student_id'])
            .where((id) => id != null)
            .toList();

        Map<String, String> profilesMap = {};
        if (studentIds.isNotEmpty) {
          // استفاده از in_ برای واکشی گروهی پروفایل‌ها
          final profilesData = await supabase
              .from("profiles")
              .select("id, first_name, last_name")
              .inFilter("id", studentIds);

          for (var p in (profilesData as List)) {
            profilesMap[p['id'].toString()] = "${p['first_name']} ${p['last_name']}";
          }
        }

        for (var ref in (backupRefData as List)) {
          final amt = (ref['reward_amount'] ?? 0).toDouble();
          totalRefRewards += amt;
          formattedRefs.add(ReferralItem(
            id: ref['id']?.toString() ?? '',
            rewardAmount: amt,
            isPaid: ref['is_paid'] ?? false,
            createdAt: ref['created_at']?.toString() ?? '',
            referredName: profilesMap[ref['referred_student_id']?.toString()] ?? 'Student',
          ));
        }
      }

      if (mounted) {
        setState(() {
          wallet = {
            'balance': (profile['wallet_balance'] ?? 0).toDouble(),
            'referralCode': profile['referral_code'] ?? 'Generating...',
            'totalRewards': totalRefRewards,
            'invitedBy': invitedByName,
          };
          transactions = (txData as List?)?.map((t) => TransactionItem.fromJson(t)).toList() ?? [];
          referrals = formattedRefs;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching wallet data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: wallet['referralCode']));
    setState(() => isCodeCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral code copied!"), backgroundColor: Colors.green));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => isCodeCopied = false);
    });
  }

  void _copyLink() {
    final inviteLink = "https://safiacademy.org/en/register?ref=${wallet['referralCode']}";
    Clipboard.setData(ClipboardData(text: inviteLink));
    setState(() => isLinkCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite link copied to clipboard!"), backgroundColor: Colors.green));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => isLinkCopied = false);
    });
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature feature is coming soon! 🚀"), backgroundColor: primaryPink),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return Colors.amber.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AcademyLoadingOverlay(
      isLoading: isLoading,
      message: "SYNCING DIGITAL WALLET...",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          centerTitle: true,
          title: const Text("Wallet & Referral", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
          iconTheme: const IconThemeData(color: textDark),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5).withOpacity(0.5), surfaceWhite],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= ۱. کارت کیف پول دیجیتال (Digital Wallet Card) =================
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF494AC), Color(0xFF880E4F)], // گرادینت شیک کارت بانکی
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(color: primaryPink.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("SAFI PAY • STUDENT NODE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text("AVAILABLE BALANCE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              "\$${wallet['balance'].toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.15),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: () => _showComingSoon("Add Funds"),
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    label: const Text("Add Funds", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: primaryPink,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: () => _showComingSoon("Withdraw"),
                                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                                    label: const Text("Withdraw", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= ۲. کارت معرفی و کسب درآمد (Invite & Earn) =================
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.card_giftcard_rounded, color: primaryPink, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: Text("Invite Friends & Earn \$5", style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Share your unique link. When your friends register and enroll in their first course, you will instantly receive a \$5 cash bonus to your wallet!",
                              style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
                            ),
                            const SizedBox(height: 24),

                            // کد رفرال
                            const Text("YOUR REFERRAL CODE", style: TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: cardBorder.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder, width: 1.5)),
                                    child: Text(wallet['referralCode'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'monospace')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: isCodeCopied ? Colors.green : lightPinkBg,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.all(14),
                                  ),
                                  icon: Icon(isCodeCopied ? Icons.check_rounded : Icons.copy_rounded, color: isCodeCopied ? Colors.white : primaryPink, size: 20),
                                  onPressed: _copyCode,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // لینک اصلی رفرال
                            const Text("YOUR MASTER LINK", style: TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: cardBorder.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder, width: 1.5)),
                                    child: Text(
                                      "safiacademy.org/en/register?ref=${wallet['referralCode']}",
                                      style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: isLinkCopied ? Colors.green : lightPinkBg,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.all(14),
                                  ),
                                  icon: Icon(isLinkCopied ? Icons.check_rounded : Icons.copy_rounded, color: isLinkCopied ? Colors.white : primaryPink, size: 20),
                                  onPressed: _copyLink,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(color: cardBorder, height: 1, thickness: 1.5),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Total Cash Earned:", style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                                Text("\$${wallet['totalRewards'].toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade700, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            if (wallet['invitedBy'].isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.person_add_rounded, color: textGrey, size: 14),
                                  const SizedBox(width: 6),
                                  Text("You were invited by: ", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                                  Text(wallet['invitedBy'], style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ================= ۳. سوییچ بین تب‌ها (Network / Transactions) =================
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cardBorder,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => activeTab = "referrals"),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: activeTab == "referrals" ? surfaceWhite : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: activeTab == "referrals" ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : [],
                                  ),
                                  child: Text("Referral Network", style: TextStyle(color: activeTab == "referrals" ? primaryPink : textGrey, fontSize: 12, fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => activeTab = "transactions"),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: activeTab == "transactions" ? surfaceWhite : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: activeTab == "transactions" ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : [],
                                  ),
                                  child: Text("Transactions", style: TextStyle(color: activeTab == "transactions" ? primaryPink : textGrey, fontSize: 12, fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= ۴. لیست محتوای تب فعال =================
                      activeTab == "referrals"
                          ? (referrals.isNotEmpty
                              ? ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: referrals.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final ref = referrals[index];
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: surfaceWhite,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: cardBorder, width: 1.5),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: lightPinkBg,
                                                  child: Text(ref.referredName.isNotEmpty ? ref.referredName[0] : "U", style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 16)),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(ref.referredName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 4),
                                                      Text("Joined: ${ref.createdAt.split('T')[0]}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                                "+\$${ref.rewardAmount.toStringAsFixed(2)}",
                                                style: TextStyle(color: ref.isPaid ? Colors.green.shade700 : textGrey, fontWeight: FontWeight.w900, fontSize: 16),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: ref.isPaid ? Colors.green.withOpacity(0.12) : cardBorder,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  ref.isPaid ? "REWARD PAID" : "AWAITING",
                                                  style: TextStyle(color: ref.isPaid ? Colors.green.shade700 : textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : _buildEmptyState(Icons.people_outline_rounded, "Network is Empty", "Share your link to invite friends and earn cash bonuses."))
                          : (transactions.isNotEmpty
                              ? ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: transactions.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final tx = transactions[index];
                                    // تشخیص نوع تراکنش برای آیکون و رنگ (برداشت یا واریز)
                                    bool isPositive = tx.transactionType.toUpperCase() == 'DEPOSIT' || tx.transactionType.toUpperCase() == 'REFERRAL_REWARD';
                                    Color statusColor = _getStatusColor(tx.status);

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: surfaceWhite,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: cardBorder, width: 1.5),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(color: isPositive ? Colors.green.withOpacity(0.1) : cardBorder, borderRadius: BorderRadius.circular(14)),
                                                  child: Icon(isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isPositive ? Colors.green.shade700 : textDark, size: 20),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(tx.transactionType.replaceAll("_", " "), style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 4),
                                                      Text(tx.createdAt.split('T')[0], style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                                "${isPositive ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}",
                                                style: TextStyle(color: isPositive ? Colors.green.shade700 : textDark, fontWeight: FontWeight.w900, fontSize: 16),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                                child: Text(tx.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : _buildEmptyState(Icons.receipt_long_outlined, "No Transactions", "You don't have any financial transactions yet.")),
                      const SizedBox(height: 80),
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

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: textGrey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ============================================================================
// ویجت کاستوم لودینگ آکادمی
// ============================================================================
class AcademyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AcademyLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = "LOADING...",
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withOpacity(0.95),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFF494AC), strokeWidth: 3),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}