import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;

class AdminMessage {
  final String id;
  final String? senderId;
  final String text;
  final String createdAt;
  final String? attachmentUrl;

  AdminMessage({
    required this.id,
    this.senderId,
    required this.text,
    required this.createdAt,
    this.attachmentUrl,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString(),
      text: json['message_text'] ?? '',
      createdAt: json['created_at'] ?? '',
      attachmentUrl: json['attachment_url'],
    );
  }
}

class AdminSupportChatScreen extends StatefulWidget {
  final String ticketId;
  final String requesterName;
  final bool isTeacher;
  final String initialStatus;

  const AdminSupportChatScreen({
    super.key,
    required this.ticketId,
    this.requesterName = "",
    this.isTeacher = false,
    this.initialStatus = "open",
  });

  @override
  State<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  bool isSending = false;
  List<AdminMessage> messages = [];

  String ticketStatus = "open";
  String requesterName = "";
  String requesterId = "";
  String myAdminId = "";
  bool isTeacher = false;

  // Premium Colors
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color deepPink = Color(0xFFD81B60);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color aiColor = Color(0xFF9C27B0);
  static const Color otherAdminColor = Color(0xFF1E88E5);
  static const Color cardBorder = Color(0xFFE5E7EB);

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    requesterName = widget.requesterName;
    isTeacher = widget.isTeacher;
    ticketStatus = widget.initialStatus;
    myAdminId = supabase.auth.currentUser?.id ?? '';

