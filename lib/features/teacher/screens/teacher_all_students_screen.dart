import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherStudentProfileItem {
  final String id;
  final String firstName;
  final String lastName;
  final String fatherName;
  final String dateOfBirth;
  final String email;
  final String phoneNumber;
  final String country;
  final String? avatarUrl;
  final int totalScore;
  final double walletBalance;
  final String bio;
  final String referralCode;
  final List<String> enrolledCourses;
  final List<String> enrolledClasses;

  TeacherStudentProfileItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fatherName,
    required this.dateOfBirth,
    required this.email,
    required this.phoneNumber,
    required this.country,
    this.avatarUrl,
    required this.totalScore,
    required this.walletBalance,
    required this.bio,
    required this.referralCode,
    required this.enrolledCourses,
    required this.enrolledClasses,
  });
}

class TeacherAllStudentsScreen extends StatefulWidget {
  const TeacherAllStudentsScreen({super.key});

  @override
  State<TeacherAllStudentsScreen> createState() => _TeacherAllStudentsScreenState();
}

class _TeacherAllStudentsScreenState extends State<TeacherAllStudentsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<TeacherStudentProfileItem> students = [];
  
  // لیست دوره‌ها و کلاس‌های استاد برای فیلتر
  List<Map<String, dynamic>> teacherCourses = [];
  List<Map<String, dynamic>> teacherClasses = [];

  String? selectedCourseId; // فیلتر دوره
  String? selectedClassId;  // فیلتر کلاس
  String searchQuery = "";

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchTeacherStudentsAndFilters();
  }

  Future<void> _fetchTeacherStudentsAndFilters() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final teacherId = user.id;

      // ۱. خواندن دوره‌های متعلق به این استاد از جدول courses
      final coursesRes = await supabase
          .from("courses")
          .select("id, title")
          .eq("teacher_id", teacherId);
      teacherCourses = List<Map<String, dynamic>>.from(coursesRes);
      final courseIds = teacherCourses.map((c) => c['id']).toList();

      // ۲. خواندن کلاس‌های متعلق به این استاد از جدول class_groups
      final classesRes = await supabase
          .from("class_groups")
          .select("id, class_name, course_id")
          .eq("teacher_id", teacherId);
      teacherClasses = List<Map<String, dynamic>>.from(classesRes);
      final classIds = teacherClasses.map((c) => c['id']).toList();

      if (courseIds.isEmpty && classIds.isEmpty) {
        setState(() {
          students = [];
          isLoading = false;
        });
        return;
      }

      // ۳. واکشی جدول enrollments برای پیدا کردن دانشجویان دوره‌ها
      List<dynamic> enrollmentsData = [];
      if (courseIds.isNotEmpty) {
        enrollmentsData = await supabase
            .from("enrollments")
            .select("student_id, course_id, courses(title)")
            .inFilter("course_id", courseIds);
      }

      // ۴. واکشی جدول class_students برای پیدا کردن دانشجویان کلاس‌ها
      List<dynamic> classStudentsData = [];
      if (classIds.isNotEmpty) {
        classStudentsData = await supabase
            .from("class_students")
            .select("student_id, class_group_id")
            .inFilter("class_group_id", classIds);
      }

      // استخراج شناسه‌های یکتای تمام دانشجویان مرتبط
      final studentIdsSet = <String>{};
      for (var en in enrollmentsData) {
        if (en['student_id'] != null) studentIdsSet.add(en['student_id'].toString());
      }
      for (var cs in classStudentsData) {
        if (cs['student_id'] != null) studentIdsSet.add(cs['student_id'].toString());
      }

      if (studentIdsSet.isEmpty) {
        setState(() {
          students = [];
          isLoading = false;
        });
        return;
      }

      // ۵. خواندن اطلاعات کامل پروفایل شاگردان از جدول profiles
      final profilesData = await supabase
          .from("profiles")
          .select("id, first_name, last_name, father_name, date_of_birth, email, phone_number, country, avatar_url, total_score, wallet_balance, bio, referral_code")
          .inFilter("id", studentIdsSet.toList());

      students = (profilesData as List).map((p) {
        final pId = p['id'];

        // دوره‌های ثبت‌نام شده‌ی این شاگرد
        final myEnrollments = enrollmentsData.where((en) => en['student_id'] == pId);
        final courseNames = myEnrollments.map((en) {
          final cObj = en['courses'];
          if (cObj is Map) return cObj['title']?.toString() ?? 'Course';
          return 'Course';
        }).toSet().toList();

        // کلاس‌های این شاگرد
        final myClasses = classStudentsData.where((cs) => cs['student_id'] == pId);
        final classNames = myClasses.map((cs) {
          final matchCls = teacherClasses.firstWhere((tc) => tc['id'] == cs['class_group_id'], orElse: () => {});
          return matchCls['class_name']?.toString() ?? 'Class';
        }).toSet().toList();

        return TeacherStudentProfileItem(
          id: pId ?? '',
          firstName: p['first_name'] ?? 'Unknown',
          lastName: p['last_name'] ?? '',
          fatherName: p['father_name'] ?? 'Not specified',
          dateOfBirth: p['date_of_birth'] ?? 'Not specified',
          email: p['email'] ?? 'No email',
          phoneNumber: p['phone_number'] ?? 'No phone',
          country: p['country'] ?? 'Not specified',
          avatarUrl: p['avatar_url'],
          totalScore: p['total_score'] ?? 0,
          walletBalance: (p['wallet_balance'] ?? 0).toDouble(),
          bio: p['bio'] ?? 'No biography provided.',
          referralCode: p['referral_code'] ?? '-',
          enrolledCourses: courseNames,
          enrolledClasses: classNames,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error fetching students data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showStudentProfileModal(TeacherStudentProfileItem student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: lightPinkBg,
                    backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                    child: student.avatarUrl == null
                        ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S', style: const TextStyle(color: primaryPink, fontSize: 20, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${student.firstName} ${student.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(student.email, style: const TextStyle(color: textGrey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: cardBorder),
              const SizedBox(height: 16),
              _buildProfileDetailRow("Father's Name", student.fatherName),
              _buildProfileDetailRow("Date of Birth", student.dateOfBirth),
              _buildProfileDetailRow("Phone Number", student.phoneNumber),
              _buildProfileDetailRow("Country", student.country),
              _buildProfileDetailRow("Total Score", "${student.totalScore} Points"),
              _buildProfileDetailRow("Wallet Balance", "\$${student.walletBalance.toStringAsFixed(2)}"),
              const SizedBox(height: 12),
              const Text("Biography", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBorder.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                child: Text(student.bio, style: const TextStyle(color: textGrey, fontSize: 11)),
              ),
              const SizedBox(height: 24),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close Profile", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // دیالوگ کشویی بسیار زیبا و حرفه‌ای برای فیلتر بر اساس نام کورس و کلاس
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Filter Directory", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: textGrey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Text("Filter students by specific course and class group.", style: TextStyle(color: textGrey, fontSize: 11)),
                  const SizedBox(height: 20),

                  // انتخاب کورس (Course)
                  const Text("Course Filter", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCourseId,
                    dropdownColor: surfaceWhite,
                    isExpanded: true,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text("All Courses (Clear)")),
                      ...teacherCourses.map((crs) => DropdownMenuItem<String?>(
                            value: crs['id'].toString(),
                            child: Text(crs['title'] ?? 'Course Title'),
                          )),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        setState(() {
                          selectedCourseId = val;
                          selectedClassId = null; // ریست کلاس با تغییر کورس
                        });
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // انتخاب کلاس (Class Group)
                  const Text("Class Group Filter", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedClassId,
                    dropdownColor: surfaceWhite,
                    isExpanded: true,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text("All Classes (Clear)")),
                      ...teacherClasses
                          .where((cls) => selectedCourseId == null || cls['course_id'].toString() == selectedCourseId.toString())
                          .map((cls) => DropdownMenuItem<String?>(
                                value: cls['id'].toString(),
                                child: Text(cls['class_name'] ?? 'Class Name'),
                              )),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        setState(() => selectedClassId = val);
                      });
                    },
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: cardBorder, width: 1.5),
                          ),
                          onPressed: () {
                            setState(() {
                              selectedCourseId = null;
                              selectedClassId = null;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Reset Filters", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Apply Filter", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // فیلتر کردن هوشمند شاگردان بر اساس سرچ، دوره و کلاس انتخاب‌شده
    final filteredStudents = students.where((s) {
      final q = searchQuery.toLowerCase();
      bool matchesSearch = s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.phoneNumber.contains(q);

      bool matchesCourse = true;
      if (selectedCourseId != null) {
        final crsObj = teacherCourses.firstWhere((c) => c['id'].toString() == selectedCourseId.toString(), orElse: () => {});
        final crsTitle = crsObj['title'] ?? '';
        matchesCourse = s.enrolledCourses.contains(crsTitle);
      }

      bool matchesClass = true;
      if (selectedClassId != null) {
        final clsObj = teacherClasses.firstWhere((c) => c['id'].toString() == selectedClassId.toString(), orElse: () => {});
        final clsName = clsObj['class_name'] ?? '';
        matchesClass = s.enrolledClasses.contains(clsName);
      }

      return matchesSearch && matchesCourse && matchesClass;
    }).toList();

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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.group_rounded, color: primaryPink, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("My Students", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                      const SizedBox(height: 3),
                      Text("Global directory of all students enrolled across your courses & classes (${filteredStudents.length} Visible).",
                          style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= ابزار جستجو و دکمه فیلتر پیشرفته =================
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "Search by name, email, phone...",
                    hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                    prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 20),
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showFilterBottomSheet,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: (selectedCourseId != null || selectedClassId != null) ? primaryPink : cardBorder.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (selectedCourseId != null || selectedClassId != null) ? primaryPink : cardBorder, width: 1.5),
                  ),
                  child: Icon(Icons.filter_list_rounded,
                      color: (selectedCourseId != null || selectedClassId != null) ? Colors.white : textDark, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ================= لیست شاگردان =================
          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : filteredStudents.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredStudents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
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
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: lightPinkBg,
                                    backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                    child: student.avatarUrl == null
                                        ? Text(student.firstName.isNotEmpty ? student.firstName[0] : 'S',
                                            style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${student.firstName} ${student.lastName}",
                                            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(student.email, style: const TextStyle(color: textGrey, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                        const SizedBox(width: 3),
                                        Text("${student.totalScore}",
                                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...student.enrolledCourses.map((crs) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: primaryPink.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text("Course: $crs",
                                            style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.bold)),
                                      )),
                                  ...student.enrolledClasses.map((cls) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: lightPinkBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text("Class: $cls",
                                            style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.bold)),
                                      )),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textDark,
                                    side: const BorderSide(color: cardBorder, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.visibility_rounded, size: 16, color: primaryPink),
                                  label: const Text("View Profile", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  onPressed: () => _showStudentProfileModal(student),
                                ),
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
                          Icon(Icons.search_off_rounded, size: 36, color: textGrey),
                          SizedBox(height: 10),
                          Text("No Students Found",
                              style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("We couldn't find any students matching your criteria.",
                              style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}