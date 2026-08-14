import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class TeacherCertificatesDetailScreen extends StatefulWidget {
  const TeacherCertificatesDetailScreen({super.key});

  @override
  State<TeacherCertificatesDetailScreen> createState() => _TeacherCertificatesDetailScreenState();
}

class _TeacherCertificatesDetailScreenState extends State<TeacherCertificatesDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;

  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> courses = [];

  String? selectedStudentId;
  String? selectedClassId;
  String? selectedCourseId;

  final TextEditingController _certCodeController = TextEditingController();
  XFile? selectedFile;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _certCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final classesData = await supabase
          .from("class_groups")
          .select("id, class_name, course_id, courses(id, title)")
          .eq("teacher_id", user.id);

      if ((classesData as List).isNotEmpty) {
        classes = List<Map<String, dynamic>>.from(classesData);
        selectedClassId = classes[0]['id'].toString();
        
        final courseMap = <String, String>{};
        for (var c in classes) {
          if (c['courses'] != null && c['courses'] is Map) {
            courseMap[c['courses']['id'].toString()] = c['courses']['title'];
          }
        }
        courses = courseMap.entries.map((e) => {'id': e.key, 'title': e.value}).toList();
        if (courses.isNotEmpty) selectedCourseId = courses[0]['id'];

        final classIds = classes.map((c) => c['id']).toList();
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

          students = List<Map<String, dynamic>>.from(profiles);
          if (students.isNotEmpty) selectedStudentId = students[0]['id'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _generateAutoCode() {
    if (selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a course first.")));
      return;
    }
    final year = DateTime.now().year;
    final randomHex = Random().nextInt(999999).toString().padLeft(6, '0');
    setState(() {
      _certCodeController.text = "SAFI-$year-CERT-$randomHex";
    });
  }

  Future<void> _pickFile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickMedia();
    if (file != null) {
      setState(() {
        selectedFile = file;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (selectedStudentId == null || selectedCourseId == null || _certCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      String? fileUrl;

      if (selectedFile != null) {
        final fileBytes = await selectedFile!.readAsBytes();
        final fileExt = selectedFile!.name.split('.').lastOrNull ?? 'jpg';
        final fileName = 'cert_${selectedStudentId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = fileName;

        await supabase.storage.from("certificates").uploadBinary(
          filePath,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );

        fileUrl = supabase.storage.from("certificates").getPublicUrl(filePath);
      }

      await supabase.from("certificates").upsert({
        'student_id': selectedStudentId,
        'course_id': selectedCourseId,
        'certificate_code': _certCodeController.text.trim(),
        'certificate_url': fileUrl,
        'issue_date': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id,course_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Certificate issued successfully! 🚀"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Failed to issue certificate: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
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

    final currentClass = classes.firstWhere((c) => c['id'].toString() == selectedClassId, orElse: () => classes.isNotEmpty ? classes[0] : {});
    final currentCourseTitle = (currentClass['courses'] is Map) ? currentClass['courses']['title'] : 'Select Class & Course';
    final currentClassName = currentClass['class_name'] ?? 'Select Class';

    final currentStudent = students.firstWhere((s) => s['id'].toString() == selectedStudentId, orElse: () => students.isNotEmpty ? students[0] : {});
    final currentStudentName = students.isNotEmpty ? "${currentStudent['first_name']} ${currentStudent['last_name']}" : 'Select Student';
    final currentStudentEmail = students.isNotEmpty ? currentStudent['email'] : '';
    final currentStudentAvatar = students.isNotEmpty ? currentStudent['avatar_url'] : null;

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: const Text("Issue New Certificate", style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Target Class & Course ---
                      const Text("TARGET CLASS & COURSE *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      PopupMenuButton<String>(
                        offset: const Offset(0, 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: surfaceWhite,
                        elevation: 10,
                        itemBuilder: (context) {
                          return classes.map((c) {
                            final courseTitle = (c['courses'] is Map) ? c['courses']['title'] : 'Course';
                            return PopupMenuItem<String>(
                              value: c['id'].toString(),
                              child: Container(
                                width: constraints.maxWidth > 500 ? 450 : constraints.maxWidth - 60,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.class_rounded, color: primaryPink, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${c['class_name']}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text("Course: $courseTitle", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    if (selectedClassId == c['id'].toString())
                                      const Icon(Icons.check_circle_rounded, color: primaryPink, size: 20),
                                  ],
                                ),
                              ),
                            );
                          }).toList();
                        },
                        onSelected: (val) {
                          setState(() {
                            selectedClassId = val;
                            final matchedClass = classes.firstWhere((c) => c['id'].toString() == val);
                            if (matchedClass['course_id'] != null) {
                              selectedCourseId = matchedClass['course_id'].toString();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardBorder.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.class_rounded, color: primaryPink, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(currentClassName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text("Course: $currentCourseTitle", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink, size: 22),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Graduate Student ---
                      const Text("GRADUATE STUDENT *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      PopupMenuButton<String>(
                        offset: const Offset(0, 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: surfaceWhite,
                        elevation: 10,
                        itemBuilder: (context) {
                          return students.map((s) {
                            return PopupMenuItem<String>(
                              value: s['id'].toString(),
                              child: Container(
                                width: constraints.maxWidth > 500 ? 450 : constraints.maxWidth - 60,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: lightPinkBg,
                                      backgroundImage: s['avatar_url'] != null ? NetworkImage(s['avatar_url']) : null,
                                      child: s['avatar_url'] == null ? Text(s['first_name'][0], style: const TextStyle(fontSize: 12, color: primaryPink, fontWeight: FontWeight.bold)) : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${s['first_name']} ${s['last_name']}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text("${s['email']}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    if (selectedStudentId == s['id'].toString())
                                      const Icon(Icons.check_circle_rounded, color: primaryPink, size: 20),
                                  ],
                                ),
                              ),
                            );
                          }).toList();
                        },
                        onSelected: (val) => setState(() => selectedStudentId = val),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardBorder.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: lightPinkBg,
                                backgroundImage: currentStudentAvatar != null ? NetworkImage(currentStudentAvatar) : null,
                                child: currentStudentAvatar == null ? Text(currentStudentName.isNotEmpty ? currentStudentName[0] : 'S', style: const TextStyle(fontSize: 12, color: primaryPink, fontWeight: FontWeight.bold)) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(currentStudentName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(currentStudentEmail, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink, size: 22),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Certificate Serial Code ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("CERTIFICATE SERIAL CODE *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          GestureDetector(
                            onTap: _generateAutoCode,
                            child: const Text("✨ Auto Generate Code", style: TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _certCodeController,
                        cursorColor: primaryPink,
                        style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: "e.g. SAFI-2026-CERT-94821",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 13),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Certificate Document Upload ---
                      const Text("CERTIFICATE DOCUMENT (IMAGE OR PDF) *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: lightPinkBg.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                            boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: primaryPink.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.cloud_upload_rounded, color: primaryPink, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFile != null ? selectedFile!.name : "Tap to browse certificate file...",
                                      style: TextStyle(color: selectedFile != null ? textDark : primaryPink, fontWeight: FontWeight.w900, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text("Supports high-res Image / PDF document", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- Submit Button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: isSubmitting ? null : _handleSubmit,
                          child: Text(
                            isSubmitting ? "Issuing Certificate..." : "Issue & Deploy Certificate 🎓",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}