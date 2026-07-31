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

      // اگر تیکت باز بود ولی در حالت open اولیه بود، به in_progress تغییر دهیم
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
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: CircularProgressIndicator(color: Colors.indigoAccent, strokeWidth: 2.5),
        ),
      );
    }

    if (ticket == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(child: Text("Ticket not found", style: TextStyle(color: Colors.white))),
      );
    }

    bool isClosed = ticket!['status'] == "closed" || ticket!['status'] == "resolved";

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                          SizedBox(width: 6),
                          Text("Back to Support", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isClosed ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                      foregroundColor: isClosed ? Colors.greenAccent : Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isClosed ? "Reopen Ticket" : "Mark as Resolved", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    onPressed: () => handleUpdateStatus(isClosed ? "open" : "closed"),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Subject Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0a0a0f),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket!['subject'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text("Student: ${ticket!['profiles']?['first_name'] ?? ''} ${ticket!['profiles']?['last_name'] ?? ''}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isClosed ? Colors.green.withOpacity(0.15) : Colors.indigo.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ticket!['status'].toUpperCase(), style: TextStyle(color: isClosed ? Colors.greenAccent : Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold)),
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
                    color: const Color(0xFF0a0a0f).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: messages.isEmpty
                      ? const Center(child: Text("No messages yet.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            bool isAdmin = msg['profiles']?['role'] == "super_admin" || msg['sender_id'] != ticket!['student_id'];

                            return Align(
                              alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(maxWidth: 260),
                                decoration: BoxDecoration(
                                  color: isAdmin ? Colors.indigoAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isAdmin ? Colors.indigoAccent.withOpacity(0.3) : Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isAdmin ? "Support Agent" : (msg['profiles']?['first_name'] ?? 'User'), style: TextStyle(color: isAdmin ? Colors.indigoAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(msg['message_text'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Reply Input Area
              if (isClosed)
                Container(
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text("This ticket is closed. Reopen it to send a message.", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: "Type your official response...",
                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.indigoAccent, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSending ? null : handleSendMessage,
                        child: isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, size: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}