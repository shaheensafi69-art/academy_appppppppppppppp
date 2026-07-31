import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http; // برای ارسال پیام به تلگرام

// ========================================================
// ⚠️ Your Telegram Keys (Token 2 & Chat ID 2)
// ========================================================
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

  // فرم تیکت
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  get ascending => null;

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

      if (ticketsData != null) {
        final allTickets = (ticketsData as List).map((t) => TicketItem.fromJson(t)).toList();
        int openCount = allTickets.where((t) => t.status == "open").length;
        int answeredCount = allTickets.where((t) => t.status == "answered").length;

        setState(() {
          tickets = allTickets;
          stats = {'open': openCount, 'answered': answeredCount, 'total': allTickets.length};
        });
      }
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

      // ۱. درج تیکت در جدول tickets
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

      // ۲. درج متن پیام در جدول ticket_messages
      await supabase.from("ticket_messages").insert({
        'ticket_id': newTicket['id'],
        'sender_id': userId,
        'message_text': message,
      });

      // ۳. ارسال هشدار به تلگرام
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه و دکمه ایجاد تیکت =================
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text("🎧", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Support Desk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text("Submit your queries directly to our elite assistance unit.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Create Ticket", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  onPressed: () => setState(() => isModalOpen = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= باکس‌های آمار =================
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text("⏳", style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("OPEN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                          Text("${stats['open']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text("✅", style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("ANSWERED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                          Text("${stats['answered']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text("📋", style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TOTAL", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                          Text("${stats['total']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ================= لیست تیکت‌ها =================
          const Text("My Support Logs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : tickets.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final t = tickets[index];
                        bool isOpen = t.status == 'open';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                                    child: const Text("🎫", style: TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text("Submitted: ${_formatDate(t.createdAt)}", style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen ? Colors.amber.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOpen ? 'Pending Review' : 'Answered',
                                  style: TextStyle(color: isOpen ? Colors.amberAccent : Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
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
                      child: Column(
                        children: [
                          const Text("📩", style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 10),
                          const Text("No Support Logs Active", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text("Need help with something? Click below to forward an alert.", style: TextStyle(color: Colors.grey.shade500, fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
          const SizedBox(height: 30),

          // ================= مودال ایجاد تیکت (Bottom Sheet / Dialog) =================
          if (isModalOpen)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0d0d14),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Open Support Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: () => setState(() => isModalOpen = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInput("First Name *", _firstNameController),
                  const SizedBox(height: 8),
                  _buildInput("Last Name *", _lastNameController),
                  const SizedBox(height: 8),
                  _buildInput("Account Email *", _emailController),
                  const SizedBox(height: 8),
                  _buildInput("Subject *", _subjectController, hint: "e.g., Database Sync Error"),
                  const SizedBox(height: 8),
                  _buildInput("Message Details *", _messageController, hint: "Describe your difficulty...", maxLines: 4),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting ? null : _handleCreateTicket,
                      child: Text(isSubmitting ? "Dispatching..." : "Submit Ticket Terminal 🚀", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 10),
            filled: true,
            fillColor: Colors.black.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
        ),
      ],
    );
  }
}