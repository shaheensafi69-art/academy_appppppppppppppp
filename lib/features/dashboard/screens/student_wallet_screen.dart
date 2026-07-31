import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionItem {
  final String id;
  final double amount;
  final String currency;
  final String transactionType; // "DEPOSIT" | "WITHDRAWAL" | "PURCHASE" | "REFERRAL_REWARD"
  final String status; // "COMPLETED" | "PENDING" | "FAILED"
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
      id: json['id'] ?? '',
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
    'referralCode': 'Generating...',
    'totalRewards': 0.0,
    'invitedBy': '',
  };

  List<TransactionItem> transactions = [];
  List<ReferralItem> referrals = [];

  bool isLinkCopied = false;
  bool isCodeCopied = false;

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
      if (profile != null && profile['referred_by'] != null) {
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

      if (profile != null) {
        if (backupRefData != null && (backupRefData as List).isNotEmpty) {
          final studentIds = backupRefData.map((ref) => ref['referred_student_id']).where((id) => id != null).toList();

          Map<String, String> profilesMap = {};
          if (studentIds.isNotEmpty) {
            final profilesData = await supabase
                .from("profiles")
                .select("id, first_name, last_name")
                .inFilter("id", studentIds);

            if (profilesData != null) {
              for (var p in (profilesData as List)) {
                profilesMap[p['id']] = "${p['first_name']} ${p['last_name']}";
              }
            }
          }

          for (var ref in (backupRefData as List)) {
            final amt = (ref['reward_amount'] ?? 0).toDouble();
            totalRefRewards += amt;
            formattedRefs.add(ReferralItem(
              id: ref['id'] ?? '',
              rewardAmount: amt,
              isPaid: ref['is_paid'] ?? false,
              createdAt: ref['created_at'] ?? '',
              referredName: profilesMap[ref['referred_student_id']] ?? 'Unknown Student',
            ));
          }
        }

        setState(() {
          wallet = {
            'balance': (profile['wallet_balance'] ?? 0).toDouble(),
            'referralCode': profile['referral_code'] ?? 'SAFI-...',
            'totalRewards': totalRefRewards,
            'invitedBy': invitedByName,
          };
          transactions = (txData as List?)?.map((t) => TransactionItem.fromJson(t)).toList() ?? [];
          referrals = formattedRefs;
        });
      }
    } catch (e) {
      debugPrint("Error fetching wallet data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: wallet['referralCode']));
    setState(() => isCodeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => isCodeCopied = false);
    });
  }

  void _copyLink() {
    final inviteLink = "https://safiacademy.org/en/register?ref=${wallet['referralCode']}";
    Clipboard.setData(ClipboardData(text: inviteLink));
    setState(() => isLinkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => isLinkCopied = false);
    });
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
              Text("LOADING WALLET...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
            // ================= هدر صفحه =================
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: lightPinkBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: primaryPink, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Wallet & Assets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                              SizedBox(height: 3),
                              Text("Manage digital funds and earn cash bonuses.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wallet['invitedBy'].isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_add_rounded, color: primaryPink, size: 14),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 80),
                            child: Text(
                              wallet['invitedBy'],
                              style: const TextStyle(color: textDark, fontSize: 9, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ۱. کارت کیف پول (Digital Wallet Card) =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("SAFI PAY • VERIFIED NODE", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      Icon(Icons.credit_card_rounded, color: textGrey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text("AVAILABLE BALANCE", style: TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(
                    "\$${wallet['balance'].toStringAsFixed(2)}",
                    style: TextStyle(color: Colors.green.shade700, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cardBorder,
                                foregroundColor: textGrey,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: null,
                              child: const Text("Add Funds", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: primaryPink.withOpacity(0.2))),
                              child: const Text("Coming Soon", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cardBorder,
                                foregroundColor: textGrey,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: null,
                              child: const Text("Withdraw", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: primaryPink.withOpacity(0.2))),
                              child: const Text("Coming Soon", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ۲. کارت معرفی و کسب درآمد (Invite & Earn) =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: primaryPink, size: 22),
                      SizedBox(width: 10),
                      Text("Invite & Earn \$5", style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Share your unique link. When your friends register and enroll in their first course, you will instantly receive a \$5 cash bonus!",
                    style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                  const SizedBox(height: 18),

                  // کد رفرال
                  const Text("YOUR REFERRAL CODE", style: TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cardBorder.withOpacity(0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.5)),
                          child: Text(wallet['referralCode'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'monospace')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isCodeCopied ? Colors.green : lightPinkBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: Icon(isCodeCopied ? Icons.check_rounded : Icons.copy_rounded, color: isCodeCopied ? Colors.white : primaryPink, size: 18),
                        onPressed: _copyCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // لینک اصلی رفرال
                  const Text("YOUR MASTER LINK", style: TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cardBorder.withOpacity(0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.5)),
                          child: Text(
                            "safiacademy.org/en/register?ref=${wallet['referralCode']}",
                            style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isLinkCopied ? Colors.green : lightPinkBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: Icon(isLinkCopied ? Icons.check_rounded : Icons.copy_rounded, color: isLinkCopied ? Colors.white : primaryPink, size: 18),
                        onPressed: _copyLink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Cash Earned", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("\$${wallet['totalRewards'].toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade700, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= ۳. سوییچ بین تب‌ها (Network / Transactions) =================
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBorder,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => activeTab = "referrals"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activeTab == "referrals" ? surfaceWhite : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: activeTab == "referrals" ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : [],
                        ),
                        child: Text("Network", style: TextStyle(color: activeTab == "referrals" ? primaryPink : textGrey, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => activeTab = "transactions"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activeTab == "transactions" ? surfaceWhite : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: activeTab == "transactions" ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : [],
                        ),
                        child: Text("Transactions", style: TextStyle(color: activeTab == "transactions" ? primaryPink : textGrey, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= ۴. لیست محتوای تب فعال =================
            activeTab == "referrals"
                ? (referrals.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: referrals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ref = referrals[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(14)),
                                        alignment: Alignment.center,
                                        child: Text(ref.referredName.isNotEmpty ? ref.referredName[0] : "U", style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 16)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(ref.referredName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text("Joined: ${ref.createdAt.split('T')[0]}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("\$${ref.rewardAmount.toStringAsFixed(2)}", style: TextStyle(color: ref.isPaid ? Colors.green.shade700 : textGrey, fontWeight: FontWeight.w900, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ref.isPaid ? Colors.green.withOpacity(0.12) : cardBorder,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ref.isPaid ? "Reward Paid" : "Awaiting",
                                        style: TextStyle(color: ref.isPaid ? Colors.green.shade700 : textGrey, fontSize: 9, fontWeight: FontWeight.w900),
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
                        child: const Text("Network is Empty. Share your link to earn cash bonuses.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ))
                : (transactions.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          bool isPositive = tx.transactionType == 'DEPOSIT' || tx.transactionType == 'REFERRAL_REWARD';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                        child: Icon(isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: primaryPink, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tx.transactionType.replaceAll("_", " "), style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text(tx.createdAt.split('T')[0], style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${isPositive ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}",
                                      style: TextStyle(color: isPositive ? Colors.green.shade700 : textDark, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                      child: Text(tx.status, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
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
                        child: const Text("No Transactions Found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}