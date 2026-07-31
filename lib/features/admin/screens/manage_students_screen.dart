import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;
  final double walletBalance;
  final int totalScore;
  final String createdAt;

  StudentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
    required this.walletBalance,
    required this.totalScore,
    required this.createdAt,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      walletBalance: (json['wallet_balance'] ?? 0).toDouble(),
      totalScore: json['total_score'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final supabase = Supabase.instance.client;
  
  bool isLoading = true;
  List<StudentProfile> students = [];
  String searchQuery = "";

  // استیت‌های مودال ویرایش کیف پول
  StudentProfile? selectedStudent;
  double newWalletBalance = 0;
  bool isSaving = false;
  String? messageText;
  bool isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url, wallet_balance, total_score, created_at")
          .eq("role", "student")
          .order("created_at", ascending: false);

      final List<StudentProfile> loadedStudents = (response as List)
          .map((item) => StudentProfile.fromJson(item))
          .toList();

      if (mounted) {
        setState(() {
          students = loadedStudents;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<StudentProfile> get filteredStudents {
    if (searchQuery.isEmpty) return students;
    final query = searchQuery.toLowerCase();
    return students.where((s) =>
      s.firstName.toLowerCase().contains(query) ||
      s.lastName.toLowerCase().contains(query) ||
      s.email.toLowerCase().contains(query)
    ).toList();
  }

  Map<String, dynamic> get stats {
    final total = students.length;
    double totalWalletFunds = 0;
    int totalPoints = 0;
    for (var s in students) {
      totalWalletFunds += s.walletBalance;
      totalPoints += s.totalScore;
    }
    return {'total': total, 'totalWalletFunds': totalWalletFunds, 'totalPoints': totalPoints};
  }

  void openEditModal(StudentProfile student) {
    setState(() {
      selectedStudent = student;
      newWalletBalance = student.walletBalance;
      messageText = null;
    });
  }

  Future<void> handleUpdateWallet() async {
    if (selectedStudent == null) return;

    setState(() {
      isSaving = true;
      messageText = null;
    });

    try {
      await supabase
          .from("profiles")
          .update({'wallet_balance': newWalletBalance})
          .eq("id", selectedStudent!.id);

      // آپدیت لیست در حافظه محلی
      setState(() {
        students = students.map((s) {
          if (s.id == selectedStudent!.id) {
            return StudentProfile(
              id: s.id,
              firstName: s.firstName,
              lastName: s.lastName,
              email: s.email,
              avatarUrl: s.avatarUrl,
              walletBalance: newWalletBalance,
              totalScore: s.totalScore,
              createdAt: s.createdAt,
            );
          }
          return s;
        }).toList();

        messageText = 'Wallet balance updated successfully!';
        isSuccessMessage = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            selectedStudent = null;
            messageText = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        messageText = 'Failed to update wallet: ${e.toString()}';
        isSuccessMessage = false;
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
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
              CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text(
                "LOADING STUDENT RECORDS...",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredStudents;
    final currentStats = stats;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          // Background Ambience (Emerald / Teal Glow)
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.tealAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
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
                                color: Colors.tealAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "STUDENT REGISTRY",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.tealAccent, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.people_alt_rounded, color: Colors.tealAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Manage Students",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Monitor points and manage digital wallet balances globally.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _buildMiniStat("Total Students", currentStats['total'].toString(), Icons.group_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMiniStat("Total Funds", "\$${(currentStats['totalWalletFunds'] as double).toInt()}", Icons.account_balance_wallet_rounded)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ================= SEARCH BAR =================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0a0a0f).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => searchQuery = val),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "Search by name or email...",
                              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= STUDENTS LIST (Vertical Mobile Cards) =================
                  currentFiltered.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_rounded, color: Colors.grey, size: 36),
                              const SizedBox(height: 10),
                              Text("No students found.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentFiltered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final student = currentFiltered[index];
                            return _buildGlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.black,
                                        backgroundImage: student.avatarUrl != null && student.avatarUrl!.isNotEmpty
                                            ? NetworkImage(student.avatarUrl!)
                                            : null,
                                        child: (student.avatarUrl == null || student.avatarUrl!.isEmpty)
                                            ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold))
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("${student.firstName} ${student.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                            const SizedBox(height: 2),
                                            Text(student.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white10, height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("WALLET BALANCE", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                          const SizedBox(height: 2),
                                          Text("\$${student.walletBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w900, fontSize: 15)),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.tealAccent.withOpacity(0.1),
                                          foregroundColor: Colors.tealAccent,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: Colors.tealAccent.withOpacity(0.2)),
                                        ),
                                        icon: const Icon(Icons.edit_outlined, size: 14),
                                        label: const Text("Edit Wallet", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                        onPressed: () => openEditModal(student),
                                      ),
                                    ],
                                  )
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

          // ================= MODAL: EDIT WALLET =================
          if (selectedStudent != null)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (!isSaving) setState(() => selectedStudent = null);
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
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, spreadRadius: 10),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Edit Student Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              GestureDetector(
                                onTap: () {
                                  if (!isSaving) setState(() => selectedStudent = null);
                                },
                                child: const Icon(Icons.close, color: Colors.grey, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("${selectedStudent!.firstName} ${selectedStudent!.lastName}", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
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

                          const Text("NEW BALANCE (USD)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(text: newWalletBalance.toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: newWalletBalance.toString().length)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              newWalletBalance = double.tryParse(val) ?? 0;
                            },
                            style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.w900),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.tealAccent, width: 1.5)),
                              prefixText: "\$ ",
                              prefixStyle: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving ? null : handleUpdateWallet,
                              child: isSaving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
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
          Icon(icon, color: Colors.tealAccent, size: 18),
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