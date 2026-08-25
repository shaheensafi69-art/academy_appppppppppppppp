import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'certificates_detail_screen.dart';

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

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
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

      final response = await supabase
          .from("certificates")
          .select("id, certificate_code, issue_date, certificate_url, course_id, courses(title)")
          .eq("student_id", userId);

      certificates = (response as List).map((item) {
        final courseObj = item['courses'];
        final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : null) : courseObj;
        final courseTitle = courseData?['title'] ?? 'Professional Course';

        return CertificateItem.fromJson(item, courseTitle);
      }).toList();
    } catch (e) {
      debugPrint("Error fetching certificates: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool _isImage(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    return AcademyLoadingOverlay(
      isLoading: isLoading,
      message: "LOADING CERTIFICATES...",
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
              padding: const EdgeInsets.all(16),
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

                  certificates.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: certificates.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final cert = certificates[index];
                            final bool hasUrl = cert.certificateUrl != null && cert.certificateUrl!.isNotEmpty;
                            final bool isImg = _isImage(cert.certificateUrl);

                            return Container(
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorder, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasUrl)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                                      child: isImg
                                          ? Image.network(
                                              cert.certificateUrl!,
                                              height: 160,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => _buildPlaceholderBanner(Icons.broken_image_rounded, "Image preview unavailable"),
                                            )
                                          : _buildPlaceholderBanner(Icons.picture_as_pdf_rounded, "Official PDF Document"),
                                    )
                                  else
                                    _buildPlaceholderBanner(Icons.verified_rounded, "Certified Achievement"),

                                  Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                              child: const Text("Verified Certificate ✅", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
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
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: lightPinkBg,
                                                  foregroundColor: primaryPink,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                icon: const Icon(Icons.visibility_rounded, size: 16),
                                                label: const Text("View In-App 👁️", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                                onPressed: hasUrl
                                                    ? () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => CertificateDetailScreen(certificate: cert),
                                                          ),
                                                        );
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: cardBorder,
                                                  foregroundColor: textDark,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                icon: const Icon(Icons.share_rounded, size: 16),
                                                label: const Text("Share ID 🔗", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                                onPressed: () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text("Certificate ID ${cert.certificateCode} copied to clipboard!")),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
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
        ),
      ),
    );
  }

  Widget _buildPlaceholderBanner(IconData icon, String subtitle) {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryPink.withOpacity(0.08), lightPinkBg.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: surfaceWhite, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 10)]),
            child: Icon(icon, color: primaryPink, size: 28),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ============================================================================
// ویجت کاستوم لودینگ آکادمی
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
                      const Color(0xFFF494AC).withOpacity(0.0),
                      const Color(0xFFF494AC).withOpacity(0.8),
                      const Color(0xFFF494AC),
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
                color: const Color(0xFFFAF4F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF494AC).withOpacity(0.25), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.girl_rounded,
                    size: 54,
                    color: Color(0xFFF494AC),
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
                        color: Color(0xFFF494AC),
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