    _fetchData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    await _fetchTicket();
    await _fetchMessages();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchTicket() async {
    try {
      final data = await supabase
          .from('tickets')
          .select(
            '*, student:profiles!tickets_student_id_fkey(id,first_name,last_name,role)',
          )
          .eq('id', widget.ticketId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          ticketStatus = data['status'] ?? "open";
          requesterId = data['student_id']?.toString() ?? "";

          final s = data['student'];
          final Map<String, dynamic>? sm = s is List
              ? (s.isNotEmpty ? s[0] : null)
              : s;
          if (sm != null) {
            final f = (sm['first_name'] ?? '').toString();
            final l = (sm['last_name'] ?? '').toString();
            final name = "$f $l".trim();
            isTeacher = (sm['role'] ?? '') == 'teacher';
            if (name.isNotEmpty) requesterName = name;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching ticket: $e');
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final data = await supabase
          .from('ticket_messages')
          .select('*')
          .eq('ticket_id', widget.ticketId)
          .order('created_at', ascending: true);

      if (mounted) {
        final newMessages = (data as List)
            .map((m) => AdminMessage.fromJson(m))
            .toList();
        if (newMessages.length != messages.length) {
          setState(() => messages = newMessages);
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
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

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || isSending) return;

    _controller.clear();
    setState(() => isSending = true);

    try {
      await supabase.from('ticket_messages').insert({
        'ticket_id': widget.ticketId,
        'sender_id': myAdminId,
        'message_text': text,
      });

      if (requesterId.isNotEmpty) {
        await supabase.from("user_notifications").insert({
          'user_id': requesterId,
          'sender_id': myAdminId,
          'title': "💬 Support Reply",
          'message': text,
          'notification_type': "support_message",
          'link_url': "/support_chat/${widget.ticketId}",
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (ticketStatus.toLowerCase() == 'closed') {
        await supabase
            .from('tickets')
            .update({'status': 'open'})
            .eq('id', widget.ticketId);
        if (mounted) setState(() => ticketStatus = 'open');
      }
      await _fetchMessages();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending admin message: $e');
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  Future<void> _toggleClose() async {
    final newStatus = ticketStatus.toLowerCase() == 'closed'
        ? 'open'
        : 'closed';
    try {
      await supabase
          .from('tickets')
          .update({'status': newStatus})
          .eq('id', widget.ticketId);
      if (mounted) {
        setState(() => ticketStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'closed'
                  ? "Conversation successfully closed."
                  : "Conversation reopened.",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            backgroundColor: newStatus == 'closed'
                ? Colors.grey.shade800
                : Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return "";
    }
  }

  Widget _buildAttachmentPreview(String url, bool isMe) {
    final lowerUrl = url.toLowerCase();
    final isImage =
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp');

    Color boxBgColor = isMe
        ? Colors.white.withOpacity(0.2)
        : Colors.black.withOpacity(0.04);
    Color contentColor = isMe ? Colors.white : textDark;

    if (isImage) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.3) : cardBorder,
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
          color: boxBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: isMe ? Colors.white : primaryPink,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Document Attached",
                style: TextStyle(
                  color: contentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: isMe ? Colors.white70 : textGrey.withOpacity(0.6),
              size: 18,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isClosed = ticketStatus.toLowerCase() == 'closed';
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF3F4F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ================= شیشه‌ای هدر (Glassmorphism App Bar) =================
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
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
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isTeacher
                                  ? [
                                      Colors.indigo.shade300,
                                      Colors.indigo.shade500,
                                    ]
                                  : [primaryPink, deepPink],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isTeacher
                                    ? Colors.indigo.withOpacity(0.3)
                                    : primaryPink.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            isTeacher
                                ? Icons.psychology_rounded
                                : Icons.school_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                requesterName.isEmpty
                                    ? "Support Chat"
                                    : requesterName,
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
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isClosed
                                          ? Colors.red
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isClosed
                                        ? "Ticket Closed"
                                        : (isTeacher
                                              ? "Teacher Online"
                                              : "Student Online"),
                                    style: TextStyle(
                                      color: isClosed ? Colors.red : textGrey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // دکمه تغییر وضعیت تیکت
                        GestureDetector(
                          onTap: _toggleClose,
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isClosed
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isClosed
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isClosed
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 14,
                                  color: isClosed
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isClosed ? "Reopen" : "Close",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isClosed
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
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

              // ================= ناحیه چت =================
              Expanded(
                child: Stack(
                  children: [
                    if (isClosed)
                      Positioned(
                        top: 10,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: textGrey,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "This conversation is currently closed.",
                                style: TextStyle(
                                  color: textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryPink,
                            ),
                          )
                        : messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: primaryPink.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.forum_rounded,
                                    color: primaryPink,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "No Messages Found",
                                  style: TextStyle(
                                    color: textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Send a message to start the conversation.",
                                  style: TextStyle(
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                            physics: const BouncingScrollPhysics(),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final m = messages[index];

                              final bool isMe = m.senderId == myAdminId;
                              final bool isRequester =
                                  m.senderId == requesterId &&
                                  m.senderId != null;
                              final bool isAi =
                                  m.senderId == 'ai' ||
                                  m.senderId == null ||
                                  m.senderId == '';

                              Alignment alignment;
                              Color bgColor;
                              Color textColor;
                              Color timeColor;
                              Widget? senderLabel;

                              if (isMe) {
                                alignment = Alignment.centerRight;
                                bgColor = primaryPink; // ادمین فعلی
                                textColor = Colors.white;
                                timeColor = Colors.white70;
                              } else if (isRequester) {
                                alignment = Alignment.centerLeft;
                                bgColor = surfaceWhite; // کاربر
                                textColor = textDark;
                                timeColor = textGrey;
                                senderLabel = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isTeacher
                                          ? Icons.psychology_rounded
                                          : Icons.person_rounded,
                                      size: 12,
                                      color: textGrey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      requesterName.isEmpty
                                          ? "User"
                                          : requesterName,
                                      style: const TextStyle(
                                        color: textGrey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                );
                              } else if (isAi) {
                                alignment = Alignment.centerLeft;
                                bgColor = Colors.purple.shade50; // ربات
                                textColor = Colors.purple.shade900;
                                timeColor = Colors.purple.shade400;
                                senderLabel = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: aiColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.smart_toy_rounded,
                                        size: 10,
                                        color: aiColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Safi AI 🤖",
                                      style: TextStyle(
                                        color: aiColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                alignment = Alignment.centerLeft;
                                bgColor = Colors.blue.shade50; // ادمین‌های دیگر
                                textColor = Colors.blue.shade900;
                                timeColor = Colors.blue.shade400;
                                senderLabel = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: otherAdminColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.support_agent_rounded,
                                        size: 10,
                                        color: otherAdminColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Other Agent",
                                      style: TextStyle(
                                        color: otherAdminColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Align(
                                alignment: alignment,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.75,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isMe ? null : bgColor,
                                    gradient: isMe
                                        ? const LinearGradient(
                                            colors: [primaryPink, deepPink],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(20)
                                        .copyWith(
                                          bottomRight: isMe
                                              ? const Radius.circular(0)
                                              : const Radius.circular(20),
                                          bottomLeft: !isMe
                                              ? const Radius.circular(0)
                                              : const Radius.circular(20),
                                        ),
                                    border: isMe
                                        ? null
                                        : Border.all(
                                            color: cardBorder,
                                            width: 1.5,
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isMe
                                            ? primaryPink.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (senderLabel != null) ...[
                                        senderLabel,
                                        const SizedBox(height: 6),
                                      ],
                                      Text(
                                        m.text,
                                        textDirection:
                                            m.text.contains(
                                              RegExp(r'[\u0600-\u06FF]'),
                                            )
                                            ? TextDirection.rtl
                                            : TextDirection.ltr,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (m.attachmentUrl != null &&
                                          m.attachmentUrl!.isNotEmpty)
                                        _buildAttachmentPreview(
                                          m.attachmentUrl!,
                                          isMe,
                                        ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          _formatTime(m.createdAt),
                                          style: TextStyle(
                                            color: timeColor,
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
                  ],
                ),
              ),

              // ================= کپسول شناور ارسال پیام =================
              if (!isClosed)
                Container(
                  margin: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: bottomPadding > 0 ? bottomPadding + 8 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                "Reply to ${requesterName.split(' ').first}...",
                            hintStyle: const TextStyle(
                              color: Colors.black38,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      GestureDetector(
                        onTap: isSending ? null : _handleSend,
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
                          child: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(
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
        ),
      ),
    );
  }
}
