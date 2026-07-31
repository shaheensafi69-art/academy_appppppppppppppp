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
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("⚠️", style: TextStyle(fontSize: 10)),
            SizedBox(width: 4),
            Text("EXPIRED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.redAccent)),
          ],
        ),
      );
    }

    bool isExpiringSoon = days <= 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpiringSoon ? Colors.red.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpiringSoon ? Colors.red.withOpacity(0.3) : Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isExpiringSoon ? "🔥" : "⏳", style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            "${days}d ${hours.toString().padLeft(2, '0')}h",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isExpiringSoon ? Colors.redAccent : Colors.amberAccent, fontFamily: 'monospace'),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("📚", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("My Courses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Real-time database records and active core tracking.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= تب‌های فیلتر =================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterTab("all", "All Courses", "📚", allCount),
                const SizedBox(width: 8),
                _buildFilterTab("in-progress", "In Progress", "⚡", inProgressCount),
                const SizedBox(width: 8),
                _buildFilterTab("completed", "Completed", "🏆", completedCount),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= لیست دوره‌ها =================
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : filteredCourses.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredCourses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final course = filteredCourses[index];
                        final expired = _isCourseExpired(course.enrolledAt);

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: expired ? Colors.red.withOpacity(0.2) : Colors.amber.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                                    child: Image.network(
                                      course.thumbnail,
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(height: 140, color: Colors.black54),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(course.category.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: ExpirationCounter(enrolledDate: course.enrolledAt),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: expired ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        expired ? "COMPLETED (ACCESS FINISHED)" : "IN PROGRESS (ACTIVE SESSION)",
                                        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: expired ? Colors.redAccent : Colors.greenAccent),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(course.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("Instructor: ${course.instructor}", style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Progress", style: TextStyle(color: Colors.grey, fontSize: 9)),
                                        Text("${course.progress}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: course.progress / 100,
                                        backgroundColor: Colors.black.withOpacity(0.5),
                                        valueColor: AlwaysStoppedAnimation<Color>(expired ? Colors.redAccent : Colors.amberAccent),
                                        minHeight: 5,
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
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: const Text("No courses found matching this filter.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, String emoji, int count) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text("$count", style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}