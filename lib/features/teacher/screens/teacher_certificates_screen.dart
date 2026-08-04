import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_certificates_detail_screen.dart';

class TeacherCertificatesScreen extends StatefulWidget {
  const TeacherCertificatesScreen({super.key});

  @override
  State<TeacherCertificatesScreen> createState() => _TeacherCertificatesScreenState();
}

class _TeacherCertificatesScreenState extends State<TeacherCertificatesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> certificates = [];

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
      final res = await supabase
          .from('certificates')
          .select('*, profiles(first_name, last_name, email), courses(title)')
          .order('issue_date', ascending: false);

      setState(() {
        certificates = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint("Error fetching certificates: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= هدر صفحه ریسپانسیو =================
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: primaryPink.withOpacity(0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWide = constraints.maxWidth > 450;
                        return Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryPink.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.workspace_premium_rounded, color: primaryPink, size: 26),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Manage Certificates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                                      SizedBox(height: 3),
                                      Text("Issue and manage verified certificates for graduates.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isWide ? 0 : 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text("Issue New", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TeacherCertificatesDetailScreen()),
                                );
                                _fetchCertificates();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text("Issued Certificates", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 12),

                  isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                      : certificates.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: certificates.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final cert = certificates[index];
                                final profile = cert['profiles'] as Map<String, dynamic>?;
                                final course = cert['courses'] as Map<String, dynamic>?;

                                final studentName = profile != null ? "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}" : "Student";
                                final courseTitle = course?['title'] ?? 'General Course';
                                final code = cert['certificate_code'] ?? 'N/A';
                                final issueDate = cert['issue_date'] != null ? cert['issue_date'].toString().split('T')[0] : '';

                                return Container(
                                  padding: const EdgeInsets.all(16),
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
                                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(14)),
                                              child: const Icon(Icons.verified_rounded, color: primaryPink, size: 22),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(studentName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 2),
                                                  Text("Course: $courseTitle", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 2),
                                                  Text("Code: $code | Date: $issueDate", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                        child: const Text("VERIFIED", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
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
                                border: Border.all(color: cardBorder),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.workspace_premium_outlined, size: 36, color: textGrey),
                                  SizedBox(height: 10),
                                  Text("No Certificates Issued", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(height: 4),
                                  Text("No certificates have been issued yet.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                                ],
                              ),
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
}