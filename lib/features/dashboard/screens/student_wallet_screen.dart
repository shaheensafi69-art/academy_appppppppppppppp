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
  
  get ascending => null;

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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration( // FIX: Replaced Colors.emerald with Colors.green
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text("💰", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Wallet & Assets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text("Manage digital funds and earn cash bonuses.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                ),
                if (!isLoading && wallet['invitedBy'].isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add, color: Colors.indigoAccent, size: 14),
                        const SizedBox(width: 4),
                        Text("Invited by: ${wallet['invitedBy']}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= ۱. کارت کیف پول (Digital Wallet Card) =================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF16251e), Color(0xFF0a0a0f)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withOpacity(0.3)), // FIX: Replaced Colors.emerald with Colors.green
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("SAFI PAY • VERIFIED NODE", style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const Icon(Icons.credit_card, color: Colors.grey, size: 18),
                  ],
                ),
                const SizedBox(height: 14),
                const Text("AVAILABLE BALANCE", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  "\$${isLoading ? '---' : wallet['balance'].toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              foregroundColor: Colors.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: null,
                            child: const Text("Add Funds", style: TextStyle(fontSize: 10)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: const Text("Coming Soon", style: TextStyle(color: Colors.yellowAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              foregroundColor: Colors.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: null,
                            child: const Text("Withdraw", style: TextStyle(fontSize: 10)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: const Text("Coming Soon", style: TextStyle(color: Colors.yellowAccent, fontSize: 7, fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF261c0a), Color(0xFF0a0a0f)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text("🎁", style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Text("Invite & Earn \$5", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Share your unique link. When your friends register and enroll in their first course, you will instantly receive a \$5 cash bonus!",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10, height: 1.3),
                ),
                const SizedBox(height: 16),

                // کد رفرال
                const Text("YOUR REFERRAL CODE", style: TextStyle(color: Colors.grey, fontSize: 7, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                        child: Text(isLoading ? "..." : wallet['referralCode'], style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: isCodeCopied ? Colors.green : Colors.white.withOpacity(0.1)),
                      icon: Icon(isCodeCopied ? Icons.check : Icons.copy, color: Colors.white, size: 16),
                      onPressed: _copyCode,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // لینک اصلی رفرال
                const Text("YOUR MASTER LINK", style: TextStyle(color: Colors.grey, fontSize: 7, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          isLoading ? "Generating..." : "safiacademy.org/en/register?ref=${wallet['referralCode']}",
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: isLinkCopied ? Colors.green : Colors.white.withOpacity(0.1)),
                      icon: Icon(isLinkCopied ? Icons.check : Icons.copy, color: Colors.white, size: 16),
                      onPressed: _copyLink,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Cash Earned", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("\$${isLoading ? '-' : wallet['totalRewards'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ================= ۳. سوییچ بین تب‌ها (Network / Transactions) =================
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => activeTab = "referrals"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeTab == "referrals" ? Colors.amber.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: activeTab == "referrals" ? Colors.amber.withOpacity(0.4) : Colors.transparent),
                    ),
                    child: Text("Network", style: TextStyle(color: activeTab == "referrals" ? Colors.amberAccent : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => activeTab = "transactions"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeTab == "transactions" ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: activeTab == "transactions" ? Colors.white.withOpacity(0.2) : Colors.transparent),
                    ),
                    child: Text("Transactions", style: TextStyle(color: activeTab == "transactions" ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ================= ۴. لیست محتوای تب فعال =================
          isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : activeTab == "referrals"
                  ? (referrals.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: referrals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final ref = referrals[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0a0a0f),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        alignment: Alignment.center,
                                        child: Text(ref.referredName.isNotEmpty ? ref.referredName[0] : "U", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ref.referredName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          Text("Joined: ${ref.createdAt.split('T')[0]}", style: const TextStyle(color: Colors.grey, fontSize: 8)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("\$${ref.rewardAmount.toStringAsFixed(2)}", style: TextStyle(color: ref.isPaid ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.w900, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: ref.isPaid ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                                        child: Text(ref.isPaid ? "Reward Paid" : "Awaiting Enrollment", style: TextStyle(color: ref.isPaid ? Colors.greenAccent : Colors.grey, fontSize: 7, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: const Color(0xFF0a0a0f), borderRadius: BorderRadius.circular(18)),
                          child: const Text("Network is Empty. Share your link to earn cash bonuses.", style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                        ))
                  : (transactions.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            bool isPositive = tx.transactionType == 'DEPOSIT' || tx.transactionType == 'REFERRAL_REWARD';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0a0a0f),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                                        child: Text(isPositive ? "↓" : "↑", style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(tx.transactionType.replaceAll("_", " "), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          Text(tx.createdAt.split('T')[0], style: const TextStyle(color: Colors.grey, fontSize: 8)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("${isPositive ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}", style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text(tx.status, style: const TextStyle(color: Colors.grey, fontSize: 7, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: const Color(0xFF0a0a0f), borderRadius: BorderRadius.circular(18)),
                          child: const Text("No Transactions Found.", style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                        )),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}