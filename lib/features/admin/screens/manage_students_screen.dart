import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_detail_profile_screen.dart'; // فایل جدید مدیریت پروفایل

class StudentProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? bio;
  final String? avatarUrl;
  final double walletBalance;
  final int totalScore;
  final String role;
  final String createdAt;

  StudentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.bio,
    this.avatarUrl,
    required this.walletBalance,
    required this.totalScore,
    required this.role,
    required this.createdAt,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'],
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
      walletBalance: (json['wallet_balance'] ?? 0).toDouble(),
      totalScore: json['total_score'] ?? 0,
      role: json['role'] ?? 'student',
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
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, phone_number, bio, avatar_url, wallet_balance, total_score, role, created_at")
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
              Text("LOADING STUDENT RECORDS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredStudents;
    final currentStats = stats;

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
                          "STUDENT REGISTRY",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.people_alt_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Manage Students",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Monitor academic performance, points, wallet balances & role promotions.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat("Total Students", currentStats['total'].toString(), Icons.group_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStat("Total Funds", "\$${(currentStats['totalWalletFunds'] as double).toInt()}", Icons.account_balance_wallet_rounded)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= SEARCH BAR =================
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
                        hintText: "Search by name or email...",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= STUDENTS LIST =================
            currentFiltered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, color: textGrey, size: 36),
                        const SizedBox(height: 10),
                        const Text("No students found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentFiltered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = currentFiltered[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: lightPinkBg,
                                  backgroundImage: student.avatarUrl != null && student.avatarUrl!.isNotEmpty
                                      ? NetworkImage(student.avatarUrl!)
                                      : null,
                                  child: (student.avatarUrl == null || student.avatarUrl!.isEmpty)
                                      ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 12))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${student.firstName} ${student.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text(student.email, style: const TextStyle(color: textGrey, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                  child: Text("${student.totalScore} PTS", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: cardBorder, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("WALLET BALANCE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                                    const SizedBox(height: 2),
                                    Text("\$${student.walletBalance.toStringAsFixed(2)}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: lightPinkBg,
                                    foregroundColor: primaryPink,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.manage_accounts_rounded, size: 14),
                                  label: const Text("Manage Profile", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                  onPressed: () {
                                    // هدایت به صفحه اختصاصی مدیریت پروفایل
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentDetailProfileScreen(studentId: student.id),
                                      ),
                                    ).then((_) => _fetchStudents());
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}