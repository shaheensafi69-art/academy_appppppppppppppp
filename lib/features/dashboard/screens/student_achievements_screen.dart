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

      if (certData is List) {
        certificates = certData.map((cert) => CertificateItem.fromJson(cert)).toList();
      }

      // ۳. دریافت نشان‌ها و افتخارات
      final awardData = await supabase
          .from("student_awards")
          .select("id, awarded_at, awards(title, description, icon_url)")
          .eq("student_id", userId)
          .order("awarded_at", ascending: false);

      if (awardData is List) {
        awards = awardData.map((item) => AwardItem.fromJson(item)).toList();
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
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING ACHIEVEMENTS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
            // ================= هدر مینیمال و واکنش‌گرا =================
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("My Achievements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        const SizedBox(height: 4),
                        const Text("A structured record of your academic milestones.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: lightPinkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: primaryPink, size: 14),
                        const SizedBox(width: 4),
                        Text("$totalScore Pts", style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= بخش گواهینامه‌ها =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Official Certificates", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                  child: Text("${certificates.length}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            certificates.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: certificates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final cert = certificates[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
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
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: lightPinkBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                                  ),
                                  child: const Icon(Icons.verified_outlined, color: primaryPink, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("VERIFIED CREDENTIAL", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1)),
                                      const SizedBox(height: 2),
                                      Text(
                                        cert.courseName,
                                        style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Issued: ${_formatDate(cert.issueDate)}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                Flexible(
                                  child: Text(
                                    "ID: ${cert.certificateCode}",
                                    style: const TextStyle(color: textGrey, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: lightPinkBg,
                                  foregroundColor: primaryPink,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text("View PDF", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                onPressed: () => _launchURL(cert.certificateUrl),
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
                    child: const Text("No Certificates Yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 28),

            // ================= ویترین نشان‌ها (Badges & Honors) =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Badges & Honors", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                  child: Text("${awards.length}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            awards.isNotEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      // تنظیم هوشمند ابعاد گرید بر اساس عرض صفحه گوشی
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: awards.length,
                        itemBuilder: (context, index) {
                          final award = awards[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: lightPinkBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(award.iconUrl, style: const TextStyle(fontSize: 20)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  award.title,
                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  award.description,
                                  style: const TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(_formatDate(award.awardedAt), style: const TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
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
                    child: const Text("No Badges Yet.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}