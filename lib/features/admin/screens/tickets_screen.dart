import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileInfo {
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String email;

  ProfileInfo({required this.firstName, required this.lastName, this.avatarUrl, required this.email});

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'],
      email: json['email'] ?? '',
    );
  }
}

class TicketItem {
  final String id;
  final String studentId;
  final String subject;
  final String department;
  final String status; // "OPEN" | "CLOSED" | "PENDING"
  final String createdAt;
  final ProfileInfo? student;
  final String? role; // نقش درخواست‌دهنده: 'teacher' | 'student' | ...

  TicketItem({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.department,
    required this.status,
    required this.createdAt,
    this.student,
    this.role,
  });

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    final studentObj = json['student'];
    Map<String, dynamic>? formattedStudent = studentObj is List ? (studentObj.isNotEmpty ? studentObj[0] : null) : studentObj;

    return TicketItem(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      subject: json['subject'] ?? '',
      department: json['department'] ?? '',
      status: json['status'] ?? 'OPEN',
      createdAt: json['created_at'] ?? '',
      student: formattedStudent != null ? ProfileInfo.fromJson(formattedStudent) : null,
      role: formattedStudent?['role'],
    );
  }

  bool get isTeacher => role == 'teacher';
}

class TicketMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String messageText;
  final String createdAt;
  final ProfileInfo? sender;

  TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.messageText,
    required this.createdAt,
    this.sender,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    final senderObj = json['sender'];
    Map<String, dynamic>? formattedSender = senderObj is List ? (senderObj.isNotEmpty ? senderObj[0] : null) : senderObj;

    return TicketMessage(
      id: json['id'] ?? '',
      ticketId: json['ticket_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      messageText: json['message_text'] ?? '',
      createdAt: json['created_at'] ?? '',
      sender: formattedSender != null ? ProfileInfo.fromJson(formattedSender) : null,
    );
  }
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<TicketItem> tickets = [];
  String searchQuery = "";
  String filterStatus = "ALL"; // "ALL" | "OPEN" | "CLOSED"
  String filterRole = "ALL"; // "ALL" | "STUDENT" | "TEACHER"

  TicketItem? selectedTicket;
  List<TicketMessage> messages = [];
  bool isLoadingMessages = false;
  final replyCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isSending = false;
  Timer? _adminPollTimer;

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchTickets();
    _startAdminPolling();
  }

  @override
  void dispose() {
    _adminPollTimer?.cancel();
    replyCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAdminPolling() {
    _adminPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (selectedTicket != null && !isLoadingMessages && !isSending) {
        _pollSelectedTicketMessages();
      }
      _pollAllTicketsSilent();
    });
  }

  Future<void> _pollSelectedTicketMessages() async {
    if (selectedTicket == null) return;
    try {
      final response = await supabase
          .from("ticket_messages")
          .select("*, sender:profiles!sender_id(first_name, last_name, avatar_url, email)")
          .eq("ticket_id", selectedTicket!.id)
          .order("created_at", ascending: true);

      final newMessages = (response as List).map((m) => TicketMessage.fromJson(m)).toList();
      
      if (newMessages.length != messages.length) {
        if (mounted) {
          setState(() {
            messages = newMessages;
          });
          Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
        }
      }
    } catch (e) {
      debugPrint("Silent poll error: $e");
    }
  }

  Future<void> _pollAllTicketsSilent() async {
    try {
      final response = await supabase
          .from("tickets")
          .select("*, student:profiles!student_id(first_name, last_name, avatar_url, email, role)")
          .order("created_at", ascending: false);

      final newTickets = (response as List).map((t) => TicketItem.fromJson(t)).toList();
      
      if (mounted) {
        setState(() {
          tickets = newTickets;
          if (selectedTicket != null) {
            final updated = tickets.firstWhere(
              (t) => t.id == selectedTicket!.id,
              orElse: () => selectedTicket!,
            );
            selectedTicket = updated;
          }
        });
      }
    } catch (e) {
      debugPrint("Silent tickets poll error: $e");
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

  Future<void> _fetchTickets() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("tickets")
          .select("*, student:profiles!student_id(first_name, last_name, avatar_url, email, role)")
          .order("created_at", ascending: false);

      setState(() {
        tickets = (response as List).map((t) => TicketItem.fromJson(t)).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching tickets: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleSelectTicket(TicketItem ticket) async {
    setState(() {
      selectedTicket = ticket;
      isLoadingMessages = true;
    });

    try {
      final response = await supabase
          .from("ticket_messages")
          .select("*, sender:profiles!sender_id(first_name, last_name, avatar_url, email)")
          .eq("ticket_id", ticket.id)
          .order("created_at", ascending: true);

      setState(() {
        messages = (response as List).map((m) => TicketMessage.fromJson(m)).toList();
        isLoadingMessages = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      debugPrint("Error fetching messages: $e");
      if (mounted) setState(() => isLoadingMessages = false);
    }
  }

  Future<void> toggleTicketStatus() async {
    if (selectedTicket == null) return;
    String newStatus = selectedTicket!.status == "CLOSED" ? "OPEN" : "CLOSED";

    try {
      await supabase.from("tickets").update({'status': newStatus}).eq("id", selectedTicket!.id);

      setState(() {
        selectedTicket = TicketItem(
          id: selectedTicket!.id,
          studentId: selectedTicket!.studentId,
          subject: selectedTicket!.subject,
          department: selectedTicket!.department,
          status: newStatus,
          createdAt: selectedTicket!.createdAt,
          student: selectedTicket!.student,
        );
        tickets = tickets.map((t) => t.id == selectedTicket!.id ? selectedTicket! : t).toList();
      });
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  Future<void> handleSendReply() async {
    if (selectedTicket == null || replyCtrl.text.trim().isEmpty) return;

    setState(() => isSending = true);
    try {
      final session = supabase.auth.currentSession;
      final adminId = session?.user.id;

      final res = await supabase
          .from("ticket_messages")
          .insert({
            'ticket_id': selectedTicket!.id,
            'sender_id': adminId,
            'message_text': replyCtrl.text.trim(),
          })
          .select("*, sender:profiles!sender_id(first_name, last_name, avatar_url, email)")
          .single();

      final newMsg = TicketMessage.fromJson(res);

      if (selectedTicket!.status == "CLOSED") {
        await supabase.from("tickets").update({'status': 'OPEN'}).eq("id", selectedTicket!.id);
        setState(() {
          selectedTicket = TicketItem(
            id: selectedTicket!.id,
            studentId: selectedTicket!.studentId,
            subject: selectedTicket!.subject,
            department: selectedTicket!.department,
            status: 'OPEN',
            createdAt: selectedTicket!.createdAt,
            student: selectedTicket!.student,
          );
        });
      }

      setState(() {
        messages.add(newMsg);
        replyCtrl.clear();
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending reply: $e");
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  List<TicketItem> get filteredTickets {
    return tickets.where((t) {
      bool matchesFilter = filterStatus == "ALL" || t.status == filterStatus;
      bool matchesSearch = searchQuery.isEmpty ||
          t.subject.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (t.student?.firstName.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      bool matchesRole = filterRole == "ALL" ||
          (filterRole == "TEACHER" && t.isTeacher) ||
          (filterRole == "STUDENT" && !t.isTeacher);
      return matchesFilter && matchesSearch && matchesRole;
    }).toList();
  }

  Map<String, int> get stats {
    int open = tickets.where((t) => t.status == "OPEN").length;
    int closed = tickets.where((t) => t.status == "CLOSED").length;
    return {'open': open, 'closed': closed};
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

    final currentStats = stats;
    final currentFiltered = filteredTickets;

    // اگر تیکتی در موبایل انتخاب شده بود، صفحه چت را نشان بده
    if (selectedTicket != null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: textDark),
            onPressed: () => setState(() => selectedTicket = null),
          ),
          title: Text(selectedTicket!.subject, style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedTicket!.status == 'OPEN' ? Colors.redAccent.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                    foregroundColor: selectedTicket!.status == 'OPEN' ? Colors.redAccent : Colors.green.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: toggleTicketStatus,
                  child: Text(selectedTicket!.status == 'OPEN' ? "Close Ticket" : "Reopen", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: isLoadingMessages
                  ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5))
                  : messages.isEmpty
                      ? const Center(child: Text("No messages yet.", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)))
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            bool isAdmin = msg.senderId != selectedTicket!.studentId;

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
                                      msg.senderId == '' || msg.senderId == 'ai'
                                          ? "Support AI 🤖"
                                          : (msg.senderId == selectedTicket!.studentId
                                              ? "${selectedTicket!.isTeacher ? 'استاد' : 'دانشجو'} ${msg.sender?.firstName ?? ''}".trim()
                                              : "Support Agent (Human)"),
                                      style: TextStyle(color: (msg.senderId == '' || msg.senderId == 'ai') ? Colors.purple : (isAdmin ? primaryPink : textGrey), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(msg.messageText, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            // Reply Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceWhite,
                border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyCtrl,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Type your response...",
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
                      onPressed: isSending ? null : handleSendReply,
                      child: isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // نمای اصلی لیست تیکت‌ها برای موبایل
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "SUPPORT DESK",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.support_agent_rounded, color: primaryPink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("Support Desk", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark)),
                  const SizedBox(height: 4),
                  const Text("Resolve inquiries and manage support tickets.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat("Open", currentStats['open'].toString(), primaryPink)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStat("Resolved", currentStats['closed'].toString(), textGrey)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar & Filters
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cardBorder.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: primaryPink, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => searchQuery = val),
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Search tickets...",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Tabs
            Row(
              children: [
                Expanded(child: _buildFilterBtn("All", "ALL")),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterBtn("Open", "OPEN")),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterBtn("Closed", "CLOSED")),
              ],
            ),
            const SizedBox(height: 10),
            // فیلتر نقش درخواست‌دهنده (دانشجو / استاد)
            Row(
              children: [
                Expanded(child: _buildRoleFilterBtn("All", "ALL")),
                const SizedBox(width: 8),
                Expanded(child: _buildRoleFilterBtn("Students", "STUDENT")),
                const SizedBox(width: 8),
                Expanded(child: _buildRoleFilterBtn("Teachers", "TEACHER")),
              ],
            ),
            const SizedBox(height: 16),

            // Tickets List
            currentFiltered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No tickets found.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentFiltered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = currentFiltered[index];
                      bool isOpen = t.status == 'OPEN';
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isOpen ? lightPinkBg : cardBorder,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isOpen ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded,
                                color: isOpen ? primaryPink : textGrey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.subject, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: t.isTeacher
                                              ? Colors.indigo.withOpacity(0.12)
                                              : primaryPink.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t.isTeacher ? "استاد" : "دانشجو",
                                          style: TextStyle(
                                            color: t.isTeacher ? Colors.indigo : primaryPink,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          t.student != null
                                              ? "${t.student!.firstName} ${t.student!.lastName}"
                                              : "Unknown",
                                          style: const TextStyle(color: textGrey, fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lightPinkBg,
                                foregroundColor: primaryPink,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => handleSelectTicket(t),
                              child: const Text("Open Chat", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label, String statusKey) {
    bool isActive = filterStatus == statusKey;
    return GestureDetector(
      onTap: () => setState(() => filterStatus = statusKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? lightPinkBg : cardBorder.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? primaryPink : cardBorder, width: isActive ? 1.5 : 1),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isActive ? primaryPink : textGrey)),
      ),
    );
  }

  Widget _buildRoleFilterBtn(String label, String roleKey) {
    bool isActive = filterRole == roleKey;
    return GestureDetector(
      onTap: () => setState(() => filterRole = roleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? primaryPink.withOpacity(0.15) : cardBorder.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? primaryPink : cardBorder,
            width: isActive ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              roleKey == "TEACHER"
                  ? Icons.psychology_rounded
                  : roleKey == "STUDENT"
                      ? Icons.school_rounded
                      : Icons.people_alt_rounded,
              size: 13,
              color: isActive ? primaryPink : textGrey,
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isActive ? primaryPink : textGrey)),
          ],
        ),
      ),
    );
  }
}