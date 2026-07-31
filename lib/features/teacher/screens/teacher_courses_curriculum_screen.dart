import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_create_course_screen.dart';

class CourseCurriculumItem {
  final String id;
  final String title;
  final String category;
  final String? thumbnailUrl;

  CourseCurriculumItem({
    required this.id,
    required this.title,
    required this.category,
    this.thumbnailUrl,
  });

  factory CourseCurriculumItem.fromJson(Map<String, dynamic> json) {
    return CourseCurriculumItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'General',
      thumbnailUrl: json['thumbnail_url'],
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
          .select("id, title, category, thumbnail_url")
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر صفحه
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
                      child: const Text("📚", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Course Curriculum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        SizedBox(height: 2),
                        Text("Manage your published video courses.", style: TextStyle(fontSize: 9, color: Colors.grey)),
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
                      MaterialPageRoute(builder: (_) => const TeacherCreateCourseScreen()),
                    ).then((_) => _fetchCourses());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // لیست گرید کورس‌ها
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : courses.isNotEmpty
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                child: SizedBox(
                                  height: 90,
                                  width: double.infinity,
                                  child: course.thumbnailUrl != null
                                      ? Image.network(course.thumbnailUrl!, fit: BoxFit.cover)
                                      : Container(color: Colors.grey.shade800, child: const Icon(Icons.book, color: Colors.grey)),
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
                                          Text(course.category.toUpperCase(), style: const TextStyle(color: Colors.pinkAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(course.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 28,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(color: Colors.white12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () {},
                                          child: const Text("Manage", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text("No courses published yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}