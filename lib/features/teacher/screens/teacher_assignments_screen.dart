import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_assignment_screen.dart';
import 'teacher_submissions_screen.dart';

class AssignmentItem {
  final String id;
  final String classGroupId;
  final String className;
  final String title;
  final String description;
  final String? deadline;
  final int maxScore;
  final String createdAt;

  AssignmentItem({
    required this.id,
    required this.classGroupId,
    required this.className,
    required this.title,
    required this.description,
    this.deadline,
    required this.maxScore,
    required this.createdAt,
  });
}

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String? deletingId;

  List<AssignmentItem> assignments = [];
  List<Map<String, dynamic>> classes = [];
  String selectedClassFilter = "all";

  // پالت رنگی لایت (سفید صدفی و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchAssignmentsData();
  }

  Future<void> _fetchAssignmentsData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final classesData = await supabase
          .from("class_groups")
          .select("id, class_name")
          .eq("teacher_id", user.id);

      if (classesData != null && (classesData as List).isNotEmpty) {
        classes = List<Map<String, dynamic>>.from(classesData);
        final classIds = classes.map((c) => c['id']).toList();

        final assignmentsData = await supabase
            .from("assignments")
            .select("id, class_group_id, title, description, deadline, max_score, created_at")
            .inFilter("class_group_id", classIds)
            .order("created_at", ascending: false);

        if (assignmentsData != null) {
          assignments = (assignmentsData as List).map((item) {
            final targetClass = classes.firstWhere(
              (c) => c['id'] == item['class_group_id'],
              orElse: () => {'class_name': 'Unknown Class'},
            );
            return AssignmentItem(
              id: item['id'],
              classGroupId: item['class_group_id'],
              className: targetClass['class_name'],
              title: item['title'] ?? '',
              description: item['description'] ?? 'No description provided.',
              deadline: item['deadline'],
              maxScore: item['max_score'] ?? 100,
              createdAt: item['created_at'] ?? '',
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching assignments: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteAssignment(String id, String title) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Assignment", style: TextStyle(color: textDark, fontSize: 15, fontWeight: FontWeight.w900)),
        content: Text("Are you sure you want to permanently delete: \"$title\"?", style: const TextStyle(color: textGrey, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => deletingId = id);
    try {
      await supabase.from("assignments").delete().eq("id", id);
      setState(() {
        assignments.removeWhere((item) => item.id == id);
      });
    } catch (e) {
      debugPrint("Failed to delete: $e");
    } finally {
      if (mounted) setState(() => deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssignments = selectedClassFilter == "all"
        ? assignments
        : assignments.where((item) => item.classGroupId == selectedClassFilter).toList();

    int totalTasks = assignments.length;
    int dueSoonCount = assignments.where((item) {
      if (item.deadline == null) return false;
      try {
        return DateTime.parse(item.deadline!).isAfter(DateTime.now());
      } catch (_) {
        return false;
      }
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.assignment_rounded, color: primaryPink, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Assignments Terminal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        SizedBox(height: 3),
                        Text("Issue tasks and evaluate student submittals.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Create", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeacherCreateAssignmentScreen()),
                    ).then((_) => _fetchAssignmentsData());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // آمار کلی
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TOTAL ISSUED", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text("$totalTasks Tasks", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ACTIVE DEADLINES", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.purple, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text("$dueSoonCount Pending", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // فیلتر کلاس
          DropdownButtonFormField<String>(
            value: selectedClassFilter,
            dropdownColor: surfaceWhite,
            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBorder.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
            ),
            items: [
              const DropdownMenuItem(value: "all", child: Text("All Classroom Roster")),
              ...classes.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['class_name']))),
            ],
            onChanged: (val) => setState(() => selectedClassFilter = val ?? "all"),
          ),
          const SizedBox(height: 18),

          // لیست تکالیف
          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : filteredAssignments.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAssignments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final task = filteredAssignments[index];
                        bool isExpired = false;
                        if (task.deadline != null) {
                          try {
                            isExpired = DateTime.parse(task.deadline!).isBefore(DateTime.now());
                          } catch (_) {}
                        }

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
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
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                    child: Text(task.className, style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                    child: Text("Max: ${task.maxScore} Pts", style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(task.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(task.description, style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: textGrey),
                                      const SizedBox(width: 6),
                                      Text(
                                        task.deadline != null ? "Due: ${task.deadline!.split('T')[0]}" : "No Deadline",
                                        style: TextStyle(color: isExpired ? Colors.redAccent : textGrey, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, color: primaryPink, size: 20),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => TeacherSubmissionsScreen(assignmentId: task.id)),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: deletingId == task.id
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                                            : const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteAssignment(task.id, task.title),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.assignment_outlined, size: 36, color: textGrey),
                          SizedBox(height: 10),
                          Text("No Assignments Found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("No assignments have been created yet.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}