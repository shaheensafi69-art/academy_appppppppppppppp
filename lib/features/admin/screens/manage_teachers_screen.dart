import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_detail_screen.dart'; // در ادامه این صفحه را می‌سازیم

class TeacherProfileModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? bio;
  final String? avatarUrl;
  final int activeClasses;
  final int totalStudents;

  TeacherProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.bio,
    this.avatarUrl,
    required this.activeClasses,
    required this.totalStudents,
  });
}

class ManageTeachersScreen extends StatefulWidget {
  const ManageTeachersScreen({super.key});

  @override
  State<ManageTeachersScreen> createState() => _ManageTeachersScreenState();
}

class _ManageTeachersScreenState extends State<ManageTeachersScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<TeacherProfileModel> users = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    setState(() => isLoading = true);
    try {
      final profiles = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, role, bio, avatar_url")
          .inFilter("role", ["teacher", "super_admin"])
          .order("created_at", ascending: false);

      List<TeacherProfileModel> enrichedProfiles = [];

      for (var teacher in (profiles as List)) {
        final groups = await supabase
            .from("class_groups")
            .select("id, is_active, class_students(student_id)")
            .eq("teacher_id", teacher['id']);

        int activeCount = 0;
        Set uniqueStudents = {};

        for (var g in (groups as List)) {
          if (g['is_active'] == true) activeCount++;
          if (g['class_students'] != null) {
            for (var cs in (g['class_students'] as List)) {
              uniqueStudents.add(cs['student_id']);
            }
          }
        }
      
        enrichedProfiles.add(TeacherProfileModel(
          id: teacher['id'] ?? '',
          firstName: teacher['first_name'] ?? '',
          lastName: teacher['last_name'] ?? '',
          email: teacher['email'] ?? '',
          role: teacher['role'] ?? 'teacher',
          bio: teacher['bio'],
          avatarUrl: teacher['avatar_url'],
          activeClasses: activeCount,
          totalStudents: uniqueStudents.length,
        ));
      }

      if (mounted) {
        setState(() {
          users = enrichedProfiles;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching teachers: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<TeacherProfileModel> get filteredTeachers {
    if (searchQuery.isEmpty) return users;
    final query = searchQuery.toLowerCase();
    return users.where((t) =>
      t.firstName.toLowerCase().contains(query) ||
      t.lastName.toLowerCase().contains(query) ||
      t.email.toLowerCase().contains(query)
    ).toList();
  }

  Map<String, dynamic> get stats {
    int totalFaculty = users.length;
    int totalClasses = users.fold(0, (acc, curr) => acc + curr.activeClasses);
    return {'totalFaculty': totalFaculty, 'totalClasses': totalClasses};
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
              Text("LOADING FACULTY RECORDS...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredTeachers;
    final currentStats = stats;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          // Background Glow (Indigo & Violet)
          Positioned(
            top: -40,
            left: -40,
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
                                color: Colors.indigoAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "FACULTY DIRECTORY",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.admin_panel_settings_rounded, color: Colors.indigoAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Faculty Management",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Review instructor profiles and active cohorts.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _buildMiniStat("Total Faculty", currentStats['totalFaculty'].toString(), Icons.verified_user_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMiniStat("Active Cohorts", currentStats['totalClasses'].toString(), Icons.menu_book_rounded)),
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
                              hintText: "Search instructor by name or email...",
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

                  // ================= FACULTY LIST =================
                  currentFiltered.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_rounded, color: Colors.grey, size: 36),
                              const SizedBox(height: 10),
                              Text("No instructors found.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentFiltered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final teacher = currentFiltered[index];
                            return _buildGlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.black,
                                        backgroundImage: teacher.avatarUrl != null && teacher.avatarUrl!.isNotEmpty
                                            ? NetworkImage(teacher.avatarUrl!)
                                            : null,
                                        child: (teacher.avatarUrl == null || teacher.avatarUrl!.isEmpty)
                                            ? Text(teacher.firstName.isNotEmpty ? teacher.firstName[0] : 'T', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold))
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("${teacher.firstName} ${teacher.lastName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                            const SizedBox(height: 2),
                                            Text(teacher.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: teacher.role == "super_admin" ? Colors.purple.withOpacity(0.15) : Colors.indigo.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(teacher.role.replaceFirst('_', ' ').toUpperCase(), style: TextStyle(color: teacher.role == "super_admin" ? Colors.purpleAccent : Colors.indigoAccent, fontSize: 7, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    teacher.bio ?? "No professional biography provided.",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white10, height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text("Classes: ${teacher.activeClasses}", style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 10),
                                          Text("Students: ${teacher.totalStudents}", style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigoAccent.withOpacity(0.15),
                                          foregroundColor: Colors.indigoAccent,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: Colors.indigoAccent.withOpacity(0.3)),
                                        ),
                                        child: const Text("View Profile", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TeacherDetailScreen(teacherId: teacher.id),
                                            ),
                                          );
                                        },
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