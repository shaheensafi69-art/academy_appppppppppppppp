import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

const String telegramBotToken = "8994358206:AAHUpoHpMpqdnTxA_J30-xMipDg4l0vhBV8";
const String telegramChatId = "5195615040";

class TicketItem {
  final String id;
  final String subject;
  final String status; // "open" | "answered" | "closed"
  final String createdAt;

  TicketItem({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
  });

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    return TicketItem(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class StudentSupportScreen extends StatefulWidget {
  const StudentSupportScreen({super.key});

  @override
  State<StudentSupportScreen> createState() => _StudentSupportScreenState();
}

class _StudentSupportScreenState extends State<StudentSupportScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;
  bool isModalOpen = false;

  List<TicketItem> tickets = [];
  Map<String, String> userInfo = {'id': '', 'firstName': '', 'lastName': '', 'email': ''};

  Map<String, int> stats = {'open': 0, 'answered': 0, 'total': 0};

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userId = user.id;
      final userEmail = user.email ?? '';

      final profile = await supabase
          .from("profiles")
          .select("first_name, last_name")
          .eq("id", userId)
          .maybeSingle();

      final fName = profile?['first_name'] ?? '';
      final lName = profile?['last_name'] ?? '';

      setState(() {
        userInfo = {'id': userId, 'firstName': fName, 'lastName': lName, 'email': userEmail};
        _firstNameController.text = fName;
        _lastNameController.text = lName;
        _emailController.text = userEmail;
      });

      final ticketsData = await supabase
          .from("tickets")
          .select("*")
          .eq("student_id", userId) 
          .order("created_at", ascending: false);

      final allTickets = (ticketsData as List).map((t) => TicketItem.fromJson(t)).toList();
      int openCount = allTickets.where((t) => t.status == "open").length;
      int answeredCount = allTickets.where((t) => t.status == "answered").length;

      setState(() {
        tickets = allTickets;
        stats = {'open': openCount, 'answered': answeredCount, 'total': allTickets.length};
      });
        } catch (e) {
      debugPrint("Error fetching support data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendTicketAlertToTelegram(String fName, String lName, String email, String userId, String subject, String message) async {
    if (telegramBotToken.isEmpty || telegramChatId.isEmpty) return;

    final telegramText = '''
🛑 *New Support Ticket*

👤 *User Information:*
👉 *First Name:* $fName
👉 *Last Name:* $lName
👉 *Account Email:* $email
👉 *Database ID:* `$userId`

📌 *Subject:* $subject

💬 *Message Details:*
$message
''';

    try {
      await http.post(
        Uri.parse("https://api.telegram.org/bot$telegramBotToken/sendMessage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": telegramChatId,
          "text": telegramText,
          "parse_mode": "Markdown",
        }),
      );
    } catch (err) {
      debugPrint("Telegram alert delivery failed: $err");
    }
  }

  Future<void> _handleCreateTicket() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) return;

    setState(() => isSubmitting = true);
    try {
      final userId = userInfo['id']!;

      final newTicket = await supabase
          .from("tickets")
          .insert({
            'student_id': userId,
            'subject': subject,
            'department': 'Technical',
            'status': 'open',
          })
          .select()
          .single();

      await supabase.from("ticket_messages").insert({
        'ticket_id': newTicket['id'],
        'sender_id': userId,
        'message_text': message,
      });

      await _sendTicketAlertToTelegram(
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _emailController.text.trim(),
        userId,
        subject,
        message,
      );

      setState(() {
        isModalOpen = false;
        _subjectController.clear();
        _messageController.clear();
        tickets.insert(0, TicketItem.fromJson(newTicket));
        stats['open'] = (stats['open'] ?? 0) + 1;
        stats['total'] = (stats['total'] ?? 0) + 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your support request has been logged and forwarded successfully."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error creating ticket: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred while creating the ticket."), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1]} ${dt.year}";
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
              Text("LOADING SUPPORT DESK...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
            // ================= هدر صفحه و دکمه ایجاد تیکت =================
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
                    child: const Icon(Icons.support_agent_rounded, color: primaryPink, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Support Desk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        const SizedBox(height: 3),
                        const Text("Submit queries to our elite assistance unit.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text("Ticket", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    onPressed: () => setState(() => isModalOpen = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= باکس‌های آمار ریسپانسیو =================
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.hourglass_top_rounded, color: primaryPink, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("OPEN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 2),
                              Text("${stats['open']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ANSWERED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 2),
                              Text("${stats['answered']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.list_alt_rounded, color: Colors.blue, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TOTAL", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                              const SizedBox(height: 2),
                              Text("${stats['total']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ================= لیست تیکت‌ها =================
            const Text("My Support Logs", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 12),

            tickets.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = tickets[index];
                      bool isOpen = t.status == 'open';

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
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.confirmation_number_rounded, color: primaryPink, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.subject, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text("Submitted: ${_formatDate(t.createdAt)}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOpen ? lightPinkBg : Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOpen ? 'Pending' : 'Answered',
                                style: TextStyle(color: isOpen ? primaryPink : Colors.green.shade700, fontSize: 9, fontWeight: FontWeight.w900),
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
                    child: Column(
                      children: [
                        const Icon(Icons.mark_email_unread_rounded, color: textGrey, size: 36),
                        const SizedBox(height: 10),
                        const Text("No Support Logs Active", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text("Need help with something? Click above to open a ticket.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
            const SizedBox(height: 30),

            // ================= مودال ایجاد تیکت =================
            if (isModalOpen)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Open Support Request", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                          onPressed: () => setState(() => isModalOpen = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInput("First Name *", _firstNameController),
                    const SizedBox(height: 12),
                    _buildInput("Last Name *", _lastNameController),
                    const SizedBox(height: 12),
                    _buildInput("Account Email *", _emailController),
                    const SizedBox(height: 12),
                    _buildInput("Subject *", _subjectController, hint: "e.g., Database Sync Error"),
                    const SizedBox(height: 12),
                    _buildInput("Message Details *", _messageController, hint: "Describe your difficulty...", maxLines: 4),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting ? null : _handleCreateTicket,
                        child: Text(isSubmitting ? "Dispatching..." : "Submit Ticket Terminal 🚀", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }
}