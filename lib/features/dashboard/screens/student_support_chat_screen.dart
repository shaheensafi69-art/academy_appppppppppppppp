import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/services/gemini_ai_service.dart';

class SupportMessage {
  final String id;
  final String senderId;
  final String messageText;
  final String createdAt;

  SupportMessage({
    required this.id,
    required this.senderId,
    required this.messageText,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'].toString(),
      senderId: json['sender_id']?.toString() ?? '',
      messageText: json['message_text'] ?? '',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class StudentSupportChatScreen extends StatefulWidget {
  final String ticketId;
  final String ticketSubject;
  final String initialStatus;

  const StudentSupportChatScreen({
    super.key,
    required this.ticketId,
    required this.ticketSubject,
    required this.initialStatus,
  });

  @override
  State<StudentSupportChatScreen> createState() =>
      _StudentSupportChatScreenState();
}

class _StudentSupportChatScreenState extends State<StudentSupportChatScreen> {
  final supabase = Supabase.instance.client;
  final GeminiAiService _aiService = GeminiAiService();
  final FlutterTts _flutterTts = FlutterTts();

  List<SupportMessage> messages = [];
  bool isLoading = true;
  bool isTyping = false;
  String currentStatus = "open";
  Timer? _pollingTimer;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String telegramBotToken =
      dotenv.env['NEXT_PUBLIC_TELEGRAM_BOT_TOKEN2'] ??
      "8994358206:AAHUpoHpMpqdnTxA_J30-xMipDg4l0vhBV8";
  final String telegramChatId =
      dotenv.env['NEXT_PUBLIC_TELEGRAM_CHAT_ID2'] ?? "5195615040";

  // Bubblegum Theme Colors
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF1E3E7);

  @override
  void initState() {
    super.initState();
    currentStatus = widget.initialStatus;
    _fetchMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
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
    if (!isSilent) {
      setState(() => isLoading = true);
    }
    try {
      // 1. Fetch messages
      final messagesData = await supabase
          .from("ticket_messages")
          .select("*")
          .eq("ticket_id", widget.ticketId)
          .order("created_at", ascending: true);

      final List<SupportMessage> fetched = (messagesData as List)
          .map((m) => SupportMessage.fromJson(m))
          .toList();

      // 2. Fetch latest ticket status
      final ticketData = await supabase
          .from("tickets")
          .select("status")
          .eq("id", widget.ticketId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          messages = fetched;
          if (ticketData != null && ticketData['status'] != null) {
            currentStatus = ticketData['status'];
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

  Future<void> _speakText(String text) async {
    try {
      await _flutterTts.stop();

      String langCode = "fa-IR"; // Default to Persian
      if (text.contains(RegExp(r'[a-zA-Z]')) &&
          !text.contains(RegExp(r'[\u0600-\u06FF]'))) {
        langCode = "en-US";
      }

      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Support Error: $e");
    }
  }

  Future<void> _sendEscalationAlertToTelegram(
    String userMsg,
    String aiResponse,
  ) async {
    final user = supabase.auth.currentUser;
    final userId = user?.id ?? 'Unknown';
    final userEmail = user?.email ?? 'Unknown';

    final telegramText =
        '''
⚠️ *RED SUPPORT ALERT: Human Handoff Requested*

👤 *User Info:*
👉 *Email:* $userEmail
👉 *User ID:* `$userId`
📌 *Ticket Subject:* ${widget.ticketSubject}
🔗 *Ticket ID:* `${widget.ticketId}`

💬 *Last Student Query:*
"$userMsg"

🤖 *AI Support Decision:*
"$aiResponse"

_Please open the Admin Support Terminal to reply to this student immediately._
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
      debugPrint("Telegram Escalation alert delivery failed: $err");
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || isTyping) return;

    _messageController.clear();
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final studentId = user.id;

    final tempMsgId = "temp-${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      messages.add(
        SupportMessage(
          id: tempMsgId,
          senderId: studentId,
          messageText: text,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      isTyping = true;
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    try {
      // 1. Insert user message into Supabase
      await supabase.from("ticket_messages").insert({
        'ticket_id': widget.ticketId,
        'sender_id': studentId,
        'message_text': text,
      });

      // Remove temp message and fetch actual messages
      await _fetchMessages(isSilent: true);

      // 2. Call Gemini AI support logic if the ticket status is not closed/escalated
      if (currentStatus == "open" || currentStatus == "ai_handling") {
        // Compile conversation history for prompt context
        final List<Map<String, String>> history = messages
            .map(
              (m) => {
                "role": m.senderId == studentId ? "user" : "model",
                "content": m.messageText,
              },
            )
            .toList();

        // Check for immediate escalation triggers
        final lowerText = text.toLowerCase();
        final bool isEscalationRequested =
            lowerText.contains("refund") ||
            lowerText.contains("money") ||
            lowerText.contains("payment") ||
            lowerText.contains("stripe") ||
            lowerText.contains("charge") ||
            lowerText.contains("پشتیبان") ||
            lowerText.contains("پول") ||
            lowerText.contains("پرداخت") ||
            lowerText.contains("انسان") ||
            lowerText.contains("ربات") ||
            lowerText.contains("اپراتور");

        String aiResponse = "";
        if (isEscalationRequested) {
          aiResponse =
              "⚠️ I have notified our human support administrators regarding your request. A support representative will join this live chat shortly to assist you. Please feel free to add any details here in the meantime.";

          // Update ticket status to escalated
          await supabase
              .from("tickets")
              .update({'status': 'escalated'})
              .eq("id", widget.ticketId);

          await _sendEscalationAlertToTelegram(text, aiResponse);
        } else {
          // Dedicated Support Agent Prompt
          final String supportSystemPrompt = """
You are the Official AI Support Assistant for Safi Academy (سافی آکادمی).
Your job is to assist the student with technical support queries, course navigation, and general assistance.
RULES:
1. Be polite, friendly, and brief.
2. If the user asks about financial issues, refunds, manual payment confirmation, or requests a human agent, immediately say that you are forwarding them to a human agent.
3. Answer in the exact language the user prompts (Persian/Dari or English).
4. Strictly answer queries related to Safi Academy support (course locking, platform usage, schedule, assignments). Reject unrelated topics.
""";

          final context = await _aiService.fetchStudentContext(studentId);
          final finalPrompt =
              "$supportSystemPrompt\n\nStudent Name: ${context.studentName}\nEnrolled Courses: ${context.enrolledCourses.join(", ")}\n\nQuery: $text";

          aiResponse = await _aiService.generateResponse(
            studentId: studentId,
            userPrompt: finalPrompt,
            conversationHistory: history,
          );
        }

        // Insert AI response into Supabase
        await supabase.from("ticket_messages").insert({
          'ticket_id': widget.ticketId,
          'sender_id': 'ai',
          'message_text': aiResponse,
        });

        // Fetch actual messages to display the AI response
        await _fetchMessages(isSilent: true);

        // Speak the response if in Farsi/English
        _speakText(aiResponse);
      }
    } catch (e) {
      debugPrint("Error sending support message: $e");
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

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final studentId = user?.id ?? '';

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textDark,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ticketSubject,
              style: const TextStyle(
                color: textDark,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: currentStatus == 'escalated'
                        ? Colors.orange
                        : currentStatus == 'closed'
                        ? Colors.red
                        : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  currentStatus == 'escalated'
                      ? "Escalated to Admins"
                      : currentStatus == 'closed'
                      ? "Ticket Closed"
                      : "AI Support Active",
                  style: TextStyle(
                    color: currentStatus == 'escalated'
                        ? Colors.orange
                        : currentStatus == 'closed'
                        ? Colors.red
                        : Colors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat messages body
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
                        const Icon(
                          Icons.forum_rounded,
                          color: textGrey,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Live Support Activated",
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Tell us how we can help you with \"${widget.ticketSubject}\"",
                          style: const TextStyle(
                            color: textGrey,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      bool isMe = msg.senderId == studentId;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? lightPinkBg : surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMe
                                  ? primaryPink.withOpacity(0.2)
                                  : cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      msg.messageText,
                                      textDirection:
                                          msg.messageText.contains(
                                            RegExp(r'[\u0600-\u06FF]'),
                                          )
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                      style: const TextStyle(
                                        color: textDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (!isMe) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _speakText(msg.messageText),
                                      child: const Icon(
                                        Icons.volume_up_rounded,
                                        color: primaryPink,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  _formatTime(msg.createdAt),
                                  style: const TextStyle(
                                    color: textGrey,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
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

          // Thinking / loading indicator
          if (isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: primaryPink,
                          strokeWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentStatus == 'escalated'
                            ? "Connecting to admin agent..."
                            : "Support AI is typing...",
                        style: const TextStyle(
                          color: textGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Message input bar
          if (currentStatus != 'closed')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: surfaceWhite,
                border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: currentStatus == 'escalated'
                            ? "Type details for the admin agent..."
                            : "Describe your support issue...",
                        hintStyle: const TextStyle(
                          color: textGrey,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: lightPinkBg.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleSendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: primaryPink,
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
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}
