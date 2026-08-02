import 'dart:async';
import 'dart:ui';
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
  final int durationWeeks;
  final bool includesCertificate;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.instructor,
    required this.category,
    required this.price,
    required this.durationWeeks,
    required this.includesCertificate,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Course',
      description: json['description']?.toString() ?? 'No description available.',
      thumbnail: json['thumbnail_url']?.toString().isNotEmpty == true
          ? json['thumbnail_url']
          : 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&q=80&w=800',
      instructor: json['instructor_name']?.toString() ?? json['instructor']?.toString() ?? 'Safi Academy Instructor',
      category: json['category']?.toString() ?? 'General',
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      durationWeeks: json['duration_weeks'] != null ? (json['duration_weeks'] as num).toInt() : 4,
      includesCertificate: json['includes_certificate'] ?? true,
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
  Set<String> enrolledCourseIds = {};
  String activeTab = "explore"; // "explore" یا "my_courses"
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
    _fetchCoursesAndEnrollments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoursesAndEnrollments() async {
    setState(() => isLoading = true);
    try {
      // ۱. واکشی امن و کامل تمام دوره‌ها از جدول courses
      final response = await supabase.from("courses").select();
      debugPrint("Fetched Courses Raw: $response");

      List<CourseModel> loadedCourses = [];
      if (response != null && response is List) {
        loadedCourses = response.map((item) => CourseModel.fromJson(item)).toList();
      }

      // ۲. واکشی دوره‌های ثبت‌نام شده دانشجو از جدول enrollments
      Set<String> enrolledIds = {};
      final user = supabase.auth.currentUser;
      if (user != null) {
        try {
          final enrollmentsRes = await supabase
              .from("enrollments")
              .select("course_id")
              .eq("student_id", user.id);

          if (enrollmentsRes != null && enrollmentsRes is List) {
            for (var item in enrollmentsRes) {
              if (item['course_id'] != null) {
                enrolledIds.add(item['course_id'].toString());
              }
            }
          }
        } catch (e) {
          debugPrint("Note: Enrolled check error: $e");
        }
      }

      setState(() {
        allCourses = loadedCourses;
        enrolledCourseIds = enrolledIds;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading courses: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myEnrolledList = allCourses.where((c) => enrolledCourseIds.contains(c.id)).toList();
    
    final displayedCourses = (activeTab == "my_courses" ? myEnrolledList : allCourses).where((c) {
      return c.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          c.instructor.toLowerCase().contains(searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING ACADEMY HUB...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
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

              // ================= سوئیچ بین Explore و My Enrolled =================
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
                          child: Text("My Enrolled (${myEnrolledList.length})", style: TextStyle(color: activeTab == "my_courses" ? primaryPink : textGrey, fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ================= نوار جستجو =================
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

              // ================= لیست دوره‌ها =================
              displayedCourses.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedCourses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final course = displayedCourses[index];
                        final isAlreadyEnrolled = enrolledCourseIds.contains(course.id);

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
                                      errorBuilder: (_, __, ___) => Container(height: 150, color: cardBorder),
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
                                  if (isAlreadyEnrolled)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(8)),
                                        child: const Text("ENROLLED ✓", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
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
                                    Text("Instructor: ${course.instructor} • ${course.durationWeeks} Weeks", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                              _fetchCoursesAndEnrollments();
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
    );
  }
}