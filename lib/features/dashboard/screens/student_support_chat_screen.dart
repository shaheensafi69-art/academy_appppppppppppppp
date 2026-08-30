import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/services/gemini_ai_service.dart';
import 'package:file_picker/file_picker.dart' as fp;

class SupportMessage {
  final String id;
  final String? senderId;
  final String messageText;
  final String? attachmentUrl;
  final String createdAt;

  SupportMessage({
    required this.id,
    this.senderId,
    required this.messageText,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'].toString(),
      senderId: json['sender_id']?.toString(),
      messageText: json['message_text'] ?? '',
      attachmentUrl: json['attachment_url'],
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class StudentSupportChatScreen extends StatefulWidget {
  final String ticketId;
  final String ticketSubject;
  final String initialStatus;
  final String requesterRole;

  const StudentSupportChatScreen({
    super.key,
    required this.ticketId,
    required this.ticketSubject,
    required this.initialStatus,
    this.requesterRole = 'student',
  });

  @override
  State<StudentSupportChatScreen> createState() =>
      _StudentSupportChatScreenState();
}

class _StudentSupportChatScreenState extends State<StudentSupportChatScreen> {
  final supabase = Supabase.instance.client;
  final GeminiAiService _aiService = GeminiAiService();

  List<SupportMessage> messages = [];
  bool isLoading = true;
  bool isTyping = false;
  bool isUploading = false;
  String currentStatus = "open";
  Timer? _pollingTimer;
  String myUserId = "";

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String telegramBotToken =
      dotenv.env['NEXT_PUBLIC_TELEGRAM_BOT_TOKEN2'] ??
      "8994358206:AAHUpoHpMpqdnTxA_J30-xMipDg4l0vhBV8";
  final String telegramChatId =
      dotenv.env['NEXT_PUBLIC_TELEGRAM_CHAT_ID2'] ?? "5195615040";

  // پالت رنگی حرفه‌ای و کامل
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color deepPink = Color(0xFFD81B60);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB); // تعریف متغیر گمشده

  // استایل پیام کاربر
  static const Color userBubbleBorder = Color(0xFFFBCFE8);
  static const Color userBubbleBg = Colors.white;

  // استایل پیام هوش مصنوعی
  static const Color aiBubbleBg = Color(0xFFF3E5F5);
  static const Color aiBubbleBorder = Color(0xFFCE93D8);
  static const Color aiTextDark = Color(0xFF4A148C);

  // استایل پیام پشتیبان انسانی
  static const Color adminBubbleBg = Color(0xFFE0F2F1);
  static const Color adminBubbleBorder = Color(0xFF80CBC4);
  static const Color adminTextDark = Color(0xFF004D40);

  @override
  void initState() {
    super.initState();
    currentStatus = widget.initialStatus;
    myUserId = supabase.auth.currentUser?.id ?? '';
    _fetchMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages(isSilent: true);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchMessages({bool isSilent = false}) async {
    if (!isSilent) setState(() => isLoading = true);

    try {
      final messagesData = await supabase
          .from("ticket_messages")
          .select("*")
          .eq("ticket_id", widget.ticketId)
          .order("created_at", ascending: true);

      final List<SupportMessage> fetched = (messagesData as List)
          .map((m) => SupportMessage.fromJson(m))
          .toList();

      final ticketData = await supabase
          .from("tickets")
          .select("status")
          .eq("id", widget.ticketId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (messages.length != fetched.length && isSilent) {
            messages = fetched;
            Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
          } else if (!isSilent) {
            messages = fetched;
          }

          if (ticketData != null && ticketData['status'] != null) {
            if (currentStatus != 'escalated' ||
                ticketData['status'] == 'closed') {
              currentStatus = ticketData['status'];
            }
          }
          isLoading = false;
        });
        if (!isSilent) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleAttachFile() async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => isUploading = true);

      final fileBytes = result.files.first.bytes;
      final fileStr = result.files.first.path;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${result.files.first.name}';
      final filePath = 'tickets/${widget.ticketId}/$fileName';

      String? publicUrl;

      if (fileBytes != null) {
        await supabase.storage
            .from('support')
            .uploadBinary(filePath, fileBytes);
        publicUrl = supabase.storage.from('support').getPublicUrl(filePath);
      } else if (fileStr != null) {
        final file = File(fileStr);
        await supabase.storage.from('support').upload(filePath, file);
        publicUrl = supabase.storage.from('support').getPublicUrl(filePath);
      }

      if (publicUrl != null) {
        await supabase.from("ticket_messages").insert({
          'ticket_id': widget.ticketId,
          'sender_id': myUserId,
          'message_text': '📎 فایل ضمیمه شد',
          'attachment_url': publicUrl,
        });

        await _fetchMessages(isSilent: true);
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      _showPremiumNotification(
        'خطا در آپلود فایل. لطفاً دوباره تلاش کنید.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendEscalationAlertToTelegram(
    String userMsg,
    String aiResponse,
  ) async {
    final user = supabase.auth.currentUser;
    final userId = user?.id ?? 'Unknown';
    final userEmail = user?.email ?? 'Unknown';

    final bool isTeacher = widget.requesterRole == 'teacher';
    final String roleLabel = isTeacher ? 'Teacher (استاد)' : 'Student (دانشجو)';

    final telegramText =
        '''
⚠️ <b>RED SUPPORT ALERT: Human Handoff Requested</b>

👤 <b>User Info:</b>
👉 <b>Role:</b> $roleLabel
👉 <b>Email:</b> ${userEmail.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}
👉 <b>User ID:</b> <code>$userId</code>
📌 <b>Ticket Subject:</b> ${widget.ticketSubject.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}
🔗 <b>Ticket ID:</b> <code>${widget.ticketId}</code>

💬 <b>Last Query:</b>
"${userMsg.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}"

🤖 <b>System Message:</b>
"${aiResponse.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}"

<i>Please open the Admin Support Terminal to reply immediately.</i>
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
      debugPrint("Telegram Escalation alert delivery failed: $err");
    }
  }

  Future<void> _startNewRequest() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final newTicket = await supabase
          .from("tickets")
          .insert({
            'student_id': user.id,
            'subject': 'General Live Support',
            'department': 'Technical',
            'status': 'open',
          })
          .select()
          .single();

      await supabase.from("ticket_messages").insert({
        'ticket_id': newTicket['id'],
        'sender_id': null,
        'message_text':
            'سلام! خوش آمدید. من پشتیبان هوشمند سافی آکادمی هستم. چگونه می‌توانم به شما کمک کنم؟',
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentSupportChatScreen(
            ticketId: newTicket['id'].toString(),
            ticketSubject: newTicket['subject'].toString(),
            initialStatus: 'open',
            requesterRole: widget.requesterRole,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error starting new request: $e");
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || isTyping || isUploading) return;

    _messageController.clear();

    final tempMsgId = "temp-${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      messages.add(
        SupportMessage(
          id: tempMsgId,
          senderId: myUserId,
          messageText: text,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      isTyping = true;
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    try {
      await supabase.from("ticket_messages").insert({
        'ticket_id': widget.ticketId,
        'sender_id': myUserId,
        'message_text': text,
      });

      await _fetchMessages(isSilent: true);

      if (currentStatus == "open") {
        final lowerText = text.toLowerCase();
        final bool isEscalationRequested =
            lowerText.contains("refund") ||
            lowerText.contains("money") ||
            lowerText.contains("payment") ||
            lowerText.contains("stripe") ||
            lowerText.contains("پشتیبان") ||
            lowerText.contains("پول") ||
            lowerText.contains("پرداخت") ||
            lowerText.contains("انسان") ||
            lowerText.contains("اپراتور") ||
            lowerText.contains("مشاور") ||
            lowerText.contains("ادمین") ||
            lowerText.contains("مدیر") ||
            lowerText.contains("رئیس") ||
            lowerText.contains("advisor") ||
            lowerText.contains("admin") ||
            lowerText.contains("human") ||
            lowerText.contains("وصل کو") ||
            lowerText.contains("وصل کن");

        if (isEscalationRequested) {
          setState(() {
            currentStatus = 'escalated';
          });
          await supabase
              .from("tickets")
              .update({'status': 'escalated'})
              .eq("id", widget.ticketId);
          await _sendEscalationAlertToTelegram(
            text,
            "⚠️ درخواست به پشتیبان انسانی ارجاع شد.",
          );
          return;
        }

        final List<Map<String, String>> history = messages
            .map(
              (m) => {
                "role": m.senderId == myUserId ? "user" : "model",
                "content": m.messageText,
              },
            )
            .toList();

        final String supportSystemPrompt = """
You are the Official AI Support Assistant for Safi Academy. Be polite, friendly, and brief.
Answer in the exact language the user prompts. Strictly answer queries related to Safi Academy support.
""";

        final contextData = await _aiService.fetchStudentContext(myUserId);
        final finalPrompt =
            "$supportSystemPrompt\n\nStudent Name: ${contextData.studentName}\nEnrolled Courses: ${contextData.enrolledCourses.join(", ")}\n\nQuery: $text";

        String aiResponse = await _aiService.generateResponse(
          studentId: myUserId,
          userPrompt: finalPrompt,
          conversationHistory: history,
        );

        final lowerAi = aiResponse.toLowerCase();
        if (lowerAi.contains("human support") ||
            lowerAi.contains("representative") ||
            lowerAi.contains("advisors") ||
            lowerAi.contains("پشتیبان انسانی") ||
            lowerAi.contains("مشاوران") ||
            lowerAi.contains("ادمین") ||
            lowerAi.contains("اپراتور")) {
          setState(() {
            currentStatus = 'escalated';
          });
          await supabase
              .from("tickets")
              .update({'status': 'escalated'})
              .eq("id", widget.ticketId);
          await _sendEscalationAlertToTelegram(text, aiResponse);
          return;
        }

        await supabase.from("ticket_messages").insert({
          'ticket_id': widget.ticketId,
          'sender_id': null,
          'message_text': aiResponse,
        });

        await _fetchMessages(isSilent: true);
      }
    } catch (e) {
      debugPrint("Error sending support message: $e");
      if (mounted)
        _showPremiumNotification(
          "Connection issue. Unable to send message.",
          isError: true,
        );
    } finally {
      if (mounted) {
        setState(() {
          messages.removeWhere((m) => m.id == tempMsgId);
          isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

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

  Widget _buildAttachmentPreview(String url, bool isMe) {
    final lowerUrl = url.toLowerCase();
    final isImage =
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp');

    if (isImage) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? userBubbleBorder : aiBubbleBorder,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.cover),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.pink.shade50.withOpacity(0.3)
              : Colors.purple.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? userBubbleBorder : aiBubbleBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: isMe ? primaryPink : aiTextDark,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Document Attached",
                style: TextStyle(
                  color: isMe ? textDark : aiTextDark,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: textGrey.withOpacity(0.6),
              size: 18,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: backgroundLight),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ================= Header (Glassmorphism) =================
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceWhite.withOpacity(0.85),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textDark,
                            size: 18,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ticketSubject,
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: currentStatus == 'escalated'
                                          ? Colors.orange
                                          : currentStatus == 'closed'
                                          ? Colors.red
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentStatus == 'escalated'
                                        ? "Waiting for Admin"
                                        : currentStatus == 'closed'
                                        ? "Ticket Closed"
                                        : "AI Support Active",
                                    style: TextStyle(
                                      color: currentStatus == 'escalated'
                                          ? Colors.orange.shade700
                                          : currentStatus == 'closed'
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // ================= New Chat Button =================
                        GestureDetector(
                          onTap: _startNewRequest,
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryPink, deepPink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: deepPink.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.flash_on_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "NEW CHAT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ================= Chat Body =================
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: primaryPink,
                          strokeWidth: 2.5,
                        ),
                      )
                    : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: primaryPink.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.forum_rounded,
                                color: primaryPink,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Live Support Initiated",
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Feel free to ask about \"${widget.ticketSubject}\"",
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 40,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];

                          final bool isMe = msg.senderId == myUserId;
                          final bool isAi =
                              msg.senderId == null ||
                              msg.senderId!.isEmpty ||
                              msg.senderId == 'ai';
                          final bool isHumanAdmin = !isMe && !isAi;

                          Color bubbleBgColor;
                          Color bubbleBorderColor;
                          Color textColor;
                          Widget? senderHeader;

                          if (isMe) {
                            bubbleBgColor = userBubbleBg;
                            bubbleBorderColor = userBubbleBorder;
                            textColor = textDark;
                            senderHeader = Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 14,
                                    color: textGrey.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.requesterRole == 'teacher'
                                        ? "You (Teacher)"
                                        : "You",
                                    style: TextStyle(
                                      color: textGrey.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (isAi) {
                            bubbleBgColor = aiBubbleBg;
                            bubbleBorderColor = aiBubbleBorder;
                            textColor = aiTextDark;
                            senderHeader = Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.smart_toy_rounded,
                                    size: 14,
                                    color: aiTextDark,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Safi AI 🤖",
                                    style: TextStyle(
                                      color: aiTextDark,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            bubbleBgColor = adminBubbleBg;
                            bubbleBorderColor = adminBubbleBorder;
                            textColor = adminTextDark;
                            senderHeader = Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.support_agent_rounded,
                                    size: 14,
                                    color: adminTextDark,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Support Agent 🧑‍💻",
                                    style: TextStyle(
                                      color: adminTextDark,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8,
                              ),
                              decoration: BoxDecoration(
                                color: bubbleBgColor,
                                borderRadius: BorderRadius.circular(20)
                                    .copyWith(
                                      bottomRight: isMe
                                          ? const Radius.circular(4)
                                          : const Radius.circular(20),
                                      bottomLeft: !isMe
                                          ? const Radius.circular(4)
                                          : const Radius.circular(20),
                                    ),
                                border: Border.all(
                                  color: bubbleBorderColor,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (senderHeader != null) senderHeader,
                                  Text(
                                    msg.messageText,
                                    textDirection:
                                        msg.messageText.contains(
                                          RegExp(r'[\u0600-\u06FF]'),
                                        )
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (msg.attachmentUrl != null &&
                                      msg.attachmentUrl!.isNotEmpty)
                                    _buildAttachmentPreview(
                                      msg.attachmentUrl!,
                                      isMe,
                                    ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      _formatTime(msg.createdAt),
                                      style: TextStyle(
                                        color: isMe
                                            ? textGrey
                                            : (isAi
                                                  ? aiTextDark.withOpacity(0.6)
                                                  : adminTextDark.withOpacity(
                                                      0.6,
                                                    )),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ================= Typing Indicator =================
              if (isTyping || isUploading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: primaryPink,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isUploading
                                ? "Uploading..."
                                : currentStatus == 'escalated'
                                ? "Waiting for admin..."
                                : "Safi AI is typing...",
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ================= Floating Input Capsule =================
              // ================= Floating Input Capsule =================
              if (currentStatus != 'closed')
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      top: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.attach_file_rounded,
                              color: textGrey,
                              size: 18,
                            ),
                          ),
                          onPressed: isUploading ? null : _handleAttachFile,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: currentStatus == 'escalated'
                                  ? "Message Admin..."
                                  : "Ask Safi AI...",
                              hintStyle: const TextStyle(
                                color: Colors.black38,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => _handleSendMessage(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _handleSendMessage,
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryPink, deepPink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ], // Column children
          ),
        ),
      ), // Container
    ); // Scaffold
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}
