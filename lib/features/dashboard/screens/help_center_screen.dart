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

      _subjectController.clear();
      _messageController.clear();

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
                              child: const Icon(Icons.help_outline_rounded, color: primaryPink, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Help Center & Support", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                                  SizedBox(height: 3),
                                  Text("Get elite assistance, explore FAQs, or connect with our global faculty.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= بخش معرفی آکادمی و تیم متخصص =================
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.auto_awesome_rounded, color: primaryPink, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Text("About Safi Academy & Our Team", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Welcome to Safi Academy, where global academic excellence meets professional trading mastery. "
                              "Our mission is to empower ambitious minds across continents with world-class education, advanced financial insights, "
                              "and life-changing international opportunities.\n\n"
                              "Behind your success stands a passionate team of elite educators, certified financial analysts, and dedicated mentors. "
                              "We are committed to guiding you step-by-step through your academic journey, ensuring you unlock your ultimate potential and shape a brilliant future.",
                              style: TextStyle(color: textGrey, fontSize: 11, height: 1.6, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= راه‌های ارتباطی مستقیم (ریسپانسیو با Wrap) =================
                      const Text("Direct Academy Contacts", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
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
                                  title: "Email Support",
                                  subtitle: "info@safiacademy.org",
                                  onTap: () => _launchURL("mailto:info@safiacademy.org"),
                                ),
                              ),
                              SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: _buildContactCard(
                                  icon: Icons.phone_rounded,
                                  title: "Direct Line",
                                  subtitle: "+447476620282",
                                  onTap: () => _launchURL("tel:+447476620282"),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ================= بخش ارسال تیکت جدید به پشتیبانی =================
                      const Text("Create Support Ticket", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Department", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                DropdownButton<String>(
                                  value: _selectedDepartment,
                                  underline: const SizedBox(),
                                  items: ['General Support', 'Technical Issue', 'Billing & Payments', 'Course Content'].map((dept) {
                                    return DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedDepartment = val);
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: cardBorder),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _subjectController,
                              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: "Subject / Issue summary...",
                                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                                filled: true,
                                fillColor: cardBorder.withOpacity(0.5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _messageController,
                              maxLines: 3,
                              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: "Describe your problem or request in detail...",
                                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                                filled: true,
                                fillColor: cardBorder.withOpacity(0.5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: isSubmitting ? null : _submitTicket,
                                child: isSubmitting
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("SUBMIT TICKET 🎫", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= بخش سوالات متداول (FAQ) =================
                      const Text("Frequently Asked Questions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 12),
                      _buildFaqItem("How do I join live classes?", "You can join live sessions directly from the 'Live Campus' section using the meeting room link provided for your batch."),
                      const SizedBox(height: 10),
                      _buildFaqItem("How are certificates issued?", "Once you successfully pass your final exams and complete course requirements, your verified certificate will appear in the 'Certificates' section."),
                      const SizedBox(height: 10),
                      _buildFaqItem("Can I apply for international scholarships?", "Yes! Explore our 'Scholarships' portal to discover fully funded global grants, eligibility criteria, and direct application links."),
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

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
        iconColor: primaryPink,
        collapsedIconColor: textGrey,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}