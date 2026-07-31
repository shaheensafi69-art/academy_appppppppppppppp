import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_course_screen.dart';
import 'teacher_courses_screen.dart'; // 👈 ایمپورت صفحه مدرس کلاس‌ها و کوهورت‌ها

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

class TeacherCoursesCurriculumScreen extends StatefulWidget {
  const TeacherCoursesCurriculumScreen({super.key});

  @override
  State<TeacherCoursesCurriculumScreen> createState() => _TeacherCoursesCurriculumScreenState();
}

class _TeacherCoursesCurriculumScreenState extends State<TeacherCoursesCurriculumScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<CourseCurriculumItem> courses = [];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
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

      if (data != null) {
        setState(() {
          courses = (data as List).map((c) => CourseCurriculumItem.fromJson(c)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching curriculum courses: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: const Icon(Icons.menu_book_rounded, color: primaryPink, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Course Curriculum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        SizedBox(height: 3),
                        Text("Manage your published video courses and materials.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
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
                      MaterialPageRoute(builder: (_) => const TeacherCreateCourseScreen()),
                    ).then((_) => _fetchCourses());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= لیست گرید کورس‌ها =================
          isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink)))
              : courses.isNotEmpty
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
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
                                  height: 100,
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
                                  padding: const EdgeInsets.all(12.0),
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
                                              Text(course.category.toUpperCase(),
                                                  style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                              Text("\$${course.price.toStringAsFixed(0)}",
                                                  style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(course.title,
                                              style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12),
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
                                            // 👈 هدایت صحیح به صفحه TeacherCoursesScreen (teacher_courses_screen.dart)
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const TeacherCoursesScreen(),
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
    );
  }
}