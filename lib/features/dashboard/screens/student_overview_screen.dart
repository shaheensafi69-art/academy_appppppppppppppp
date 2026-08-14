import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentOverviewScreen extends StatefulWidget {
  const StudentOverviewScreen({super.key});

  @override
  State<StudentOverviewScreen> createState() => _StudentOverviewScreenState();
}

class _StudentOverviewScreenState extends State<StudentOverviewScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  Map<String, dynamic> student = {
    'first_name': 'Student',
    'last_name': '',
    'avatar': '',
    'email': '',
    'wallet': 0.0,
    'total_score': 0,
  };

  Map<String, dynamic> stats = {
    'enrolledCourses': 0,
    'certificates': 0,
    'dailyStreak': 0,
    'longestStreak': 0,
  };

  Map<String, dynamic>? activeCourse;
  List<Map<String, dynamic>> activeClasses = [];

  // پالت رنگی پرمیوم و هماهنگ با دیزاین مرجع
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchRealDashboardData();
  }

  Future<void> _fetchRealDashboardData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // ۱. واکشی اطلاعات پروفایل از جدول profiles
      final profile = await supabase
          .from("profiles")
          .select("first_name, last_name, avatar_url, email, total_score, wallet_balance")
          .eq("id", userId)
          .maybeSingle();

      if (profile != null) {
        student = {
          'first_name': profile['first_name'] ?? 'Student',
          'last_name': profile['last_name'] ?? '',
          'avatar': profile['avatar_url'] ?? '',
          'email': profile['email'] ?? user.email ?? '',
          'wallet': (profile['wallet_balance'] ?? 0).toDouble(),
          'total_score': profile['total_score'] ?? 0,
        };
      }

      // ۲. شمارش تعداد دوره‌های ثبت‌نام شده از جدول enrollments
      final enrollmentsCount = await supabase
          .from("enrollments")
          .count(CountOption.exact)
          .eq("student_id", userId);

      // ۳. شمارش تعداد گواهینامه‌ها از جدول certificates
      final certsCount = await supabase
          .from("certificates")
          .count(CountOption.exact)
          .eq("student_id", userId);

      // ۴. واکشی استریک‌ها از جدول student_streaks
      final streakData = await supabase
          .from("student_streaks")
          .select("current_streak, longest_streak")
          .eq("student_id", userId)
          .maybeSingle();

      setState(() {
        stats['enrolledCourses'] = enrollmentsCount;
        stats['certificates'] = certsCount;
        stats['dailyStreak'] = streakData?['current_streak'] ?? 0;
        stats['longestStreak'] = streakData?['longest_streak'] ?? 0;
      });

      // ۵. واکشی آخرین دوره در حال یادگیری از جدول enrollments همراه با اطلاعات جدول courses
      final latestEnrollment = await supabase
          .from("enrollments")
          .select("progress_percentage, courses(title)")
          .eq("student_id", userId)
          .order("enrolled_at", ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestEnrollment != null && latestEnrollment['courses'] != null) {
        final courseObj = latestEnrollment['courses'];
        final courseTitle = courseObj is List 
            ? (courseObj.isNotEmpty ? courseObj[0]['title'] : 'Active Course')
            : courseObj['title'] ?? 'Active Course';

        activeCourse = {
          'title': courseTitle,
          'progress': latestEnrollment['progress_percentage'] ?? 0,
        };
      }

      // ۶. واکشی کلاس‌های زنده مرتبط با دانشجو از جدول class_students و class_groups
      final studentClasses = await supabase
          .from("class_students")
          .select("class_groups(class_name, meeting_link, class_time, class_days, is_active)")
          .eq("student_id", userId);

      List<Map<String, dynamic>> parsedClasses = [];
      for (var item in (studentClasses as List)) {
        if (item['class_groups'] != null) {
          final group = item['class_groups'];
          parsedClasses.add({
            'title': group['class_name'] ?? 'Live Campus Session',
            'time': "${group['class_days'] ?? ''} • ${group['class_time'] ?? ''}",
            'meeting_link': group['meeting_link'] ?? '',
            'is_active': group['is_active'] ?? true,
          });
        }
      }
      activeClasses = parsedClasses;

    } catch (e) {
      debugPrint("Error fetching real dashboard data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSessionActionModal(Map<String, dynamic> liveClass) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                  child: const Text("LIVE CAMPUS SESSION", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, color: textGrey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Text(liveClass['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
            const SizedBox(height: 6),
            Text("Schedule: ${liveClass['time']}", style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.video_call_rounded, size: 18),
                label: const Text("Join Live Meeting Room 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening meeting link..."), backgroundColor: Colors.green));
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AcademyLoadingOverlay(
      isLoading: isLoading,
      message: "LOADING DASHBOARD...",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5), surfaceWhite, lightPinkBg.withOpacity(0.2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= 1. PROFILE & WALLET HEADER =================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                                color: lightPinkBg,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: student['avatar'].isNotEmpty
                                    ? Image.network(student['avatar'], fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          student['first_name'].isNotEmpty ? student['first_name'][0] : 'S',
                                          style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 20),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                    child: const Text("ACADEMY STUDENT", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1)),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "${student['first_name']} ${student['last_name']}",
                                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(student['email'], style: const TextStyle(color: textGrey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardBorder.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Wallet Balance", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey)),
                              Text("\$${student['wallet'].toStringAsFixed(2)}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= 2. DAILY STREAK =================
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard("DAILY STREAK", "${stats['dailyStreak']} Days", "🔥", Colors.amber)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMetricCard("LONGEST STREAK", "${stats['longestStreak']} Days", "⚡", primaryPink)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= 3. STATS GRID =================
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      _buildStatCard("Enrolled", "${stats['enrolledCourses']}", Icons.menu_book_rounded, Colors.indigo),
                      _buildStatCard("Score", "${student['total_score']}", Icons.bolt_rounded, primaryPink),
                      _buildStatCard("Certs", "${stats['certificates']}", Icons.emoji_events_rounded, Colors.green.shade700),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ================= 4. CONTINUE LEARNING =================
                  const Text("Continue Learning", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 10),
                  activeCourse != null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: activeCourse!['progress'] / 100,
                                      backgroundColor: cardBorder,
                                      valueColor: const AlwaysStoppedAnimation<Color>(primaryPink),
                                      strokeWidth: 5,
                                    ),
                                    Center(
                                      child: Text(
                                        "${activeCourse!['progress']}%",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(6)),
                                      child: const Text("IN PROGRESS", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: primaryPink)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      activeCourse!['title'],
                                      style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder, width: 1.5)),
                          child: const Text("You haven't enrolled in any courses yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                  const SizedBox(height: 20),

                  // ================= 5. LIVE CLASSES =================
                  const Text("Active Live Campus Classes", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 10),
                  activeClasses.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeClasses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final liveClass = activeClasses[index];

                            return GestureDetector(
                              onTap: () => _showSessionActionModal(liveClass),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorder, width: 1.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                            child: const Icon(Icons.live_tv_rounded, color: primaryPink, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(liveClass['title'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 2),
                                                Text(liveClass['time'], style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                                      child: const Text("Join 🚀", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder, width: 1.5)),
                          child: const Text("No active class groups found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, dynamic iconOrEmoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: iconOrEmoji is String
                ? Text(iconOrEmoji, style: const TextStyle(fontSize: 16))
                : Icon(iconOrEmoji, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ویجت کاستوم لودینگ آکادمی (انیمیشن دختر دانشجو)
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