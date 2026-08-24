import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MessageStatus { sending, sent, delivered, read }

class DirectChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String? attachmentUrl;
  final String createdAt;
  final bool isMe;
  final MessageStatus status;

  DirectChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.attachmentUrl,
    required this.createdAt,
    required this.isMe,
    this.status = MessageStatus.sent,
  });
}

class DirectChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerAvatar;

  const DirectChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  bool isSending = false;
  bool showEmojiPicker = false;
  List<DirectChatMessage> messages = [];
  RealtimeChannel? _chatChannel;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  final List<String> quickEmojis = ["❤️", "🔥", "👍", "🚀", "😍", "🎯", "👏", "💡"];

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToRealtimeChat();
    // ریفرش اتوماتیک فوق‌العاده سریع هر 400 میلی‌ثانیه برای دریافت آنی پیام‌ها
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) _fetchMessages(showLoading: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_chatChannel != null) {
      supabase.removeChannel(_chatChannel!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToRealtimeChat() {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      _chatChannel = supabase
          .channel('direct_messages_${widget.peerId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'direct_messages',
            callback: (payload) {
              _fetchMessages(showLoading: false);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Realtime channel subscription error: $e");
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

  bool isFriend = false;

  Future<void> _fetchMessages({bool showLoading = true}) async {
    if (showLoading) setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final currentUserId = user.id;

      // بررسی وضعیت دوستی (accepted) در جدول student_friends
      bool friendStatus = false;
      try {
        final friendCheck = await supabase
            .from("student_friends")
            .select("id")
            .or("and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.peerId}),and(sender_id.eq.${widget.peerId},receiver_id.eq.$currentUserId)")
            .eq("status", "accepted")
            .maybeSingle();

        friendStatus = friendCheck != null;
      } catch (_) {}

      // دریافت پیام‌های چت اختصاصی از جدول direct_messages
      final res = await supabase
          .from("direct_messages")
          .select("*")
          .or("and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.peerId}),and(sender_id.eq.${widget.peerId},receiver_id.eq.$currentUserId)")
          .order("created_at", ascending: true);

      List<DirectChatMessage> loadedMessages = [];

      for (var m in (res as List)) {
        final senderId = m['sender_id']?.toString() ?? '';
        final isRead = m['is_read'] == true;
        final isDelivered = m['is_delivered'] == true || isRead;

        MessageStatus status = MessageStatus.sent;
        if (isRead) {
          status = MessageStatus.read; // تیک آبی دوتایی
        } else if (isDelivered) {
          status = MessageStatus.delivered; // تیک خاکستری دوتایی
        } else {
          status = MessageStatus.sent; // تک تیک خاکستری
        }

        loadedMessages.add(DirectChatMessage(
          id: m['id']?.toString() ?? '',
          senderId: senderId,
          text: m['message_text'] ?? '',
          attachmentUrl: m['attachment_url'],
          createdAt: m['created_at'] ?? DateTime.now().toIso8601String(),
          isMe: senderId == currentUserId,
          status: status,
        ));
      }

      // علامت‌گذاری پیام‌های خوانده‌نشده به‌عنوان خوانده‌شده (تیک آبی)
      try {
        await supabase
            .from("direct_messages")
            .update({
              'is_read': true,
              'is_delivered': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq("sender_id", widget.peerId)
            .eq("receiver_id", currentUserId)
            .eq("is_read", false);
      } catch (_) {}

      if (mounted) {
        setState(() {
          isFriend = friendStatus;
          messages = loadedMessages;
          isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint("Error fetching direct messages: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from("student_friends").insert({
        'sender_id': user.id,
        'receiver_id': widget.peerId,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("درخواست دوستی شما با موفقیت ارسال شد! 🤝")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("درخواست دوستی قبلاً ارسال شده یا خطایی رخ داد: $e")),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || isSending) return;

    _messageController.clear();
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final tempMsg = DirectChatMessage(
      id: "temp-${DateTime.now().millisecondsSinceEpoch}",
      senderId: user.id,
      text: text,
      createdAt: DateTime.now().toIso8601String(),
      isMe: true,
      status: MessageStatus.sending, // در حال ارسال (آیکون ساعت)
    );

    setState(() {
      messages.add(tempMsg);
      isSending = true;
      showEmojiPicker = false;
    });
    _scrollToBottom();

    try {
      final inserted = await supabase
          .from("direct_messages")
          .insert({
            'sender_id': user.id,
            'receiver_id': widget.peerId,
            'message_text': text,
            'is_delivered': true, // تحویل به سرور
          })
          .select()
          .single();

      // ثبت نوتیفیکیشن درون‌برنامه‌ای برای کاربر گیرنده
      try {
        await supabase.from("user_notifications").insert({
          'user_id': widget.peerId,
          'title': "💬 پیام جدید",
          'message': text,
          'notification_type': "direct_message",
          'link_url': "/chat/${user.id}",
          'is_read': false,
        });
      } catch (_) {}

      if (mounted) {
        setState(() {
          messages.removeWhere((m) => m.id == tempMsg.id);
          messages.add(DirectChatMessage(
            id: inserted['id'].toString(),
            senderId: user.id,
            text: inserted['message_text'],
            attachmentUrl: inserted['attachment_url'],
            createdAt: inserted['created_at'],
            isMe: true,
            status: MessageStatus.sent, // تک تیک خاکستری
          ));
          isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error sending direct message: $e");
      if (mounted) setState(() => isSending = false);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: lightPinkBg,
                  backgroundImage: widget.peerAvatar.isNotEmpty ? NetworkImage(widget.peerAvatar) : null,
                  child: widget.peerAvatar.isEmpty
                      ? Text(widget.peerName.isNotEmpty ? widget.peerName[0] : 'U', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold))
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peerName, style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
                const Text("Online now", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const Divider(color: cardBorder, height: 1),

          // ================= لیست پیام‌ها =================
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildChatBubble(msg);
                    },
                  ),
          ),

          // ================= نوار ایموجی سریع =================
          if (showEmojiPicker)
            Container(
              color: cardBorder.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: quickEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      _messageController.text += emoji;
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  );
                }).toList(),
              ),
            ),

          // ================= ورودی پیام یا کادر غیرفعال برای غیر دوستان =================
          SafeArea(
            top: false,
            child: !isFriend
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "شما باید ابتدا با این کاربر دوست شوید تا بتوانید به او پیام بفرستید.",
                                style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _sendFriendRequest,
                            icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                            label: const Text("ارسال درخواست دوستی", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined, color: textGrey, size: 22),
                          onPressed: () => setState(() => showEmojiPicker = !showEmojiPicker),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: "Write a message...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 12),
                              filled: true,
                              fillColor: cardBorder.withValues(alpha: 0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: cardBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// ساخت حباب چت و آیکون‌های وضعیت (۱ تیک، ۲ تیک، ۲ تیک آبی)
  Widget _buildChatBubble(DirectChatMessage msg) {
    bool isMe = msg.isMe;

    Widget statusIcon;
    switch (msg.status) {
      case MessageStatus.sending:
        statusIcon = const Icon(Icons.access_time_rounded, color: Colors.white70, size: 12);
        break;
      case MessageStatus.sent:
        // ۱ تیک خاکستری (ارسال به سرور)
        statusIcon = const Icon(Icons.check_rounded, color: Colors.white70, size: 13);
        break;
      case MessageStatus.delivered:
        // ۲ تیک خاکستری (تحویل داده شده به دیوایس کاربر آنلاین/آفلان)
        statusIcon = const Icon(Icons.done_all_rounded, color: Colors.white70, size: 14);
        break;
      case MessageStatus.read:
        // ۲ تیک آبی روشن (مشاهده شده توسط گیرنده)
        statusIcon = const Icon(Icons.done_all_rounded, color: Color(0xFF80DEEA), size: 14);
        break;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? primaryPink : lightPinkBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : textDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white.withValues(alpha: 0.8) : textGrey,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
