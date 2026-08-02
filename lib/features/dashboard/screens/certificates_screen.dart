import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificateItem {
  final String id;
  final String courseTitle;
  final String certificateCode;
  final String issueDate;
  final String? certificateUrl;

  CertificateItem({
    required this.id,
    required this.courseTitle,
    required this.certificateCode,
    required this.issueDate,
    this.certificateUrl,
  });

  factory CertificateItem.fromJson(Map<String, dynamic> json, String courseTitle) {
    return CertificateItem(
      id: json['id']?.toString() ?? '',
      courseTitle: courseTitle,
      certificateCode: json['certificate_code'] ?? 'SAF-CERT-000',
      issueDate: json['issue_date'] ?? '',
      certificateUrl: json['certificate_url'],
    );
  }
}

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<CertificateItem> certificates = [];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
  }

  Future<void> _fetchCertificates() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // واکشی گواهینامه‌های شاگرد به همراه اطلاعات دوره‌ها از جدول certificates و courses
      final response = await supabase
          .from("certificates")
          .select("id, certificate_code, issue_date, certificate_url, course_id, courses(title)")
          .eq("student_id", userId);

      if (response is List) {
        certificates = response.map((item) {
          final courseObj = item['courses'];
          final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;
          final courseTitle = courseData?['title'] ?? 'Professional Course';

          return CertificateItem.fromJson(item, courseTitle);
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching certificates: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                      child: const Icon(Icons.workspace_premium_rounded, color: primaryPink, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("My Certificates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("View, download, and share your official academy achievements.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Earned Credentials", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                  : certificates.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: certificates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final cert = certificates[index];
                            return Container(
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                        child: Text("Verified Certificate ✅", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                      Text("ID: ${cert.certificateCode}", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(cert.courseTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text("Issued on: ${cert.issueDate.split('T')[0]}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.styleFrom != null ? ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: lightPinkBg,
                                            foregroundColor: primaryPink,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: cert.certificateUrl != null ? () => _launchURL(cert.certificateUrl!) : null,
                                          child: const Text("Download PDF 📄", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                        ) : const SizedBox(),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cardBorder,
                                            foregroundColor: textDark,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Certificate ID ${cert.certificateCode} copied to clipboard!")),
                                            );
                                          },
                                          child: const Text("Share / LinkedIn 🔗", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                    ],
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
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: const Text("No certificates earned yet. Complete courses to get certified!", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}