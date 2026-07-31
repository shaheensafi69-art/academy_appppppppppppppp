import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherStudentProfileItem {
  final String id;
  final String firstName;
  final String lastName;
  final String fatherName;
  final String dateOfBirth;
  final String email;
  final String phoneNumber;
  final String country;
  final String? avatarUrl;
  final int totalScore;
  final double walletBalance;
  final String bio;
  final String referralCode;
  final List<String> enrolledClasses;

  TeacherStudentProfileItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fatherName,
    required this.dateOfBirth,
    required this.email,
    required this.phoneNumber,
    required this.country,
    this.avatarUrl,
    required this.totalScore,
    required this.walletBalance,
    required this.bio,
    required this.referralCode,
    required this.enrolledClasses,
  });
}

class TeacherAllStudentsScreen extends StatefulWidget {
  const TeacherAllStudentsScreen({super.key});

  @override
  State<TeacherAllStudentsScreen> createState() => _TeacherAllStudentsScreenState();
}

class _TeacherAllStudentsScreenState extends State<TeacherAllStudentsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<TeacherStudentProfileItem> students = [];
  String searchQuery = "";
  TeacherStudentProfileItem? selectedStudent;

  @override
  void initState() {
    super.initState();
    _fetchAllTeacherStudents();
  }

  Future<void> _fetchAllTeacherStudents() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final teacherId = user.id;

      // ۱. پیدا کردن تمام کلاس‌های این استاد
      final teacherClasses = await supabase
          .from("class_groups")
          .select("id, class_name")
          .eq("teacher_id", teacherId);

      if (teacherClasses == null || (teacherClasses as List).isEmpty) {
        setState(() {
          students = [];
          isLoading = false;
        });
        return;
      }

      final classIds = (teacherClasses as List).map((c) => c['id']).toList();

      // ۲. پیدا کردن رکوردهای شاگردان این کلاس‌ها
      final classStudentsData = await supabase
          .from("class_students")
          .select("student_id, class_group_id")
          .inFilter("class_group_id", classIds);

      if (classStudentsData == null || (classStudentsData as List).isEmpty) {
        setState(() {
          students = [];
          isLoading = false;
        });
        return;
      }

      final uniqueStudentIds = (classStudentsData as List).map((item) => item['student_id']).toSet().toList();

      // ۳. واکشی پروفایل کامل این شاگردان
      final profilesData = await supabase
          .from("profiles")
          .select("id, first_name, last_name, father_name, date_of_birth, email, phone_number, country, avatar_url, total_score, wallet_balance, bio, referral_code")
          .inFilter("id", uniqueStudentIds);

      if (profilesData != null) {
        students = (profilesData as List).map((p) {
          final studentClassRelations = (classStudentsData as List).where((cs) => cs['student_id'] == p['id']);
          final enrolledClassNames = studentClassRelations.map((rel) {
            final cls = (teacherClasses as List).firstWhere((c) => c['id'] == rel['class_group_id'], orElse: () => null);
            return cls != null ? cls['class_name'] : "Unknown Class";
          }).toList();

          return TeacherStudentProfileItem(
            id: p['id'] ?? '',
            firstName: p['first_name'] ?? 'Unknown',
            lastName: p['last_name'] ?? '',
            fatherName: p['father_name'] ?? 'Not specified',
            dateOfBirth: p['date_of_birth'] ?? 'Not specified',
            email: p['email'] ?? 'No email',
            phoneNumber: p['phone_number'] ?? 'No phone',
            country: p['country'] ?? 'Not specified',
            avatarUrl: p['avatar_url'],
            totalScore: p['total_score'] ?? 0,
            walletBalance: (p['wallet_balance'] ?? 0).toDouble(),
            bio: p['bio'] ?? 'No biography provided.',
            referralCode: p['referral_code'] ?? '-',
            enrolledClasses: enrolledClassNames.cast<String>().toSet().toList(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching teacher roster: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = students.where((s) {
      final q = searchQuery.toLowerCase();
      return s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.phoneNumber.contains(q);
    }).toList();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text("👥", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("My Students",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text("Global directory of all students enrolled across your classes (${students.length} Total).",
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Search by name, email...",
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= لیست شاگردان =================
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pink))
              : filteredStudents.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredStudents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.pink.withOpacity(0.2),
                                    backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                    child: student.avatarUrl == null ? Text(student.firstName[0],
                                            style: const TextStyle(color: Colors.pinkAccent))
                                        : null, // Changed fuchsiaAccent to pinkAccent
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${student.firstName} ${student.lastName}",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(student.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amberAccent, size: 10),
                                        const SizedBox(width: 3),
                                        Text("${student.totalScore}",
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: student.enrolledClasses.map((cls) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(cls,
                                        style: const TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 34,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: Icon(Icons.visibility, size: 14, color: Colors.pink),
                                  label: const Text("View Profile", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  onPressed: () => setState(() => selectedStudent = student),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: const Column(
                        children: [
                          Text("🔍", style: TextStyle(fontSize: 32)),
                          SizedBox(height: 10),
                          Text("No Students Found",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("We couldn't find any students matching your criteria.",
                              style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 30),

          // ================= مودال پروفایل کامل شاگرد =================
          if (selectedStudent != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d0d14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.pink.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${selectedStudent!.firstName} ${selectedStudent!.lastName}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                        IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                            onPressed: () => setState(() => selectedStudent = null)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Email: ${selectedStudent!.email}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Phone: ${selectedStudent!.phoneNumber}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Country: ${selectedStudent!.country}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Wallet: \$${selectedStudent!.walletBalance}", style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("Biography:", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(selectedStudent!.bio, style: TextStyle(color: Colors.grey.shade300, fontSize: 10)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                        onPressed: () => setState(() => selectedStudent = null),
                        child: const Text("Close", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}