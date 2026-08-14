import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_course_detail_screen.dart';

class CourseModel {
  final String id;
  final String title;
  final String description;
  final String thumbnail;
  final String instructor;
  final String category;
  final double price;
  final String language;
  final int progressPercentage; // اضافه شده از جدول enrollments

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.instructor,
    required this.category,
    required this.price,
    required this.language,
    this.progressPercentage = 0,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json, {int progress = 0}) {
    return CourseModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Course',
      description: json['description']?.toString() ?? 'No description available.',
      thumbnail: json['thumbnail_url']?.toString().isNotEmpty == true
          ? json['thumbnail_url']
          : 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&q=80&w=800',
      instructor: json['instructor_name']?.toString() ?? 'Safi Academy Instructor',
      category: json['category']?.toString() ?? 'General',
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      language: json['language']?.toString() ?? 'English',
      progressPercentage: progress,
    );
  }
}

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  
  List<CourseModel> allCourses = [];
  List<CourseModel> enrolledCourses = [];
  Set<String> enrolledCourseIds = {};
  Set<String> wishlistCourseIds = {};
  
  String activeTab = "explore"; // "explore" or "my_courses"
  String searchQuery = "";

  final TextEditingController _searchController = TextEditingController();

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchCoursesAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoursesAndData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;

      // ۱. واکشی تمام دوره‌ها از جدول courses
      final response = await supabase.from("courses").select();
      
      Map<String, int> enrollmentProgressMap = {};
      Set<String> wishlistIds = {};

      if (user != null) {
        // ۲. واکشی اطلاعات ثبت‌نام و درصد پیشرفت از جدول enrollments
        try {
          final enrollmentsRes = await supabase
              .from("enrollments")
              .select("course_id, progress_percentage")
              .eq("student_id", user.id);

          for (var item in enrollmentsRes as List) {
            if (item['course_id'] != null) {
              String cId = item['course_id'].toString();
              int prog = (item['progress_percentage'] ?? 0).toInt();
              enrollmentProgressMap[cId] = prog;
            }
          }
        } catch (e) {
          debugPrint("Note: Enrolled check error: $e");
        }

        // ۳. واکشی علاقه‌مندی‌ها از جدول wishlists
        try {
          final wishlistRes = await supabase
              .from("wishlists")
              .select("course_id")
              .eq("student_id", user.id);

          for (var item in wishlistRes as List) {
            if (item['course_id'] != null) {
              wishlistIds.add(item['course_id'].toString());
            }
          }
        } catch (e) {
          debugPrint("Note: Wishlist check error: $e");
        }
      }

      List<CourseModel> loadedAll = [];
      List<CourseModel> loadedEnrolled = [];

      for (var item in (response as List)) {
        String cId = item['id']?.toString() ?? '';
        int progress = enrollmentProgressMap[cId] ?? 0;
        bool isEnrolled = enrollmentProgressMap.containsKey(cId);

        CourseModel course = CourseModel.fromJson(item, progress: progress);
        loadedAll.add(course);

        if (isEnrolled) {
          loadedEnrolled.add(course);
        }
      }

      setState(() {
        allCourses = loadedAll;
        enrolledCourses = loadedEnrolled;
        enrolledCourseIds = enrollmentProgressMap.keys.toSet();
        wishlistCourseIds = wishlistIds;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading courses: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleWishlist(String courseId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    bool isWishlisted = wishlistCourseIds.contains(courseId);

    setState(() {
      if (isWishlisted) {
        wishlistCourseIds.remove(courseId);
      } else {
        wishlistCourseIds.add(courseId);
      }
    });

    try {
      if (isWishlisted) {
        await supabase
            .from("wishlists")
            .delete()
            .eq("student_id", user.id)
            .eq("course_id", courseId);
      } else {
        await supabase.from("wishlists").insert({
          "student_id": user.id,
          "course_id": courseId,
        });
      }
    } catch (e) {
      debugPrint("Error toggling wishlist: $e");
      setState(() {
        if (isWishlisted) {
          wishlistCourseIds.add(courseId);
        } else {
          wishlistCourseIds.remove(courseId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceList = activeTab == "my_courses" ? enrolledCourses : allCourses;
    
    final displayedCourses = sourceList.where((c) {
      return c.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          c.instructor.toLowerCase().contains(searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return AcademyLoadingOverlay(
      isLoading: isLoading,
      message: "LOADING ACADEMY HUB...",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // هدر صفحه
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: primaryPink, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Academy Learning Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                            SizedBox(height: 3),
                            Text("Explore masterclasses, view your enrollments & upgrade skills.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // سوئیچ تب‌ها
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardBorder,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => activeTab = "explore"),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: activeTab == "explore" ? surfaceWhite : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: activeTab == "explore" ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : [],
                            ),
                            child: Text("Explore All (${allCourses.length})", style: TextStyle(color: activeTab == "explore" ? primaryPink : textGrey, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => activeTab = "my_courses"),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: activeTab == "my_courses" ? surfaceWhite : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: activeTab == "my_courses" ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : [],
                            ),
                            child: Text("My Enrolled (${enrolledCourses.length})", style: TextStyle(color: activeTab == "my_courses" ? primaryPink : textGrey, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // نوار جستجو
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Search masterclasses by title, category, instructor...",
                    hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                    prefixIcon: const Icon(Icons.search_rounded, color: primaryPink, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: textGrey, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = "");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardBorder.withOpacity(0.6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),

                // لیست دوره‌ها
                displayedCourses.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedCourses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final course = displayedCourses[index];
                          final isAlreadyEnrolled = enrolledCourseIds.contains(course.id);
                          final isWishlisted = wishlistCourseIds.contains(course.id);

                          return Container(
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                                      child: Image.network(
                                        course.thumbnail,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(height: 150, color: cardBorder),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(8)),
                                        child: Text(course.category.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                                      ),
                                    ),
                                    // دکمه ویشلیست
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () => _toggleWishlist(course.id),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                                          ),
                                          child: Icon(
                                            isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            color: primaryPink,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isAlreadyEnrolled)
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(8)),
                                          child: Text("PROGRESS: ${course.progressPercentage}% ✓", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                                        ),
                                      ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(course.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text("Instructor: ${course.instructor} • ${course.language}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            course.price > 0 ? "\$${course.price.toStringAsFixed(2)}" : "FREE",
                                            style: TextStyle(color: course.price > 0 ? primaryPink : Colors.green.shade700, fontWeight: FontWeight.w900, fontSize: 14),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isAlreadyEnrolled ? Colors.green.shade700 : primaryPink,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            ),
                                            onPressed: () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => StudentCourseDetailScreen(courseId: course.id)),
                                              );
                                              if (result == true) {
                                                _fetchCoursesAndData();
                                              }
                                            },
                                            child: Text(isAlreadyEnrolled ? "View Hub 🚀" : "View Details 🚀", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                      ),
                                    ],
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
                          border: Border.all(color: cardBorder, width: 1.5),
                        ),
                        child: const Text("No masterclasses found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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

// ============================================================================
// ویجت کاستوم لودینگ آکادمی
// ============================================================================

class AcademyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AcademyLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = "LOADING...",
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withOpacity(0.95),
            alignment: Alignment.center,
            child: _AcademyThinkingLoadingAnimation(message: message),
          ),
      ],
    );
  }
}

class _AcademyThinkingLoadingAnimation extends StatefulWidget {
  final String message;
  const _AcademyThinkingLoadingAnimation({required this.message});

  @override
  State<_AcademyThinkingLoadingAnimation> createState() => _AcademyThinkingLoadingAnimationState();
}

class _AcademyThinkingLoadingAnimationState extends State<_AcademyThinkingLoadingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      const Color(0xFFC2185B).withOpacity(0.0),
                      const Color(0xFFC2185B).withOpacity(0.8),
                      const Color(0xFFC2185B),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC2185B).withOpacity(0.25), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.girl_rounded,
                    size: 54,
                    color: Color(0xFFC2185B),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: Color(0xFFC2185B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          widget.message,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}