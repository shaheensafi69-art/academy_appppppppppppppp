import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherDetailScreen extends StatefulWidget {
  final String teacherId;
  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  Map<String, dynamic>? teacher;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> payouts = [];
  int totalStudents = 0;

  // مودال تسویه حساب
  bool isPayoutModalOpen = false;
  double payoutAmount = 0;
  bool isProcessingPayout = false;
  String? messageText;
  bool isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _fetchTeacherData();
  }

  Future<void> _fetchTeacherData() async {
    setState(() => isLoading = true);
    try {
      // ۱. اطلاعات پروفایل استاد
      final profileData = await supabase
          .from("profiles")
          .select("*")
          .eq("id", widget.teacherId)
          .single();

      // ۲. کلاس‌های استاد
      final classesData = await supabase
          .from("class_groups")
          .select("id, class_name, is_active, course:courses(title), class_students(student_id)")
          .eq("teacher_id", widget.teacherId);

      Set uniqueStudents = {};
      List<Map<String, dynamic>> formattedClasses = [];

      for (var cls in (classesData as List)) {
        if (cls['class_students'] != null) {
          for (var cs in (cls['class_students'] as List)) {
            uniqueStudents.add(cs['student_id']);
          }
        }
        formattedClasses.add({
          'id': cls['id'],
          'class_name': cls['class_name'],
          'is_active': cls['is_active'],
          'students_count': (cls['class_students'] as List?)?.length ?? 0,
          'course_title': cls['course'] != null ? (cls['course'] is List ? cls['course'][0]['title'] : cls['course']['title']) : 'General'
        });
      }
    
      // ۳. تاریخچه پرداختی‌ها
      final transactionsData = await supabase
          .from("transactions")
          .select("id, amount, status, created_at")
          .eq("student_id", widget.teacherId)
          .eq("transaction_type", "withdrawal")
          .order("created_at", ascending: false);

      if (mounted) {
        setState(() {
          teacher = profileData;
          classes = formattedClasses;
          totalStudents = uniqueStudents.length;
          payouts = (transactionsData as List?)?.cast<Map<String, dynamic>>() ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching teacher details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleProcessPayout() async {
    if (teacher == null) return;
    double currentBalance = (teacher!['wallet_balance'] ?? 0).toDouble();

    if (payoutAmount <= 0 || payoutAmount > currentBalance) {
      setState(() {
        messageText = 'Invalid payout amount.';
        isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      isProcessingPayout = true;
      messageText = null;
    });

    try {
      double newBalance = currentBalance - payoutAmount;

      await supabase
          .from("profiles")
          .update({'wallet_balance': newBalance})
          .eq("id", widget.teacherId);

      await supabase.from("transactions").insert({
        'student_id': widget.teacherId,
        'amount': -payoutAmount,
        'transaction_type': 'withdrawal',
        'status': 'COMPLETED',
        'reference_id': 'PAYOUT-${DateTime.now().millisecondsSinceEpoch}'
      });

      setState(() {
        teacher!['wallet_balance'] = newBalance;
        payouts.insert(0, {
          'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
          'amount': -payoutAmount,
          'status': 'COMPLETED',
          'created_at': DateTime.now().toIso8601String(),
        });
        messageText = 'Payout successfully processed!';
        isSuccessMessage = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            isPayoutModalOpen = false;
            messageText = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        messageText = 'Failed to process payout: ${e.toString()}';
        isSuccessMessage = false;
      });
    } finally {
      if (mounted) setState(() => isProcessingPayout = false);
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
              const CircularProgressIndicator(color: Colors.indigoAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING INSTRUCTOR DATA...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (teacher == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              const Text("Instructor Not Found", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back")),
            ],
          ),
        ),
      );
    }

    double walletBalance = (teacher!['wallet_balance'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.indigoAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
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
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                          SizedBox(width: 6),
                          Text("Back to Faculty", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Profile Header Card
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.black,
                          backgroundImage: teacher!['avatar_url'] != null && teacher!['avatar_url'].toString().isNotEmpty
                              ? NetworkImage(teacher!['avatar_url'])
                              : null,
                          child: (teacher!['avatar_url'] == null || teacher!['avatar_url'].toString().isEmpty)
                              ? Text(teacher!['first_name'][0], style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 20))
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${teacher!['first_name']} ${teacher!['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(teacher!['email'], style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metrics
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat("Classes", classes.length.toString(), Icons.menu_book)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMiniStat("Students", totalStudents.toString(), Icons.group)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Wallet & Payout Card
                  _buildGlassCard(
                    borderColor: Colors.greenAccent.withOpacity(0.2),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("WALLET BALANCE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("\$${walletBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.w900)),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: walletBalance > 0 ? () {
                                setState(() {
                                  payoutAmount = walletBalance;
                                  messageText = null;
                                  isPayoutModalOpen = true;
                                });
                              } : null,
                              child: const Text("Process Payout", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Assigned Classes Section
                  const Text("ASSIGNED COHORTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  classes.isEmpty
                      ? Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, child: const Text("No assigned classes.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: classes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final cls = classes[index];
                            return _buildGlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cls['class_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text("Course: ${cls['course_title']}", style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                    ],
                                  ),
                                  Text("${cls['students_count']} Students", style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Payout Modal
          if (isPayoutModalOpen)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (!isProcessingPayout) setState(() => isPayoutModalOpen = false);
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
                              const Text("Process Instructor Payout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              GestureDetector(
                                onTap: () {
                                  if (!isProcessingPayout) setState(() => isPayoutModalOpen = false);
                                },
                                child: const Icon(Icons.close, color: Colors.grey, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (messageText != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSuccessMessage ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSuccessMessage ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(isSuccessMessage ? Icons.check_circle : Icons.error, color: isSuccessMessage ? Colors.greenAccent : Colors.redAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const Text("PAYOUT AMOUNT (USD)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(text: payoutAmount.toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: payoutAmount.toString().length)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              payoutAmount = double.tryParse(val) ?? 0;
                            },
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.w900),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.greenAccent, width: 1.5)),
                              prefixText: "\$ ",
                              prefixStyle: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom( // Changed from emeraldAccent
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isProcessingPayout ? null : handleProcessPayout,
                              child: isProcessingPayout
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : const Text("CONFIRM & SETTLE PAYOUT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
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

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigoAccent, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}