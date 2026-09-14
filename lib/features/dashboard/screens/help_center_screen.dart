import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/language_service.dart';

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

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
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
        SnackBar(content: Text(context.l10n.fillSubjectAndMessage), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final ticketRes = await supabase.from('tickets').insert({
        'student_id': user.id,
        'subject': subject,
        'department': _selectedDepartment,
        'status': 'open',
      }).select('id').single();

      final ticketId = ticketRes['id'];

      await supabase.from('ticket_messages').insert({
        'ticket_id': ticketId,
        'sender_id': user.id,
        'message_text': message,
      });

      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ticketSuccess), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Error submitting ticket: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit ticket: $e"), backgroundColor: Colors.redAccent),
      );
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
      message: context.l10n.submittingTicket.toUpperCase(),
      child: Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          iconTheme: const IconThemeData(color: textDark),
          title: Text(context.l10n.helpCenterTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5).withValues(alpha: 0.5), surfaceWhite],
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
                                colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: primaryPink.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: lightPinkBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                                  ),
                                  child: const Icon(Icons.support_agent_rounded, color: primaryPink, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.howCanWeHelp,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.l10n.howCanWeHelpDesc,
                                        style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ================= بخش ارسال تیکت جدید =================
                          Text(context.l10n.submitSupportTicket, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(context.l10n.ticketDepartment, style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: lightPinkBg.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: primaryPink.withValues(alpha: 0.2)),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _selectedDepartment,
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink, size: 18),
                                        dropdownColor: surfaceWhite,
                                        borderRadius: BorderRadius.circular(16),
                                        items: [
                                          DropdownMenuItem(value: 'General Support', child: Text(context.l10n.generalSupport, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark))),
                                          DropdownMenuItem(value: 'Technical Issue', child: Text(context.l10n.technicalIssue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark))),
                                          DropdownMenuItem(value: 'Billing & Payments', child: Text(context.l10n.billingAndPayments, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark))),
                                          DropdownMenuItem(value: 'Course Content', child: Text(context.l10n.courseContent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark))),
                                        ],
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
                                  cursorColor: primaryPink,
                                  style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.subjectHint,
                                    hintStyle: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w600),
                                    filled: true,
                                    fillColor: cardBorder.withValues(alpha: 0.5),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _messageController,
                                  cursorColor: primaryPink,
                                  maxLines: 4,
                                  style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.messageHint,
                                    hintStyle: const TextStyle(color: textGrey, fontSize: 13),
                                    filled: true,
                                    fillColor: cardBorder.withValues(alpha: 0.5),
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
                                    child: Text("${context.l10n.submitTicket.toUpperCase()} 🎫", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // ================= راه‌های ارتباطی مستقیم =================
                          Text(context.l10n.directCommunications, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
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
                                      title: context.l10n.officialEmail,
                                      subtitle: "info@safiacademy.org",
                                      onTap: () => _launchURL("mailto:info@safiacademy.org"),
                                    ),
                                  ),
                                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                                  Expanded(
                                    flex: isWide ? 1 : 0,
                                    child: _buildContactCard(
                                      icon: Icons.phone_rounded,
                                      title: context.l10n.academyHotline,
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
                          Text(context.l10n.officialChannelsAndSocials, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          
                          _buildFeaturedWhatsAppCard(
                            onTap: () => _launchURL("https://whatsapp.com/channel/0029Vb8WCN9FXUucJwrltI32"),
                          ),
                          const SizedBox(height: 12),

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
                          const SizedBox(height: 30),

                          // ================= سوالات متداول =================
                          Text(context.l10n.faqTitle, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          _buildFaqItem(context.l10n.faq1Q, context.l10n.faq1A),
                          const SizedBox(height: 10),
                          _buildFaqItem(context.l10n.faq2Q, context.l10n.faq2A),
                          const SizedBox(height: 10),
                          _buildFaqItem(context.l10n.faq3Q, context.l10n.faq3A),
                          const SizedBox(height: 80),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
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
          boxShadow: [BoxShadow(color: const Color(0xFF25D366).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Image.asset('assets/whatsapp.com-logo.webp', width: 24, height: 24, fit: BoxFit.contain),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.whatsappCommunity, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(context.l10n.whatsappCommunityDesc, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
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
            Icon(Icons.open_in_new_rounded, color: textGrey.withValues(alpha: 0.4), size: 14),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
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
            color: Colors.white.withValues(alpha: 0.95),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFF494AC), strokeWidth: 3),
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