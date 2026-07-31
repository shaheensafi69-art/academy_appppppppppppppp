import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  Map<String, dynamic>? ticket;
  List<Map<String, dynamic>> messages = [];
  final messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isSending = false;
  RealtimeChannel? _ticketChannel;

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _loadTicketData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    _scrollController.dispose();
    if (_ticketChannel != null) {
      supabase.removeChannel(_ticketChannel!);
    }
    super.dispose();
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

  Future<void> _loadTicketData() async {
    setState(() => isLoading = true);
    try {
      // ۱. اطلاعات اصلی تیکت به همراه پروفایل دانش‌آموز
      final ticketData = await supabase
          .from("tickets")
          .select("id, student_id, subject, department, status, created_at, profiles!student_id(first_name, last_name, avatar_url, role, email)")
          .eq("id", widget.ticketId)
          .single();

      final studentObj = ticketData['profiles'];
      Map<String, dynamic>? formattedStudent = studentObj is List ? (studentObj.isNotEmpty ? studentObj[0] : null) : studentObj;

      ticket = {
        ...ticketData,
        'profiles': formattedStudent,
      };

      // ۲. دریافت پیام‌های چت
      final msgData = await supabase
          .from("ticket_messages")
          .select("id, sender_id, message_text, created_at, profiles!sender_id(first_name, last_name, avatar_url, role)")
          .eq("ticket_id", widget.ticketId)
          .order("created_at", ascending: true);

      List<Map<String, dynamic>> formattedMsgs = [];
      for (var m in (msgData as List)) {
        final senderObj = m['profiles'];
        Map<String, dynamic>? formattedSender = senderObj is List ? (senderObj.isNotEmpty ? senderObj[0] : null) : senderObj;
        formattedMsgs.add({
          ...m,
          'profiles': formattedSender,
        });
      }
    
      if (mounted) {
        setState(() {
          messages = formattedMsgs;
          isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint("Error loading ticket: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _ticketChannel = supabase
        .channel('ticket_${widget.ticketId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: widget.ticketId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            final senderId = newRow['sender_id'];

            final senderInfo = await supabase
                .from("profiles")
                .select("first_name, last_name, avatar_url, role")
                .eq("id", senderId)
                .single();

            if (mounted) {
              setState(() {
                messages.add({
                  ...newRow,
                  'profiles': senderInfo,
                });
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  Future<void> handleSendMessage() async {
    if (messageCtrl.text.trim().isEmpty || ticket == null) return;

    setState(() => isSending = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from("ticket_messages").insert({
        'ticket_id': widget.ticketId,
        'sender_id': user.id,
        'message_text': messageCtrl.text.trim(),
      });

      messageCtrl.clear();

      // آپدیت وضعیت تیکت به in_progress در صورت باز بودن اولیه
      if (ticket!['status'] == "open" || ticket!['status'] == "OPEN") {
        await supabase.from("tickets").update({'status': 'in_progress'}).eq("id", widget.ticketId);
        setState(() {
          ticket!['status'] = 'in_progress';
        });
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  Future<void> handleUpdateStatus(String newStatus) async {
    try {
      await supabase.from("tickets").update({'status': newStatus}).eq("id", widget.ticketId);
      setState(() {
        ticket!['status'] = newStatus;
      });
    } catch (e) {
      debugPrint("Error updating status: $e");
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
              Text("LOADING TICKET CONVERSATION...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (ticket == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: const Center(child: Text("Ticket not found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold))),
      );
    }

    bool isClosed = ticket!['status'] == "closed" || ticket!['status'] == "resolved";

    return Scaffold(
      backgroundColor: surfaceWhite,
      resizeToAvoidBottomInset: true, // جلوگیری از به هم ریختگی صفحه با کیبورد گوشی
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: textDark, size: 14),
                    SizedBox(width: 4),
                    Text("Back", style: TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClosed ? Colors.green.withOpacity(0.12) : lightPinkBg,
                  foregroundColor: isClosed ? Colors.green.shade700 : primaryPink,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isClosed ? "Reopen Ticket" : "Mark Resolved", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                onPressed: () => handleUpdateStatus(isClosed ? "open" : "closed"),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject Card
            Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket!['subject'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text("Student: ${ticket!['profiles']?['first_name'] ?? ''} ${ticket!['profiles']?['last_name'] ?? ''}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isClosed ? Colors.green.withOpacity(0.12) : lightPinkBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket!['status'].toUpperCase(),
                      style: TextStyle(color: isClosed ? Colors.green.shade700 : primaryPink, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Chat Messages Container
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBorder.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: messages.isEmpty
                    ? const Center(child: Text("No messages yet. Start the conversation!", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)))
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          bool isAdmin = msg['profiles']?['role'] == "super_admin" || msg['sender_id'] != ticket!['student_id'];

                          return Align(
                            alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isAdmin ? lightPinkBg : surfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isAdmin ? primaryPink.withOpacity(0.2) : cardBorder, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAdmin ? "Support Agent" : (msg['profiles']?['first_name'] ?? 'User'),
                                    style: TextStyle(color: isAdmin ? primaryPink : textGrey, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(msg['message_text'], style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Reply Input Area
            if (isClosed)
              Container(
                padding: const EdgeInsets.all(14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5)),
                child: const Text("This ticket is closed. Reopen it to send a message.", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900)),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageCtrl,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Type your official response...",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        filled: true,
                        fillColor: cardBorder.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    width: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSending ? null : handleSendMessage,
                      child: isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}