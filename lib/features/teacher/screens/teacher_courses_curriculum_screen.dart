import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_course_screen.dart';

class CourseCurriculumItem {
  final String id;
  final String title;
  final String category;
  final String? thumbnailUrl;
  final double price;
  final String language;
  final bool isPublished;
  final String description;

  CourseCurriculumItem({
    required this.id,
    required this.title,
    required this.category,
    this.thumbnailUrl,
    required this.price,
    required this.language,
    required this.isPublished,
    required this.description,
  });

  factory CourseCurriculumItem.fromJson(Map<String, dynamic> json) {
    return CourseCurriculumItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Course',
      category: json['category'] ?? 'General',
      thumbnailUrl: json['thumbnail_url'],
      price: (json['price'] ?? 0).toDouble(),
      language: json['language'] ?? 'English',
      isPublished: json['is_published'] ?? false,
      description: json['description'] ?? 'No description provided.',
    );
  }
}

// ================= صفحه جزئیات کامل دوره و دانشجویان ان‌رول شده =================
class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseDetailScreen({super.key, required this.courseId, required this.courseTitle});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? courseData;
  List<Map<String, dynamic>> enrolledStudents = [];

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    setState(() => isLoading = true);
    try {
      final courseRes = await supabase
          .from("courses")
          .select("*")
          .eq("id", widget.courseId)
          .maybeSingle();

      final enrollmentsRes = await supabase
          .from("enrollments")
          .select("*, profiles(first_name, last_name, email, avatar_url)")
          .eq("course_id", widget.courseId);

      setState(() {
        courseData = courseRes;
        enrolledStudents = List<Map<String, dynamic>>.from(enrollmentsRes);
      });
    } catch (e) {
      debugPrint("Error fetching course details: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        title: Text(widget.courseTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
        iconTheme: const IconThemeData(color: primaryPink),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                  child: Text((courseData?['category'] ?? 'GENERAL').toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                                Text("\$${(courseData?['price'] ?? 0).toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(courseData?['title'] ?? widget.courseTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 6),
                            Text(courseData?['description'] ?? 'No description provided for this course.', style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4)),
                            const SizedBox(height: 16),
                            const Divider(color: cardBorder),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Language: ${courseData?['language'] ?? 'English'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text("Status: ${courseData?['is_published'] == true ? 'Published ✅' : 'Draft 📌'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Enrolled Students", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                            child: Text("${enrolledStudents.length} Students", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      enrolledStudents.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: enrolledStudents.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final enrollment = enrolledStudents[index];
                                final profile = enrollment['profiles'] as Map<String, dynamic>?;
                                final studentName = profile != null ? "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim() : "Student";
                                final studentEmail = profile?['email'] ?? 'No email';
                                final avatarUrl = profile?['avatar_url'];
                                final progress = enrollment['progress_percentage'] ?? 0;

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: cardBorder, width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: lightPinkBg,
                                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: primaryPink, size: 18) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(studentName.isNotEmpty ? studentName : "Enrolled Student", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(studentEmail, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text("$progress% Done", style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(30),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder),
                              ),
                              child: const Text("No students enrolled in this course yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ================= صفحه اصلی لیست کورس‌ها (Curriculum) =================
class TeacherCoursesCurriculumScreen extends StatefulWidget {
  const TeacherCoursesCurriculumScreen({super.key});

  @override
  State<TeacherCoursesCurriculumScreen> createState() => _TeacherCoursesCurriculumScreenState();
}

class _TeacherCoursesCurriculumScreenState extends State<TeacherCoursesCurriculumScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<CourseCurriculumItem> courses = [];

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from("courses")
          .select("id, title, category, thumbnail_url, price, language, is_published, description")
          .eq("teacher_id", user.id)
          .order("created_at", ascending: false);

      setState(() {
        courses = (data as List).map((c) => CourseCurriculumItem.fromJson(c)).toList();
      });
    } catch (e) {
      debugPrint("Error fetching curriculum courses: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 450;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryPink.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: primaryPink, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Course Curriculum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                                  SizedBox(height: 3),
                                  Text("Manage your published video courses and materials.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isWide ? 0 : 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text("Create Course", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TeacherCreateCourseScreen()),
                            ).then((_) => _fetchCourses());
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              const Text("Published Courses", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 12),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
                  : courses.isNotEmpty
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: courses.length,
                          itemBuilder: (context, index) {
                            final course = courses[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: cardBorder, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                    child: SizedBox(
                                      height: 95,
                                      width: double.infinity,
                                      child: course.thumbnailUrl != null
                                          ? Image.network(course.thumbnailUrl!, fit: BoxFit.cover)
                                          : Container(
                                              color: lightPinkBg,
                                              child: const Icon(Icons.book_rounded, color: primaryPink, size: 32),
                                            ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(course.category.toUpperCase(),
                                                        style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text("\$${course.price.toStringAsFixed(0)}",
                                                      style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(course.title,
                                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 32,
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: textDark,
                                                side: const BorderSide(color: cardBorder, width: 1.5),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: EdgeInsets.zero,
                                              ),
                                              onPressed: () {
                                                // 👈 هدایت صحیح به صفحه جزئیات دوره و دانشجویان ان‌رول شده
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => CourseDetailScreen(courseId: course.id, courseTitle: course.title),
                                                  ),
                                                ).then((_) => _fetchCourses());
                                              },
                                              child: const Text("Manage", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                            ),
                                          ),
                                        ],
                                      ),
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
                              Icon(Icons.library_books_rounded, size: 36, color: textGrey),
                              SizedBox(height: 10),
                              Text("No Courses Published", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 4),
                              Text("You haven't created any courses yet.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}