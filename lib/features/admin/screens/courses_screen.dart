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

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING COURSE LIBRARY...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentFiltered = filteredCourses;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "COURSE LIBRARY",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text("Deploy", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
                          ).then((_) => _fetchCourses());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Manage Courses",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Create and organize educational programs effortlessly.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: primaryPink, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => searchQuery = val),
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: "Search courses by title...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= COURSES LIST =================
            currentFiltered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No courses found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentFiltered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final course = currentFiltered[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: course.id)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: lightPinkBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                                  image: course.thumbnailUrl != null ? DecorationImage(image: NetworkImage(course.thumbnailUrl!), fit: BoxFit.cover) : null,
                                ),
                                child: course.thumbnailUrl == null ? const Icon(Icons.menu_book_rounded, color: primaryPink, size: 28) : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            course.title,
                                            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: course.isPublished ? Colors.green.withOpacity(0.12) : lightPinkBg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            course.isPublished ? "PUBLISHED" : "DRAFT",
                                            style: TextStyle(
                                              color: course.isPublished ? Colors.green.shade700 : primaryPink,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      course.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      course.price > 0 ? "\$${course.price.toStringAsFixed(2)}" : "FREE",
                                      style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}