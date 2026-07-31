import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnrolledCourse {
  final String id;
  final String courseId;
  final String title;
  final String thumbnail;
  final String instructor;
  final String category;
  final int progress;
  final String enrolledAt;

  EnrolledCourse({
    required this.id,
    required this.courseId,
    required this.title,
    required this.thumbnail,
    required this.instructor,
    required this.category,
    required this.progress,
    required this.enrolledAt,
  });

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    final courseObj = json['courses'];
    final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;

    return EnrolledCourse(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      title: courseData?['title'] ?? 'Premium Academy Course',
      thumbnail: courseData?['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&q=80&w=800',
      instructor: courseData?['instructor_name'] ?? 'Safi Academy Instructor',
      category: courseData?['category'] ?? 'Trading',
      progress: json['progress_percentage'] ?? 0,
      enrolledAt: json['enrolled_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

// =====================================================================
// کامپوننت هوشمند محاسباتی زمان باقیمانده واقعی بر اساس فیلد enrolled_at دیتابیس
// =====================================================================
class ExpirationCounter extends StatefulWidget {
  final String enrolledDate;
  const ExpirationCounter({super.key, required this.enrolledDate});

  @override
  State<ExpirationCounter> createState() => _ExpirationCounterState();
}

class _ExpirationCounterState extends State<ExpirationCounter> {
  Timer? _timer;
  int days = 0;
  int hours = 0;
  int mins = 0;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _calculateTimeLeft());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeLeft() {
    try {
      final enrollmentTime = DateTime.parse(widget.enrolledDate).millisecondsSinceEpoch;
      const expirationDuration = 30 * 24 * 60 * 60 * 1000; // مهلت دقیق ۳۰ روزه اشتراک
      final expirationTime = enrollmentTime + expirationDuration;
      final now = DateTime.now().millisecondsSinceEpoch;
      final difference = expirationTime - now;

      if (difference > 0) {
        setState(() {
          days = (difference / (1000 * 60 * 60 * 24)).floor();
          hours = ((difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)).floor();
          mins = ((difference % (1000 * 60 * 60)) / (1000 * 60)).floor();
          isInitialized = true;
        });
      } else {
        setState(() {
          days = 0;
          hours = 0;
          mins = 0;
          isInitialized = true;
        });
      }
    } catch (_) {
      setState(() => isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) return const SizedBox(width: 60, height: 24);

    if (days == 0 && hours == 0 && mins == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 12),
            SizedBox(width: 4),
            Text("EXPIRED", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.redAccent)),
          ],
        ),
      );
    }

    bool isExpiringSoon = days <= 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpiringSoon ? Colors.red.withOpacity(0.12) : const Color(0xFFC2185B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpiringSoon ? Colors.red.withOpacity(0.3) : const Color(0xFFC2185B).withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isExpiringSoon ? Icons.local_fire_department_rounded : Icons.timer_rounded, color: isExpiringSoon ? Colors.redAccent : const Color(0xFFC2185B), size: 12),
          const SizedBox(width: 4),
          Text(
            "${days}d ${hours.toString().padLeft(2, '0')}h",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isExpiringSoon ? Colors.redAccent : const Color(0xFFC2185B), fontFamily: 'monospace'),
          ),
        ],
      ),
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
  List<EnrolledCourse> courses = [];
  String filter = "all"; // "all", "in-progress", "completed"

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
    _fetchMyCourses();
  }

  Future<void> _fetchMyCourses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final enrollments = await supabase
          .from("enrollments")
          .select("id, course_id, progress_percentage, enrolled_at, courses(title, thumbnail_url, instructor_name, category)")
          .eq("student_id", user.id)
          .order("enrolled_at", ascending: false);

      setState(() {
        courses = (enrollments as List).map((item) => EnrolledCourse.fromJson(item)).toList();
      });
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool _isCourseExpired(String enrolledAt) {
    try {
      final enrollmentTime = DateTime.parse(enrolledAt).millisecondsSinceEpoch;
      const expirationDuration = 30 * 24 * 60 * 60 * 1000;
      return DateTime.now().millisecondsSinceEpoch > (enrollmentTime + expirationDuration);
    } catch (_) {
      return false;
    }
  }

  List<EnrolledCourse> get filteredCourses {
    return courses.where((course) {
      final expired = _isCourseExpired(course.enrolledAt);
      if (filter == "completed") return expired;
      if (filter == "in-progress") return !expired;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    int allCount = courses.length;
    int inProgressCount = courses.where((c) => !_isCourseExpired(c.enrolledAt)).length;
    int completedCount = courses.where((c) => _isCourseExpired(c.enrolledAt)).length;

    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING COURSES...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("My Courses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        const SizedBox(height: 3),
                        const Text("Real-time database records and active core tracking.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= تب‌های فیلتر =================
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterTab("all", "All Courses", Icons.library_books_rounded, allCount),
                  const SizedBox(width: 10),
                  _buildFilterTab("in-progress", "In Progress", Icons.bolt_rounded, inProgressCount),
                  const SizedBox(width: 10),
                  _buildFilterTab("completed", "Completed", Icons.emoji_events_rounded, completedCount),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= لیست دوره‌ها =================
            filteredCourses.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredCourses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final course = filteredCourses[index];
                      final expired = _isCourseExpired(course.enrolledAt);

                      return Container(
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: expired ? Colors.red.withOpacity(0.3) : cardBorder, width: 1.5),
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
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(course.category.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: ExpirationCounter(enrolledDate: course.enrolledAt),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: expired ? Colors.red.withOpacity(0.1) : lightPinkBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      expired ? "COMPLETED (ACCESS FINISHED)" : "IN PROGRESS (ACTIVE SESSION)",
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: expired ? Colors.redAccent : primaryPink),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(course.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text("Instructor: ${course.instructor}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Progress", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                      Text("${course.progress}%", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: course.progress / 100,
                                      backgroundColor: cardBorder,
                                      valueColor: AlwaysStoppedAnimation<Color>(expired ? Colors.redAccent : primaryPink),
                                      minHeight: 8,
                                    ),
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
                    child: const Text("No courses found matching this filter.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, IconData icon, int count) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryPink : lightPinkBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryPink : cardBorder, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: primaryPink.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : primaryPink),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : textDark, fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : cardBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("$count", style: TextStyle(color: isSelected ? Colors.white : textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}