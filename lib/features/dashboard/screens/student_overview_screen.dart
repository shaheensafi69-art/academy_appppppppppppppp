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

  Map<String, int> stats = {
    'enrolledCourses': 0,
    'totalScore': 0,
    'certificates': 0,
  };

  Map<String, dynamic>? activeCourse;

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

      // ۱. پروفایل کاربر
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

      // ۲. تعداد دوره‌ها و مدارک
      final enrollmentsCount = await supabase
          .from("class_students")
          .count(CountOption.exact)
          .eq("student_id", userId);

      final certsCount = await supabase
          .from("certificates")
          .count(CountOption.exact)
          .eq("student_id", userId);

      setState(() {
        stats = {
          'enrolledCourses': enrollmentsCount,
          'totalScore': profile?['total_score'] ?? 0,
          'certificates': certsCount,
        };
      });

      // ۳. آخرین دوره فعال
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
            'thumbnail': 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&q=80&w=800',
            'progress': 35,
          };
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. PREMIUM PROFILE BOX =================
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
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                          color: surfaceWhite,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: student['avatar'].isNotEmpty
                              ? Image.network(student['avatar'], fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    student['first_name'].isNotEmpty ? student['first_name'][0] : 'S',
                                    style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 22),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: lightPinkBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("ACADEMY STUDENT", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${student['first_name']} ${student['last_name']}",
                              style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              student['email'],
                              style: const TextStyle(color: textGrey, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Wallet Balance", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey)),
                        Text("\$${student['wallet'].toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= 2. COLORFUL STATS GRID =================
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _buildStatCard("Enrolled", "${stats['enrolledCourses']}", Icons.menu_book_rounded, Colors.indigo),
                _buildStatCard("Total Score", "${stats['totalScore']}", Icons.bolt_rounded, primaryPink),
                _buildStatCard("Certificates", "${stats['certificates']}", Icons.emoji_events_rounded, Colors.green.shade700),
              ],
            ),
            const SizedBox(height: 24),

            // ================= 3. CONTINUE LEARNING =================
            const Text("Continue Learning", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            activeCourse != null
                ? Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                              child: const Text("IN PROGRESS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(activeCourse!['title'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Course Progress", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text("${activeCourse!['progress']}%", style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: activeCourse!['progress'] / 100,
                            backgroundColor: cardBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(primaryPink),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("You haven't enrolled in any courses yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
            ],
          ),
        ],
      ),
    );
  }
}