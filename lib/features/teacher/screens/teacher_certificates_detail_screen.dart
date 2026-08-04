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

      // 🛠 استفاده از upsert برای جلوگیری از خطای duplicate key در دیتابیس
      await supabase.from("certificates").upsert({
        'student_id': selectedStudentId,
        'course_id': selectedCourseId,
        'certificate_code': _certCodeController.text.trim(),
        'certificate_url': ?fileUrl,
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

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: const Text("Issue New Certificate", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Target Class & Course *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    dropdownColor: surfaceWhite,
                    isExpanded: true,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                    items: classes.map((c) {
                      final courseTitle = (c['courses'] is Map) ? c['courses']['title'] : 'Course';
                      return DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text("${c['class_name']} ($courseTitle)", overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedClassId = val;
                        final matchedClass = classes.firstWhere((c) => c['id'].toString() == val);
                        if (matchedClass['course_id'] != null) {
                          selectedCourseId = matchedClass['course_id'].toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text("Graduate Student *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStudentId,
                    dropdownColor: surfaceWhite,
                    isExpanded: true,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                    items: students.map((s) {
                      return DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: lightPinkBg,
                              backgroundImage: s['avatar_url'] != null ? NetworkImage(s['avatar_url']) : null,
                              child: s['avatar_url'] == null ? Text(s['first_name'][0], style: const TextStyle(fontSize: 9, color: primaryPink)) : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text("${s['first_name']} ${s['last_name']} (${s['email']})", overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedStudentId = val),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Certificate Serial Code *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: _generateAutoCode,
                        child: const Text("✨ Auto Generate Code", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _certCodeController,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "e.g. SAFI-2026-CERT-94821",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("Certificate Document (Image or PDF) *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: lightPinkBg.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: primaryPink.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.cloud_upload_rounded, color: primaryPink, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFile != null ? selectedFile!.name : "Tap to browse certificate file...",
                                  style: TextStyle(color: selectedFile != null ? textDark : primaryPink, fontWeight: FontWeight.w900, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text("Supports high-res Image / PDF document", style: TextStyle(color: textGrey, fontSize: 9)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

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
                      onPressed: isSubmitting ? null : _handleSubmit,
                      child: Text(isSubmitting ? "Issuing Certificate..." : "Issue & Deploy Certificate 🎓", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
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