import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final supabase = Supabase.instance.client;
  bool isSubmitting = false;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedDepartment = 'General Support';

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in both subject and message fields."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // ایجاد تیکت در دیتابیس
      final ticketRes = await supabase.from('tickets').insert({
        'student_id': user.id,
        'subject': subject,
        'department': _selectedDepartment,
        'status': 'open',
      }).select('id').single();

      final ticketId = ticketRes['id'];

      // ثبت اولین پیام تیکت
      await supabase.from('ticket_messages').insert({
        'ticket_id': ticketId,
        'sender_id': user.id,
        'message_text': message,
      });

      _subjectController.clear();
      _messageController.clear();
      FocusScope.of(context).unfocus(); // بستن کیبورد

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Support ticket submitted successfully! We will get back to you soon. 🎫"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error submitting ticket: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit ticket: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AcademyLoadingOverlay(
      isLoading: isSubmitting,
      message: "SUBMITTING TICKET...",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          iconTheme: const IconThemeData(color: textDark),
          title: const Text("Help & Support", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5).withOpacity(0.5), surfaceWhite],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
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
                                BoxShadow(color: primaryPink.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
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
                                  child: const Icon(Icons.support_agent_rounded, color: primaryPink, size: 28),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("How can we help?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                                      SizedBox(height: 4),
                                      Text("Submit a ticket, explore FAQs, or reach out to us directly.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ================= بخش ارسال تیکت جدید =================
                          const Text("Submit a Support Ticket", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Department", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: lightPinkBg.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: primaryPink.withOpacity(0.2)),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _selectedDepartment,
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink, size: 18),
                                        dropdownColor: surfaceWhite,
                                        borderRadius: BorderRadius.circular(16),
                                        items: ['General Support', 'Technical Issue', 'Billing & Payments', 'Course Content'].map((dept) {
                                          return DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark)));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedDepartment = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24, color: cardBorder, thickness: 1.5),
                                TextField(
                                  controller: _subjectController,
                                  style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900), // رنگ تیره برای لایت مود
                                  decoration: InputDecoration(
                                    hintText: "Subject / Issue summary...",
                                    hintStyle: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w600),
                                    filled: true,
                                    fillColor: cardBorder.withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _messageController,
                                  maxLines: 4,
                                  style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5), // رنگ تیره
                                  decoration: InputDecoration(
                                    hintText: "Describe your problem or request in detail...",
                                    hintStyle: const TextStyle(color: textGrey, fontSize: 13),
                                    filled: true,
                                    fillColor: cardBorder.withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryPink,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: isSubmitting ? null : _submitTicket,
                                    child: const Text("SUBMIT TICKET 🎫", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // ================= راه‌های ارتباطی مستقیم =================
                          const Text("Direct Communications", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
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
                                      title: "Official Email",
                                      subtitle: "info@safiacademy.org",
                                      onTap: () => _launchURL("mailto:info@safiacademy.org"),
                                    ),
                                  ),
                                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                                  Expanded(
                                    flex: isWide ? 1 : 0,
                                    child: _buildContactCard(
                                      icon: Icons.phone_rounded,
                                      title: "Academy Hotline",
                                      subtitle: "+447476620282",
                                      onTap: () => _launchURL("tel:+447476620282"),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 30),

                          // ================= شبکه‌های اجتماعی =================
                          const Text("Official Channels & Socials", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          
                          // کانال واتساپ
                          _buildFeaturedWhatsAppCard(
                            onTap: () => _launchURL("https://whatsapp.com/channel/0029Vb8WCN9FXUucJwrltI32"),
                          ),
                          const SizedBox(height: 12),

                          // شبکه‌های اجتماعی (ایکس، فیسبوک، اینستاگرام، لینکدین)
                          LayoutBuilder(
                            builder: (context, gridConstraints) {
                              bool isWideGrid = gridConstraints.maxWidth > 500;
                              return Column(
                                children: [
                                  Row(
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
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
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
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 30),

                          // ================= سوالات متداول =================
                          const Text("Frequently Asked Questions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          _buildFaqItem("How do I join live classes?", "You can join live sessions directly from the 'Live Campus' section using the meeting room link provided for your batch. Ensure you have Zoom/Meet installed."),
                          const SizedBox(height: 10),
                          _buildFaqItem("How are certificates issued?", "Once you successfully pass your final exams and complete the course requirements, your official verified certificate will automatically appear in the 'Certificates' section as a downloadable PDF."),
                          const SizedBox(height: 10),
                          _buildFaqItem("Can I apply for international scholarships?", "Absolutely! Explore our 'Scholarships' portal to discover fully funded global grants, eligibility criteria, and direct application links curated by Safi Academy."),
                          const SizedBox(height: 80), // فاصله برای Bottom Nav
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: primaryPink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Image.asset('assets/whatsapp.com-logo.webp', width: 24, height: 24, fit: BoxFit.contain),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("WhatsApp Community Channel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  SizedBox(height: 2),
                  Text("Join our official broadcast channel for instant updates", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12)),
              child: Image.asset(assetPath, width: 22, height: 22, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: textGrey.withOpacity(0.4), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
        iconColor: primaryPink,
        collapsedIconColor: textGrey,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: textGrey, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500)),
          ),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFC2185B), strokeWidth: 3),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}