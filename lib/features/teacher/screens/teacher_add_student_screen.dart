import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GlobalStudentItem {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String? avatarUrl;

  GlobalStudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.avatarUrl,
  });
}

class TeacherAddStudentScreen extends StatefulWidget {
  final String classId;
  const TeacherAddStudentScreen({super.key, required this.classId});

  @override
  State<TeacherAddStudentScreen> createState() => _TeacherAddStudentScreenState();
}

class _TeacherAddStudentScreenState extends State<TeacherAddStudentScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String className = "Loading...";
  String? courseId;

  List<GlobalStudentItem> allStudents = [];
  Set<String> enrolledIds = {};
  String searchQuery = "";
  String? addingId;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final classData = await supabase
          .from("class_groups")
          .select("class_name, course_id")
          .eq("id", widget.classId)
          .maybeSingle();

      if (classData != null) {
        className = classData['class_name'] ?? '';
        courseId = classData['course_id'];
      }

      final profilesData = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, phone_number, avatar_url")
          .eq("role", "student");

      allStudents = (profilesData as List).map((p) => GlobalStudentItem(
            id: p['id'],
            firstName: p['first_name'] ?? '',
            lastName: p['last_name'] ?? '',
            email: p['email'] ?? '',
            phoneNumber: p['phone_number'] ?? '',
            avatarUrl: p['avatar_url'],
          )).toList();
    
      final enrolledData = await supabase
          .from("class_students")
          .select("student_id")
          .eq("class_group_id", widget.classId);

      enrolledIds = Set<String>.from((enrolledData as List).map((e) => e['student_id']));
    } catch (e) {
      debugPrint("Error fetching global roster: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addStudent(GlobalStudentItem student) async {
    setState(() => addingId = student.id);
    try {
      if (courseId != null) {
        final existingEnrollment = await supabase
            .from("enrollments")
            .select("id")
            .eq("course_id", courseId!)
            .eq("student_id", student.id)
            .maybeSingle();

        if (existingEnrollment == null) {
          await supabase.from("enrollments").insert({
            'course_id': courseId,
            'student_id': student.id,
            'progress_percentage': 0,
          });
        }
      }

      await supabase.from("class_students").insert({
        'class_group_id': widget.classId,
        'student_id': student.id,
      });

      setState(() {
        enrolledIds.add(student.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${student.firstName} added to class successfully!"),
            backgroundColor: primaryPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding student: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to add student: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: const Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    final filtered = allStudents.where((s) {
      final q = searchQuery.toLowerCase();
      return s.firstName.toLowerCase().contains(q) || s.lastName.toLowerCase().contains(q) || s.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(
          "Add to: $className",
          style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  // سرچ‌بار مدرن و فیکس‌شده
                  TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Search student by name or email...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 20),
                      filled: true,
                      fillColor: cardBorder.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  filtered.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            bool isEnrolled = enrolledIds.contains(student.id);

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: isEnrolled ? primaryPink.withValues(alpha: 0.3) : cardBorder, width: isEnrolled ? 1.5 : 1),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: lightPinkBg,
                                          backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                          child: student.avatarUrl == null
                                              ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900))
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("${student.firstName} ${student.lastName}",
                                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text(student.email, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  isEnrolled
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text("Enrolled", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryPink,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: addingId == student.id ? null : () => _addStudent(student),
                                          child: Text(
                                            addingId == student.id ? "..." : "Add",
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text("No students found.", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}