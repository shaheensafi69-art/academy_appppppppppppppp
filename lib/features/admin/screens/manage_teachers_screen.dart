import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';
import 'teacher_detail_screen.dart';

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

  // Luxury Light-Pink Palette
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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

      final teacherInfoList = await supabase
          .from("teacher_info")
          .select("*");

      List<TeacherProfileModel> enrichedProfiles = [];

      for (var teacher in (profiles as List)) {
        String teacherId = teacher['id'];
        String fName = teacher['first_name'] ?? '';
        String lName = teacher['last_name'] ?? '';
        
        Map<String, dynamic>? tInfo;
        try {
          tInfo = (teacherInfoList as List).firstWhere(
            (info) => (info['first_name']?.toString().toLowerCase() == fName.toLowerCase()) &&
                      (info['last_name']?.toString().toLowerCase() == lName.toLowerCase()),
            orElse: () => {},
          );
        } catch (_) {
          tInfo = {};
        }

        final bioVal = teacher['bio'] ?? (tInfo != null && tInfo.isNotEmpty ? tInfo['bio'] : null);
        final avatarVal = teacher['avatar_url'] ?? (tInfo != null && tInfo.isNotEmpty ? tInfo['avatar_url'] : null);

        final groups = await supabase
            .from("class_groups")
            .select("id, is_active, class_students(student_id)")
            .eq("teacher_id", teacherId);

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
          id: teacherId,
          firstName: fName,
          lastName: lName,
          email: teacher['email'] ?? '',
          role: teacher['role'] ?? 'teacher',
          bio: bioVal,
          avatarUrl: avatarVal,
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
      debugPrint("Error fetching teachers & teacher_info: $e");
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text(
                context.l10n.loadingDirectory.toUpperCase(),
                style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredTeachers;
    final currentStats = stats;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: primaryPink.withValues(alpha: 0.08), blurRadius: 25, offset: const Offset(0, 10)),
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
                        child: Text(
                          context.l10n.facultyDirectory,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.admin_panel_settings_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.facultyManagement,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.facultyManagementSubtitle,
                    style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat(context.l10n.totalFaculty, currentStats['totalFaculty'].toString(), Icons.verified_user_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStat(context.l10n.activeCohorts, currentStats['totalClasses'].toString(), Icons.menu_book_rounded)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cardBorder.withValues(alpha: 0.5),
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
                        hintText: context.l10n.searchInstructorsHint,
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

            // Faculty List
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
                        Text(context.l10n.noInstructorsFound, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentFiltered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final teacher = currentFiltered[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: lightPinkBg,
                                  backgroundImage: teacher.avatarUrl != null && teacher.avatarUrl!.isNotEmpty
                                      ? NetworkImage(teacher.avatarUrl!)
                                      : null,
                                  child: (teacher.avatarUrl == null || teacher.avatarUrl!.isEmpty)
                                      ? Text(teacher.firstName.isNotEmpty ? teacher.firstName[0] : 'T', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 12))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${teacher.firstName} ${teacher.lastName}".trim(), style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text(teacher.email, style: const TextStyle(color: textGrey, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: teacher.role == "super_admin" ? Colors.purple.withValues(alpha: 0.12) : lightPinkBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    teacher.role == "super_admin"
                                        ? context.l10n.roleAdmin
                                        : context.l10n.roleTeacher,
                                    style: TextStyle(
                                      color: teacher.role == "super_admin" ? Colors.purple.shade700 : primaryPink,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              teacher.bio ?? context.l10n.noBiographyProvided,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: cardBorder, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text("${context.l10n.classes}: ${teacher.activeClasses}", style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 14),
                                    Text("${context.l10n.students}: ${teacher.totalStudents}", style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                  icon: const Icon(Icons.visibility_rounded, size: 14),
                                  label: Text(context.l10n.viewProfile, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
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