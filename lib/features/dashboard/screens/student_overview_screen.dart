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
    'first_name': '',
    'last_name': '',
    'avatar': '',
    'email': '',
    'wallet': 0.0,
  };

  Map<String, dynamic> stats = {
    'enrolledCourses': 0,
    'totalScore': 0,
    'certificates': 0,
    'dailyStreak': 5,
    'learningHours': 34.5,
  };

  Map<String, dynamic>? activeCourse;
  List<Map<String, dynamic>> upcomingClasses = [];

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
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

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
        };
      }

      final enrollmentsCount = await supabase
          .from("class_students")
          .count(CountOption.exact)
          .eq("student_id", userId);

      final certsCount = await supabase
          .from("certificates")
          .count(CountOption.exact)
          .eq("student_id", userId);

      setState(() {
        stats['enrolledCourses'] = enrollmentsCount;
        stats['totalScore'] = profile?['total_score'] ?? 0;
        stats['certificates'] = certsCount;
      });

      final latestEnrollment = await supabase
          .from("class_students")
          .select("class_groups(class_name)")
          .eq("student_id", userId)
          .order("enrolled_at", ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestEnrollment != null && latestEnrollment['class_groups'] != null) {
        final courseData = latestEnrollment['class_groups'] is List
            ? (latestEnrollment['class_groups'] as List).isNotEmpty ? latestEnrollment['class_groups'][0] : null
            : latestEnrollment['class_groups'];

        if (courseData != null) {
          activeCourse = {
            'title': courseData['class_name'] ?? 'Untitled Course',
            'progress': 42,
          };
        }
      }

      upcomingClasses = [
        {
          'title': 'Advanced Financial Markets & Risk Management',
          'time': 'Today, 04:00 PM',
          'instructor': 'Prof. Alex Safi',
          'isMissed': false,
        },
        {
          'title': 'Forex Price Action Masterclass',
          'time': 'Yesterday, 06:00 PM',
          'instructor': 'Mentor David',
          'isMissed': true,
        },
      ];
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
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
                  child: Text(liveClass['isMissed'] ? "MISSED SESSION" : "UPCOMING LIVE", style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, color: textGrey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Text(liveClass['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
            const SizedBox(height: 6),
            Text("Instructor: ${liveClass['instructor']} • ${liveClass['time']}", style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (liveClass['isMissed']) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
                  label: const Text("Review Recorded Session", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loading recorded session..."), backgroundColor: Colors.green));
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: primaryPink, side: const BorderSide(color: primaryPink, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text("Reschedule / Book Make-up Class", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Make-up class request submitted!"), backgroundColor: Colors.green));
                  },
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text("Join Live Meeting Room 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting to live meeting..."), backgroundColor: Colors.green));
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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
              Text("LOADING DASHBOARD...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
              // ================= 1. PREMIUM PROFILE & WALLET HEADER =================
              Container(
                padding: const EdgeInsets.all(20),
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
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                            color: surfaceWhite,
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

              // ================= 2. DAILY STREAK & LEARNING HOURS (RESPONSIVE) =================
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isSmall = constraints.maxWidth < 340;
                  if (isSmall) {
                    return Column(
                      children: [
                        _buildMetricCard("DAILY STREAK", "${stats['dailyStreak']} Days", "🔥", Colors.amber),
                        const SizedBox(height: 10),
                        _buildMetricCard("STUDY HOURS", "${stats['learningHours']} Hrs", Icons.access_time_rounded, primaryPink),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _buildMetricCard("DAILY STREAK", "${stats['dailyStreak']} Days", "🔥", Colors.amber)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMetricCard("STUDY HOURS", "${stats['learningHours']} Hrs", Icons.access_time_rounded, primaryPink)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // ================= 3. COLORFUL STATS GRID (RESPONSIVE) =================
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 500 ? 3 : 3;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: constraints.maxWidth > 500 ? 1.4 : 1.05,
                    children: [
                      _buildStatCard("Enrolled", "${stats['enrolledCourses']}", Icons.menu_book_rounded, Colors.indigo),
                      _buildStatCard("Score", "${stats['totalScore']}", Icons.bolt_rounded, primaryPink),
                      _buildStatCard("Certs", "${stats['certificates']}", Icons.emoji_events_rounded, Colors.green.shade700),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ================= 4. CONTINUE LEARNING WITH PROGRESS CIRCLE =================
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

              // ================= 5. UPCOMING & MISSED CLASSES =================
              const Text("Upcoming & Recent Classes", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcomingClasses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final liveClass = upcomingClasses[index];
                  bool isMissed = liveClass['isMissed'];

                  return GestureDetector(
                    onTap: () => _showSessionActionModal(liveClass),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isMissed ? Colors.red.withOpacity(0.3) : cardBorder, width: 1.5),
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
                                  decoration: BoxDecoration(color: isMissed ? Colors.red.withOpacity(0.1) : lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(isMissed ? Icons.video_camera_front_rounded : Icons.live_tv_rounded, color: isMissed ? Colors.redAccent : primaryPink, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(liveClass['title'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text("${liveClass['time']} • ${liveClass['instructor']}", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: isMissed ? Colors.red.withOpacity(0.1) : lightPinkBg, borderRadius: BorderRadius.circular(10)),
                            child: Text(isMissed ? "Review" : "Join 🚀", style: TextStyle(color: isMissed ? Colors.redAccent : primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
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