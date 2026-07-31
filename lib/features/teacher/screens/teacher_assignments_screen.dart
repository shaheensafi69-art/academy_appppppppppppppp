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
        backgroundColor: const Color(0xFF0a0a0f),
        title: const Text("Delete Assignment", style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Text("Are you sure you want to permanently delete: \"$title\"?", style: const TextStyle(color: Colors.grey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.pink.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Text("📝", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Assignments Terminal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text("Issue tasks and evaluate student submittals.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Create", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
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
          const SizedBox(height: 16),

          // آمار کلی
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.pink.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.pink.withOpacity(0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TOTAL ISSUED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.pinkAccent)),
                      const SizedBox(height: 2),
                      Text("$totalTasks Tasks", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.purple.withOpacity(0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ACTIVE DEADLINES", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
                      const SizedBox(height: 2),
                      Text("$dueSoonCount Pending", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // فیلتر کلاس
          DropdownButtonFormField<String>(
            value: selectedClassFilter,
            dropdownColor: const Color(0xFF161622),
            style: const TextStyle(color: Colors.white, fontSize: 11),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0a0a0f),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            items: [
              const DropdownMenuItem(value: "all", child: Text("All Classroom Roster")),
              ...classes.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['class_name']))),
            ],
            onChanged: (val) => setState(() => selectedClassFilter = val ?? "all"),
          ),
          const SizedBox(height: 16),

          // لیست تکالیف
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : filteredAssignments.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAssignments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final task = filteredAssignments[index];
                        bool isExpired = false;
                        if (task.deadline != null) {
                          try {
                            isExpired = DateTime.parse(task.deadline!).isBefore(DateTime.now());
                          } catch (_) {}
                        }

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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text(task.className, style: const TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text("Max: ${task.maxScore} Pts", style: const TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(task.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(task.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        task.deadline != null ? "Due: ${task.deadline!.split('T')[0]}" : "No Deadline",
                                        style: TextStyle(color: isExpired ? Colors.redAccent : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, color: Colors.pinkAccent, size: 18),
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
                                            : const Icon(Icons.delete, color: Colors.redAccent, size: 18),
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
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: const Text("No assignments found.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}