import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionItem {
  final String id;
  final double amount;
  final String currency;
  final String transactionType;
  final String status;
  final String paymentGateway;
  final String referenceId;
  final String createdAt;

  TransactionItem({
    required this.id,
    required this.amount,
    required this.currency,
    required this.transactionType,
    required this.status,
    required this.paymentGateway,
    required this.referenceId,
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      transactionType: json['transaction_type'] ?? 'payment',
      status: json['status'] ?? 'pending',
      paymentGateway: json['payment_gateway'] ?? 'manual',
      referenceId: json['reference_id']?.toString() ?? 'N/A',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isApplyingCoupon = false;
  List<TransactionItem> transactions = [];
  
  final TextEditingController _couponController = TextEditingController();
  final FocusNode _couponFocus = FocusNode();

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _couponFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final res = await supabase
          .from("transactions")
          .select("*")
          .eq("student_id", user.id)
          .order("created_at", ascending: false);

      transactions = (res as List).map((t) => TransactionItem.fromJson(t)).toList();
    } catch (e) {
      debugPrint("Error fetching transactions: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => isApplyingCoupon = true);
    _couponFocus.unfocus(); // بستن کیبورد

    try {
      final res = await supabase
          .from("coupons")
          .select("*")
          .eq("code", code)
          .maybeSingle();

      if (res != null) {
        final discount = res['discount_percentage'] ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Coupon applied successfully! $discount% discount unlocked. 🎉"), backgroundColor: Colors.green),
          );
          _couponController.clear();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid or expired coupon code. ❌"), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      debugPrint("Error applying coupon: $e");
    } finally {
      if (mounted) setState(() => isApplyingCoupon = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return Colors.green;
      case 'failed':
      case 'cancelled':
        return Colors.redAccent;
      case 'pending':
      case 'processing':
        return Colors.amber.shade800;
      default:
        return textGrey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return Icons.arrow_downward_rounded;
      case 'withdrawal':
        return Icons.arrow_upward_rounded;
      case 'refund':
        return Icons.settings_backup_restore_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  // نمایش رسید دیجیتال بسیار حرفه‌ای
  void _showTransactionDetails(TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final statusColor = _getStatusColor(tx.status);
        return Container(
          decoration: const BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              // هدر رسید
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_getTransactionIcon(tx.transactionType), color: statusColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text("\$${tx.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -1)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(tx.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const SizedBox(height: 24),
              
              // خط چین
              Row(
                children: List.generate(30, (index) => Expanded(
                  child: Container(color: index % 2 == 0 ? Colors.transparent : cardBorder, height: 2),
                )),
              ),
              const SizedBox(height: 24),

              // جزئیات
              _detailRow("Transaction ID", tx.id),
              const SizedBox(height: 16),
              _detailRow("Type", tx.transactionType.toUpperCase()),
              const SizedBox(height: 16),
              _detailRow("Gateway", tx.paymentGateway.toUpperCase()),
              const SizedBox(height: 16),
              _detailRow("Reference", tx.referenceId),
              const SizedBox(height: 16),
              _detailRow("Date & Time", tx.createdAt.replaceFirst('T', ' ').substring(0, 16)),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cardBorder,
                    foregroundColor: textDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CLOSE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- هدر صفحه ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: primaryPink.withOpacity(0.06), blurRadius: 25, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: primaryPink, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Payments & Invoices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                          SizedBox(height: 4),
                          Text("Track transaction history, receipts, and apply discount coupons.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- بخش اعمال کد تخفیف ---
              const Text("Discount & Scholarships", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        focusNode: _couponFocus,
                        cursorColor: primaryPink,
                        // رنگ تیره اجباری برای خوانایی در حالت لایت‌مود
                        style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          hintText: "Enter coupon code...",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: isApplyingCoupon ? null : _applyCoupon,
                      child: isApplyingCoupon
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Apply", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- بخش تاریخچه تراکنش‌ها ---
              const Text("Transaction History", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 3)))
                  : transactions.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final statusColor = _getStatusColor(tx.status);
                            return GestureDetector(
                              onTap: () => _showTransactionDetails(tx),
                              child: Container(
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
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(14)),
                                          child: Icon(_getTransactionIcon(tx.transactionType), color: primaryPink, size: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tx.transactionType.toUpperCase(), style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text("Gateway: ${tx.paymentGateway}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(tx.createdAt.split('T')[0], style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text("\$${tx.amount.toStringAsFixed(2)}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                          child: Text(tx.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.all(50),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: textGrey),
                              SizedBox(height: 12),
                              Text("No payment history found.", style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
              const SizedBox(height: 80), // فاصله برای Bottom Nav
            ],
          ),
        ),
      ),
    );
  }
}