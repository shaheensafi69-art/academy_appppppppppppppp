import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_course_screen.dart';
import 'course_detail_screen.dart';

class CourseItemModel {
  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final double price;
  final bool isPublished;
  final String createdAt;

  CourseItemModel({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    required this.price,
    required this.isPublished,
    required this.createdAt,
  });
}

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<CourseItemModel> courses = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("courses")
          .select("id, title, description, thumbnail_url, price, is_published, created_at")
          .order("created_at", ascending: false);

      final List<CourseItemModel> loaded = (response as List).map((c) => CourseItemModel(
        id: c['id'] ?? '',
        title: c['title'] ?? '',
        description: c['description'] ?? '',
        thumbnailUrl: c['thumbnail_url'],
        price: (c['price'] ?? 0).toDouble(),
        isPublished: c['is_published'] ?? false,
        createdAt: c['created_at'] ?? '',
      )).toList();

      if (mounted) {
        setState(() {
          courses = loaded;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<CourseItemModel> get filteredCourses {
    if (searchQuery.isEmpty) return courses;
    final query = searchQuery.toLowerCase();
    return courses.where((c) =>
      c.title.toLowerCase().contains(query) ||
      c.description.toLowerCase().contains(query)
    ).toList();
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
              const CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING COURSE LIBRARY...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredCourses;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.purpleAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
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
                  // Header
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "COURSE LIBRARY",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.purpleAccent, letterSpacing: 1.2),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text("Deploy", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
                                ).then((_) => _fetchCourses());
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text("Manage Courses", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text("Create and organize educational programs.", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
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
                              const Icon(Icons.search, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => setState(() => searchQuery = val),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: "Search courses by title...",
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

                  // Courses Grid
                  currentFiltered.isEmpty
                      ? Container(padding: const EdgeInsets.all(40), alignment: Alignment.center, child: Text("No courses found.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentFiltered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final course = currentFiltered[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: course.id)),
                                );
                              },
                              child: _buildGlassCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(12),
                                        image: course.thumbnailUrl != null ? DecorationImage(image: NetworkImage(course.thumbnailUrl!), fit: BoxFit.cover) : null,
                                      ),
                                      child: course.thumbnailUrl == null ? const Icon(Icons.book, color: Colors.purpleAccent, size: 24) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(course.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: course.isPublished ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(course.isPublished ? "Published" : "Draft", style: TextStyle(color: course.isPublished ? Colors.greenAccent : Colors.amberAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(course.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                          const SizedBox(height: 6),
                                          Text(course.price > 0 ? "\$${course.price}" : "FREE", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 30),
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