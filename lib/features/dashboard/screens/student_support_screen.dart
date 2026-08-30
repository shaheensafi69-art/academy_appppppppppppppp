import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'student_support_chat_screen.dart';

final String telegramBotToken =
    dotenv.env['NEXT_PUBLIC_TELEGRAM_BOT_TOKEN2'] ??
    "8994358206:AAHUpoHpMpqdnTxA_J30-xMipDg4l0vhBV8";
final String telegramChatId =
    dotenv.env['NEXT_PUBLIC_TELEGRAM_CHAT_ID2'] ?? "5195615040";

class TicketItem {
  final String id;
  final String subject;
  final String status;
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
      subject: json['subject'] ?? 'Live Support',
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class StudentSupportScreen extends StatefulWidget {
  final String requesterRole; // 'student' | 'teacher'

  const StudentSupportScreen({super.key, this.requesterRole = 'student'});

  @override
  State<StudentSupportScreen> createState() => _StudentSupportScreenState();
}

class _StudentSupportScreenState extends State<StudentSupportScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  List<TicketItem> tickets = [];
  Map<String, String> userInfo = {
    'id': '',
    'firstName': '',
    'lastName': '',
    'email': '',
  };

  Map<String, int> stats = {'pending': 0, 'active': 0, 'closed': 0};

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);

  // رنگ‌بندی‌های اختصاصی وضعیت
  static const Color colorPending = Color(0xFFFFB300); // زرد/کهربایی
  static const Color colorActive = Color(0xFF43A047); // سبز
  static const Color colorClosed = Color(0xFFE53935); // سرخ

  void _showPremiumNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.redAccent.withOpacity(0.85)
                    : Colors.green.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isError ? Colors.red : Colors.green).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
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
        userInfo = {
          'id': userId,
          'firstName': fName,
          'lastName': lName,
          'email': userEmail,
        };
      });

      final ticketsData = await supabase
          .from("tickets")
          .select("*")
          .eq("student_id", userId)
          .order("created_at", ascending: false);

      final allTickets = (ticketsData as List)
          .map((t) => TicketItem.fromJson(t))
          .toList();

      int pendingCount = allTickets.where((t) => t.status == "open").length;
      int activeCount = allTickets
          .where((t) => t.status == "escalated" || t.status == "answered")
          .length;
      int closedCount = allTickets.where((t) => t.status == "closed").length;

      setState(() {
        tickets = allTickets;
        stats = {
          'pending': pendingCount,
          'active': activeCount,
          'closed': closedCount,
        };
      });
    } catch (e) {
      debugPrint("Error fetching support data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendLiveChatAlertToTelegram(String role) async {
    if (telegramBotToken.isEmpty || telegramChatId.isEmpty) return;

    final bool isTeacher = role == 'teacher';
    final String roleLabel = isTeacher ? 'استاد (Teacher)' : 'دانشجو (Student)';

    final telegramText =
        '''
🟢 <b>Live Support Chat Started</b>

👤 <b>Requester:</b> $roleLabel
👉 <b>Name:</b> ${userInfo['firstName']} ${userInfo['lastName']}
👉 <b>Email:</b> ${userInfo['email']}
👉 <b>User ID:</b> <code>${userInfo['id']}</code>

📌 <b>Subject:</b> General Live Support

<i>The AI assistant is now handling the chat. If the user requests a human, it will be escalated automatically.</i>
''';

    try {
      await http.post(
        Uri.parse("https://api.telegram.org/bot$telegramBotToken/sendMessage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": telegramChatId,
          "text": telegramText,
          "parse_mode": "HTML",
        }),
      );
    } catch (err) {
      debugPrint("Telegram live chat alert failed: $err");
    }
  }

  Future<void> _handleLiveChatClick() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // بررسی اینکه آیا چت لایو بازی وجود دارد یا خیر
      final existingTicket = await supabase
          .from("tickets")
          .select("*")
          .eq("student_id", userId)
          .eq("subject", "General Live Support")
          .neq("status", "closed")
          .order("created_at", ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingTicket != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentSupportChatScreen(
                ticketId: existingTicket['id'].toString(),
                ticketSubject: existingTicket['subject'].toString(),
                initialStatus: existingTicket['status'].toString(),
                requesterRole: widget.requesterRole,
              ),
            ),
          ).then((_) => _fetchInitialData());
        }
      } else {
        // ساخت چت لایو جدید
        final newTicket = await supabase
            .from("tickets")
            .insert({
              'student_id': userId,
              'subject': 'General Live Support',
              'department': 'Technical',
              'status': 'open',
            })
            .select()
            .single();

        // پیام پیش‌فرض خوشامدگویی از ربات
        await supabase.from("ticket_messages").insert({
          'ticket_id': newTicket['id'],
          'sender_id': null,
          'message_text':
              'سلام! خوش آمدید. من پشتیبان هوشمند سافی آکادمی هستم. چگونه می‌توانم به شما کمک کنم؟',
        });

        await _sendLiveChatAlertToTelegram(widget.requesterRole);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentSupportChatScreen(
                ticketId: newTicket['id'].toString(),
                ticketSubject: newTicket['subject'].toString(),
                initialStatus: newTicket['status'].toString(),
                requesterRole: widget.requesterRole,
              ),
            ),
          ).then((_) => _fetchInitialData());
        }
      }
    } catch (e) {
      debugPrint("Error opening Live Chat: $e");
      if (mounted) {
        _showPremiumNotification(
          "An error occurred opening Live Chat.",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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

  // توابع کمکی برای رنگ و لیبل بر اساس وضعیت
  Color _getStatusColor(String status) {
    if (status == 'closed') return colorClosed; // سرخ
    if (status == 'escalated' || status == 'answered')
      return colorActive; // سبز
    return colorPending; // زرد برای open/pending
  }

  String _getStatusLabel(String status) {
    if (status == 'closed') return 'Closed';
    if (status == 'escalated' || status == 'answered') return 'In Conversation';
    return 'Pending';
  }

  IconData _getStatusIcon(String status) {
    if (status == 'closed') return Icons.lock_rounded;
    if (status == 'escalated' || status == 'answered')
      return Icons.support_agent_rounded;
    return Icons.hourglass_empty_rounded;
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
              const CircularProgressIndicator(
                color: primaryPink,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 14),
              Text(
                "CONNECTING TO LIVE SUPPORT...",
                style: TextStyle(
                  color: textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightPinkBg.withOpacity(0.3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Support Center",
          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textGrey),
            onPressed: _fetchInitialData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= بنر اصلی چت لایو =================
            GestureDetector(
              onTap: _handleLiveChatClick,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), primaryPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPink.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.headset_mic_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Live Support Agent",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "AI & Human Agents are online",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "START CONVERSATION",
                            style: TextStyle(
                              color: Color(0xFFE91E63),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFE91E63),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ================= باکس‌های آمار (زرد - سبز - سرخ) =================
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "PENDING",
                    stats['pending'] ?? 0,
                    colorPending,
                    Icons.hourglass_top_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    "ACTIVE",
                    stats['active'] ?? 0,
                    colorActive,
                    Icons.forum_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    "CLOSED",
                    stats['closed'] ?? 0,
                    colorClosed,
                    Icons.check_circle_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // ================= لیست گفتگوهای قبلی =================
            const Text(
              "Recent Conversations",
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            tickets.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = tickets[index];
                      final statusColor = _getStatusColor(t.status);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentSupportChatScreen(
                                ticketId: t.id,
                                ticketSubject: t.subject,
                                initialStatus: t.status,
                                requesterRole: widget.requesterRole,
                              ),
                            ),
                          ).then((_) {
                            _fetchInitialData();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // نوار رنگی کناری نشان دهنده وضعیت
                              Container(
                                width: 5,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                _getStatusIcon(t.status),
                                                color: statusColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.subject,
                                                    style: const TextStyle(
                                                      color: textDark,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Started: ${_formatDate(t.createdAt)}",
                                                    style: const TextStyle(
                                                      color: textGrey,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusLabel(t.status),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: textGrey,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No Conversations Yet",
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Click the banner above to start a live chat.",
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
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

  // ویجت کمکی برای ساخت کارت‌های آمار
  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(
                "$count",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textGrey,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
