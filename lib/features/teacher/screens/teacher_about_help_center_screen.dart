import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherAboutHelpCenterScreen extends StatefulWidget {
  const TeacherAboutHelpCenterScreen({super.key});

  @override
  State<TeacherAboutHelpCenterScreen> createState() => _TeacherAboutHelpCenterScreenState();
}

class _TeacherAboutHelpCenterScreenState extends State<TeacherAboutHelpCenterScreen> {
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
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
                              child: const Icon(Icons.info_outline_rounded, color: primaryPink, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("About & Faculty Help", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                                  SizedBox(height: 3),
                                  Text("Safi Academy instructor portal, guidelines, and official channels.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= درباره آکادمی (همراه با لوگو در بالا) =================
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: lightPinkBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryPink.withOpacity(0.2)),
                                  ),
                                  child: Image.asset(
                                    'assets/logo-without-b.png',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text("About Safi Academy", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Welcome to the Safi Academy Instructor Portal. As part of our elite faculty, your dedication shapes the future of global education, technical training, and professional trading expertise.\n\n"
                              "Use this portal to manage your courses, grade student assignments, review assessments, and interact with students. "
                              "For direct administration or technical assistance, you can reach out via our official communication channels below.",
                              style: TextStyle(color: textGrey, fontSize: 11, height: 1.6, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= راه‌های ارتباطی مستقیم (ایمیل و شماره تماس) =================
                      const Text("Direct Communications", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, boxConstraints) {
                          bool isWide = boxConstraints.maxWidth > 500;
                          return Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            children: [
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: _buildContactCard(
                                  icon: Icons.email_rounded,
                                  title: "Faculty Email",
                                  subtitle: "info@safiacademy.org",
                                  onTap: () => _launchURL("mailto:info@safiacademy.org"),
                                ),
                              ),
                              SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: _buildContactCard(
                                  icon: Icons.phone_rounded,
                                  title: "Admin Hotline",
                                  subtitle: "+447476620282",
                                  onTap: () => _launchURL("tel:+447476620282"),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ================= شبکه‌های اجتماعی با لوگوهای کوچک و مرتب =================
                      const Text("Official Channels & Socials", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 12),
                      
                      // دکمه ویژه واتساپ
                      _buildFeaturedWhatsAppCard(
                        onTap: () => _launchURL("https://whatsapp.com/channel/0029Vb8WCN9FXUucJwrltI32"),
                      ),
                      const SizedBox(height: 12),

                      // شبکه‌های اجتماعی (ایکس و فیسبوک)
                      LayoutBuilder(
                        builder: (context, gridConstraints) {
                          bool isWideGrid = gridConstraints.maxWidth > 500;
                          if (isWideGrid) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildAssetSocialCard(
                                    title: "X (Twitter)",
                                    subtitle: "safi_academy",
                                    assetPath: "assets/x.com-logo.webp",
                                    onTap: () => _launchURL("https://x.com/safi_academy"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildAssetSocialCard(
                                    title: "Facebook",
                                    subtitle: "Safi Academy",
                                    assetPath: "assets/facebook.com-logo.webp",
                                    onTap: () => _launchURL("https://www.facebook.com/profile.php?id=61591973281742"),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildAssetSocialCard(
                                  title: "X (Twitter)",
                                  subtitle: "safi_academy",
                                  assetPath: "assets/x.com-logo.webp",
                                  onTap: () => _launchURL("https://x.com/safi_academy"),
                                ),
                                const SizedBox(height: 10),
                                _buildAssetSocialCard(
                                  title: "Facebook",
                                  subtitle: "Safi Academy",
                                  assetPath: "assets/facebook.com-logo.webp",
                                  onTap: () => _launchURL("https://www.facebook.com/profile.php?id=61591973281742"),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      
                      // شبکه‌های اجتماعی (اینستاگرام و لینکدین)
                      LayoutBuilder(
                        builder: (context, gridConstraints) {
                          bool isWideGrid = gridConstraints.maxWidth > 500;
                          if (isWideGrid) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildAssetSocialCard(
                                    title: "Instagram",
                                    subtitle: "safi_academy01",
                                    assetPath: "assets/intagram.com-logo.webp",
                                    onTap: () => _launchURL("https://www.instagram.com/safi_academy01?igsh=MXV1ZW44aXBwOHd3NQ=="),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildAssetSocialCard(
                                    title: "LinkedIn",
                                    subtitle: "Safi Academy",
                                    assetPath: "assets/linkedin.com-logo.webp",
                                    onTap: () => _launchURL("https://www.linkedin.com/company/safi-academy/"),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildAssetSocialCard(
                                  title: "Instagram",
                                  subtitle: "safi_academy01",
                                  assetPath: "assets/intagram.com-logo.webp",
                                  onTap: () => _launchURL("https://www.instagram.com/safi_academy01?igsh=MXV1ZW44aXBwOHd3NQ=="),
                                ),
                                const SizedBox(height: 10),
                                _buildAssetSocialCard(
                                  title: "LinkedIn",
                                  subtitle: "Safi Academy",
                                  assetPath: "assets/linkedin.com-logo.webp",
                                  onTap: () => _launchURL("https://www.linkedin.com/company/safi-academy/"),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContactCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: primaryPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedWhatsAppCard({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF25D366).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/whatsapp.com-logo.webp',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("WhatsApp Community Channel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  SizedBox(height: 2),
                  Text("Join our official broadcast channel for instant updates", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetSocialCard({required String title, required String subtitle, required String assetPath, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBorder,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                assetPath,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: textGrey.withOpacity(0.5), size: 12),
          ],
        ),
      ),
    );
  }
}