import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentItem {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;

  StudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
  });
}

class AwardItem {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final int pointsRequired;

  AwardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.pointsRequired,
  });

  factory AwardItem.fromJson(Map<String, dynamic> json) {
    return AwardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'] ?? '🏆',
      pointsRequired: json['points_required'] ?? 0,
    );
  }
}

class TeacherAchievementsScreen extends StatefulWidget {
  const TeacherAchievementsScreen({super.key});

  @override
  State<TeacherAchievementsScreen> createState() => _TeacherAchievementsScreenState();
}

class _TeacherAchievementsScreenState extends State<TeacherAchievementsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  List<StudentItem> students = [];
  List<AwardItem> awards = [];

  // فرم اعطای نشان و مقام
  String? selectedAwardStudentId;
  String? selectedAwardId;
  bool isSubmittingAward = false;
  String studentSearchQuery = "";

  String? messageText;
  bool isSuccessMessage = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final myClasses = await supabase
          .from("class_groups")
          .select("id")
          .eq("teacher_id", userId);

      if ((myClasses as List).isNotEmpty) {
        final classIds = myClasses.map((c) => c['id']).toList();

        final classStudents = await supabase
            .from("class_students")
            .select("student_id")
            .inFilter("class_group_id", classIds);

        if ((classStudents as List).isNotEmpty) {
          final studentIds = classStudents.map((cs) => cs['student_id']).toSet().toList();
          final profiles = await supabase
              .from("profiles")
              .select("id, first_name, last_name, email, avatar_url")
              .inFilter("id", studentIds);

          students = (profiles as List).map((p) => StudentItem(
                id: p['id'],
                firstName: p['first_name'] ?? '',
                lastName: p['last_name'] ?? '',
                email: p['email'] ?? '',
                avatarUrl: p['avatar_url'],
              )).toList();

          if (students.isNotEmpty) {
            selectedAwardStudentId = students[0].id;
          }
        }
      }

      final awardsData = await supabase
          .from("awards")
          .select()
          .order("points_required", ascending: true);

      awards = (awardsData as List).map((a) => AwardItem.fromJson(a)).toList();
      if (awards.isNotEmpty) selectedAwardId = awards[0].id;
    } catch (e) {
      debugPrint("Error fetching awards data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleGrantAward() async {
    if (selectedAwardStudentId == null || selectedAwardId == null) {
      _showMessage("Please select a student and an award.", false);
      return;
    }

    setState(() => isSubmittingAward = true);
    try {
      await supabase.from("student_awards").insert({
        'student_id': selectedAwardStudentId,
        'award_id': selectedAwardId,
      });

      _showMessage("Award & Badge granted successfully!", true);
    } catch (e) {
      _showMessage("Failed to grant award: $e", false);
    } finally {
      if (mounted) setState(() => isSubmittingAward = false);
    }
  }

  void _showMessage(String text, bool success) {
    setState(() {
      messageText = text;
      isSuccessMessage = success;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => messageText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: const Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    final filteredStudents = students.where((s) {
      final query = studentSearchQuery.toLowerCase();
      return s.firstName.toLowerCase().contains(query) || s.lastName.toLowerCase().contains(query) || s.email.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= هدر صفحه ریسپانسیو =================
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: primaryPink.withValues(alpha: 0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryPink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: primaryPink, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Honors & Awards Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                              SizedBox(height: 3),
                              Text("Grant special badges, titles, and merits to top-performing students.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // پیام سیستم (Toast)
                  if (messageText != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isSuccessMessage ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSuccessMessage ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(isSuccessMessage ? Icons.check_circle_rounded : Icons.error_rounded, color: isSuccessMessage ? Colors.green : Colors.redAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.green.shade800 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),

                  // ================= فرم متمرکز اعطای مقام و نشان =================
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.military_tech_rounded, color: Colors.amber, size: 22),
                            SizedBox(width: 8),
                            Text("Grant Merit / Award", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // سرچ‌بار برای پیدا کردن سریع شاگرد
                        const Text("Search & Select Student *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          onChanged: (val) => setState(() => studentSearchQuery = val),
                          style: const TextStyle(color: textDark, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Filter student by name or email...",
                            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                            prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 18),
                            filled: true,
                            fillColor: cardBorder.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAwardStudentId,
                          dropdownColor: surfaceWhite,
                          isExpanded: true,
                          style: const TextStyle(color: textDark, fontSize: 12),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: cardBorder.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                          items: filteredStudents.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.firstName} ${s.lastName} (${s.email})", overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => selectedAwardStudentId = val),
                        ),
                        const SizedBox(height: 18),

                        const Text("Select Badge / Award Merit *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        awards.isNotEmpty
                            ? ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: awards.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final award = awards[index];
                                  bool isSelected = selectedAwardId == award.id;

                                  return GestureDetector(
                                    onTap: () => setState(() => selectedAwardId = award.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected ? lightPinkBg : cardBorder.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 1.5 : 1),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? primaryPink : primaryPink.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(award.iconUrl, style: const TextStyle(fontSize: 20)),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(award.title, style: TextStyle(color: isSelected ? primaryPink : textDark, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 2),
                                                Text(award.description, style: const TextStyle(color: textGrey, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.check_circle_rounded, color: primaryPink, size: 20),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : const Text("No awards configured in database.", style: TextStyle(color: textGrey, fontSize: 11)),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: isSubmittingAward ? null : _handleGrantAward,
                            child: Text(isSubmittingAward ? "Granting..." : "Grant Award & Merit 🏆", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}