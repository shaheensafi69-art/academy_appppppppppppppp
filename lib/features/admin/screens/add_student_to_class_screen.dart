import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Map<String, dynamic>? selectedStudent;
  bool isPaid = false;
  bool isEnrolling = false;

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

  Future<void> handleEnrollStudent() async {
    if (selectedStudent == null) return;
    setState(() => isEnrolling = true);

    try {
      final classData = await supabase
          .from("class_groups")
          .select("course_id")
          .eq("id", widget.classId)
          .single();

      // درج در جدول class_students
      await supabase.from("class_students").upsert({
        'class_group_id': widget.classId,
        'student_id': selectedStudent!['id'],
        'is_paid': isPaid,
      }, onConflict: "class_group_id, student_id");

      // درج در جدول enrollments
      await supabase.from("enrollments").upsert({
        'student_id': selectedStudent!['id'],
        'course_id': classData['course_id'],
        'progress_percentage': 0,
      }, onConflict: "student_id, course_id");

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error enrolling student: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
        setState(() => isEnrolling = false);
      }
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
              const CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING GLOBAL DIRECTORY...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredStudents;

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
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
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
                          Text("Back to Class Roster", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header & Search
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Enroll Student", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text("Search and select a student to enroll in this cohort.", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => setState(() => searchQuery = val),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: "Search by name, email...",
                                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                  currentFiltered.isEmpty
                      ? Container(padding: const EdgeInsets.all(30), alignment: Alignment.center, child: const Text("No students found.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentFiltered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final student = currentFiltered[index];
                            bool isSelected = selectedStudent?['id'] == student['id'];

                            return GestureDetector(
                              onTap: () => setState(() => selectedStudent = student),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.cyan.withOpacity(0.15) : const Color(0xFF0a0a0f).withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.06)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.black,
                                      backgroundImage: student['avatar_url'] != null ? NetworkImage(student['avatar_url']) : null,
                                      child: student['avatar_url'] == null ? Text(student['first_name'][0], style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${student['first_name']} ${student['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(height: 2),
                                          Text(student['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                    if (isSelected) const Icon(Icons.check_circle, color: Colors.cyanAccent, size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom Action Bar when student is selected
          if (selectedStudent != null)
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0a0a0f),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text("Enroll: ${selectedStudent!['first_name']} ${selectedStudent!['last_name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: isPaid,
                              activeColor: Colors.cyanAccent,
                              checkColor: Colors.black,
                              onChanged: (val) => setState(() => isPaid = val ?? false),
                            ),
                            const Text("Paid", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isEnrolling ? null : handleEnrollStudent,
                        child: isEnrolling
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text("CONFIRM ENROLLMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
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
}