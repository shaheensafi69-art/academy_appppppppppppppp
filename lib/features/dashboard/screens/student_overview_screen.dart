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
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellowAccent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= 1. PREMIUM PROFILE BOX =================
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1a1a24), Color(0xFF0a0a0f)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.yellowAccent.withOpacity(0.3), width: 1.5),
                        color: Colors.black54,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: student['avatar'].isNotEmpty
                            ? Image.network(student['avatar'], fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  student['first_name'].isNotEmpty ? student['first_name'][0] : 'S',
                                  style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 20),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.yellowAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.yellowAccent.withOpacity(0.2)),
                            ),
                            child: const Text("ACADEMY STUDENT", style: TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.yellowAccent, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${student['first_name']} ${student['last_name']}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student['email'],
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Wallet Balance", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("\$${student['wallet'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ================= 2. COLORFUL STATS GRID =================
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1, // Adjusted for better visual balance
            children: [
              _buildStatCard("Enrolled", "${stats['enrolledCourses']}", "📚", Colors.blueAccent),
              _buildStatCard("Total Score", "${stats['totalScore']}", "⚡", Colors.purpleAccent),
              _buildStatCard("Certificates", "${stats['certificates']}", "🏆", Colors.green),
            ],
          ),
          const SizedBox(height: 16),

          // ================= 3. CONTINUE LEARNING =================
          const Text("Continue Learning", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          activeCourse != null
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF261c0a), Color(0xFF0a0a0f)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: const Text("IN PROGRESS", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(activeCourse!['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Course Progress", style: TextStyle(color: Colors.grey, fontSize: 9)),
                          Text("${activeCourse!['progress']}%", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: activeCourse!['progress'] / 100,
                          backgroundColor: Colors.black.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text("You haven't enrolled in any courses yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 1),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}