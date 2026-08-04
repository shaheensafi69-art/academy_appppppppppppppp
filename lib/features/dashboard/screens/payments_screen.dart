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
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // واکشی تراکنش‌های مالی شاگرد از جدول transactions بر اساس student_id
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
    try {
      // بررسی کد تخفیف از جدول coupons
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
      default:
        return Colors.amber.shade800;
    }
  }

  void _showTransactionDetails(TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final statusColor = _getStatusColor(tx.status);
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Transaction Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                  IconButton(
                    icon: const Icon(Icons.close, color: textGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: cardBorder, height: 20),
              _detailRow("Transaction ID:", tx.id),
              const SizedBox(height: 10),
              _detailRow("Type:", tx.transactionType.toUpperCase()),
              const SizedBox(height: 10),
              _detailRow("Amount:", "\$${tx.amount.toStringAsFixed(2)} ${tx.currency}"),
              const SizedBox(height: 10),
              _detailRow("Payment Gateway:", tx.paymentGateway.toUpperCase()),
              const SizedBox(height: 10),
              _detailRow("Reference ID:", tx.referenceId),
              const SizedBox(height: 10),
              _detailRow("Date & Time:", tx.createdAt.replaceFirst('T', ' ').substring(0, 19)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Status:", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(tx.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
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
        Text(label, style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
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
              // هدر صفحه
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: primaryPink, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Payments & Invoices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Track transaction history, receipts, and apply discount coupons.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // بخش اعمال کد تخفیف
              const Text("Discount & Scholarships", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "Enter coupon code...",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: isApplyingCoupon ? null : _applyCoupon,
                      child: isApplyingCoupon
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Apply", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // بخش تاریخچه تراکنش‌ها با تمام جزئیات
              const Text("Transaction History", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
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
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.payment_rounded, color: primaryPink, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tx.transactionType.toUpperCase(), style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text("Gateway: ${tx.paymentGateway}", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 1),
                                            Text(tx.createdAt.split('T')[0], style: const TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text("\$${tx.amount.toStringAsFixed(2)} ${tx.currency}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                          child: Text(tx.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900)),
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
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: const Text("No payment history or transactions found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}