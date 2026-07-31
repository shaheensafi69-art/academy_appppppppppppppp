import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificateItem {
  final String id;
  final String courseName;
  final String certificateCode;
  final String issueDate;
  final String certificateUrl;

  CertificateItem({
    required this.id,
    required this.courseName,
    required this.certificateCode,
    required this.issueDate,
    required this.certificateUrl,
  });

  factory CertificateItem.fromJson(Map<String, dynamic> json) {
    final courseObj = json['courses'];
    final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;

    return CertificateItem(
      id: json['id'] ?? '',
      courseName: courseData?['title'] ?? 'Safi Academy Course',
      certificateCode: json['certificate_code'] ?? '',
      issueDate: json['issue_date'] ?? '',
      certificateUrl: json['certificate_url'] ?? '',
    );
  }
}

class AwardItem {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final String awardedAt;

  AwardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.awardedAt,
  });

  factory AwardItem.fromJson(Map<String, dynamic> json) {
    final awardObj = json['awards'];
    final awardDetails = awardObj is List ? (awardObj.isNotEmpty ? awardObj[0] : null) : awardObj;

    return AwardItem(
      id: json['id'] ?? '',
      title: awardDetails?['title'] ?? 'Special Award',
      description: awardDetails?['description'] ?? 'Earned for outstanding performance.',
      iconUrl: awardDetails?['icon_url'] ?? '🏅',
      awardedAt: json['awarded_at'] ?? '',
    );
  }
}

class StudentAchievementsScreen extends StatefulWidget {
  const StudentAchievementsScreen({super.key});

  @override
  State<StudentAchievementsScreen> createState() => _StudentAchievementsScreenState();
}

class _StudentAchievementsScreenState extends State<StudentAchievementsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  int totalScore = 0;
  List<CertificateItem> certificates = [];
  List<AwardItem> awards = [];

  @override
  void initState() {
    super.initState();
    _fetchAchievements();
  }

  Future<void> _fetchAchievements() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // ۱. دریافت پروفایل (امتیاز کل) با متد امن maybeSingle
      final profile = await supabase
          .from("profiles")
          .select("total_score")
          .eq("id", userId)
          .maybeSingle();

      if (profile != null) {
        totalScore = profile['total_score'] ?? 0;
      }

      // ۲. دریافت گواهینامه‌ها
      final certData = await supabase
          .from("certificates")
          .select("id, certificate_code, issue_date, certificate_url, courses(title)")
          .eq("student_id", userId)
          .order("issue_date", ascending: false);

      if (certData != null && certData is List) {
        certificates = certData.map((cert) => CertificateItem.fromJson(cert as Map<String, dynamic>)).toList();
      }

      // ۳. دریافت نشان‌ها و افتخارات
      final awardData = await supabase
          .from("student_awards")
          .select("id, awarded_at, awards(title, description, icon_url)")
          .eq("student_id", userId)
          .order("awarded_at", ascending: false);

      if (awardData != null && awardData is List) {
        awards = awardData.map((item) => AwardItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching achievements: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر مینیمال و قدرتمند =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("My Achievements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text("A structured record of your academic milestones.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.blueAccent, size: 14),
                      const SizedBox(width: 4),
                      Text("$totalScore Pts", style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= بخش گواهینامه‌ها =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Official Certificates", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                child: Text("${certificates.length}", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          certificates.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: certificates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cert = certificates[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                                ),
                                child: const Icon(Icons.verified_outlined, color: Colors.blueAccent, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("VERIFIED CREDENTIAL", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1)),
                                    const SizedBox(height: 2),
                                    Text(cert.courseName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Issued: ${_formatDate(cert.issueDate)}", style: const TextStyle(color: Colors.grey, fontSize: 9)),
                              Text("ID: ${cert.certificateCode}", style: const TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.05),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                                // side: Border.all(color: Colors.white.withOpacity(0.1)), // This line was causing the error
                              ),
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text("View PDF", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              onPressed: () => _launchURL(cert.certificateUrl),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text("No Certificates Yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 24),

          // ================= ویترین نشان‌ها (Badges & Honors) =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Badges & Honors", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                child: Text("${awards.length}", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          awards.isNotEmpty
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: awards.length,
                  itemBuilder: (context, index) {
                    final award = awards[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(award.iconUrl, style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(height: 8),
                          Text(award.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(award.description, style: TextStyle(color: Colors.grey.shade500, fontSize: 8), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Text(_formatDate(award.awardedAt), style: const TextStyle(color: Colors.grey, fontSize: 7)),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text("No Badges Yet.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}