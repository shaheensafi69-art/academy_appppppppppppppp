import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';

class AddStudentToClassScreen extends StatefulWidget {
  final String classId;
  const AddStudentToClassScreen({super.key, required this.classId});

  @override
  State<AddStudentToClassScreen> createState() => _AddStudentToClassScreenState();
}

class _AddStudentToClassScreenState extends State<AddStudentToClassScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> allStudents = [];
  String searchQuery = "";
  
  final Set<String> selectedStudentIds = {};
  bool isPaid = false;
  bool isEnrolling = false;

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
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("profiles")
          .select("*")
          .eq('role', 'student')
          .order('created_at', ascending: false)
          .limit(500);

      if (mounted) {
        setState(() {
          allStudents = (response as List?)?.cast<Map<String, dynamic>>() ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load students: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredStudents {
    if (searchQuery.trim().isEmpty) return allStudents;
    final query = searchQuery.toLowerCase().trim();
    return allStudents.where((s) {
      final fullName = "${s['first_name'] ?? ''} ${s['last_name'] ?? ''}".toLowerCase();
      final email = (s['email'] ?? '').toLowerCase();
      final phone = (s['phone_number'] ?? '').toLowerCase();
      return fullName.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();
  }

  Future<void> handleEnrollStudents() async {
    if (selectedStudentIds.isEmpty) return;
    setState(() => isEnrolling = true);

    try {
      final classData = await supabase
          .from("class_groups")
          .select("course_id")
          .eq("id", widget.classId)
          .single();

      final courseId = classData['course_id'];

      List<Map<String, dynamic>> classStudentsPayload = [];
      List<Map<String, dynamic>> enrollmentsPayload = [];

      for (String studentId in selectedStudentIds) {
        classStudentsPayload.add({
          'class_group_id': widget.classId,
          'student_id': studentId,
          'is_paid': isPaid,
        });

        if (courseId != null) {
          enrollmentsPayload.add({
            'student_id': studentId,
            'course_id': courseId,
            'progress_percentage': 0,
          });
        }
      }

      await supabase.from("class_students").upsert(
            classStudentsPayload,
            onConflict: "class_group_id, student_id",
          );

      if (enrollmentsPayload.isNotEmpty) {
        await supabase.from("enrollments").upsert(
              enrollmentsPayload,
              onConflict: "student_id, course_id",
            );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error enrolling students: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
        setState(() => isEnrolling = false);
      }
    }
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

    final currentFiltered = filteredStudents;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBorder,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: textDark, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.backToClassRoster,
                        style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header & Search
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: primaryPink.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.enrollStudents,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.enrollStudentsSubtitle,
                      style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),
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
                                hintText: context.l10n.searchByNameOrEmail,
                                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Students List
              Expanded(
                child: currentFiltered.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: Text(
                            context.l10n.noStudentsFound,
                            style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: currentFiltered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = currentFiltered[index];
                          final studentId = student['id'];
                          bool isSelected = selectedStudentIds.contains(studentId);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedStudentIds.remove(studentId);
                                } else {
                                  selectedStudentIds.add(studentId);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? lightPinkBg.withValues(alpha: 0.5) : surfaceWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 2 : 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: lightPinkBg,
                                    backgroundImage: student['avatar_url'] != null ? NetworkImage(student['avatar_url']) : null,
                                    child: student['avatar_url'] == null ? Text(student['first_name'] != null && student['first_name'].isNotEmpty ? student['first_name'][0] : 'S', style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold)) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${student['first_name'] ?? ''} ${student['last_name'] ?? ''}".trim(), style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text(student['email'] ?? '', style: const TextStyle(color: textGrey, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: primaryPink,
                                    checkColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedStudentIds.add(studentId);
                                        } else {
                                          selectedStudentIds.remove(studentId);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Action Bar
              if (selectedStudentIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: primaryPink.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${selectedStudentIds.length} ${context.l10n.enrolledStudents}",
                            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: isPaid,
                                activeColor: primaryPink,
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) => setState(() => isPaid = val ?? false),
                              ),
                              Text(context.l10n.paidAll, style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: isEnrolling ? null : handleEnrollStudents,
                          child: isEnrolling
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text("${context.l10n.confirmEnrollment.toUpperCase()} (${selectedStudentIds.length}) 🚀", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}