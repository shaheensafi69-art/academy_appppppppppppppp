import 'dart:ui';
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

  TicketItem({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.department,
    required this.status,
    required this.createdAt,
    this.student,
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
    );
  }
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

  TicketItem? selectedTicket;
  List<TicketMessage> messages = [];
  bool isLoadingMessages = false;
  final replyCtrl = TextEditingController();
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  @override
  void dispose() {
    replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("tickets")
          .select("*, student:profiles!student_id(first_name, last_name, avatar_url, email)")
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
      return matchesFilter && matchesSearch;
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
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING SUPPORT DESK...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final currentStats = stats;
    final currentFiltered = filteredTickets;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Column(
                children: [
                  // ================= HEADER =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Support Desk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text("Resolve inquiries and manage support tickets.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                          ],
                        ),
                        Row(
                          children: [
                            _buildMiniStat("Open", currentStats['open'].toString(), Colors.blueAccent),
                            const SizedBox(width: 8),
                            _buildMiniStat("Resolved", currentStats['closed'].toString(), Colors.grey),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ================= MAIN LAYOUT =================
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: TICKET LIST (Fixed width on tablet/desktop, full if no selection on mobile)
                        Container(
                          width: 280,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a0a0f).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: [
                                    TextField(
                                      onChanged: (val) => setState(() => searchQuery = val),
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                      decoration: InputDecoration(
                                        hintText: "Search tickets...",
                                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 14),
                                        filled: true,
                                        fillColor: Colors.black.withOpacity(0.4),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildFilterBtn("All", "ALL"),
                                        const SizedBox(width: 4),
                                        _buildFilterBtn("Open", "OPEN"),
                                        const SizedBox(width: 4),
                                        _buildFilterBtn("Closed", "CLOSED"),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              Expanded(
                                child: currentFiltered.isEmpty
                                    ? const Center(child: Text("No tickets", style: TextStyle(color: Colors.grey, fontSize: 10)))
                                    : ListView.separated(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: currentFiltered.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                                        itemBuilder: (context, index) {
                                          final t = currentFiltered[index];
                                          bool isSelected = selectedTicket?.id == t.id;
                                          return GestureDetector(
                                            onTap: () => handleSelectTicket(t),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.04)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(child: Text(t.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: t.status == 'OPEN' ? Colors.blueAccent : Colors.grey)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(t.student != null ? "${t.student!.firstName} ${t.student!.lastName}" : "Unknown", style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // RIGHT: CHAT INTERFACE
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0f).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: selectedTicket == null
                                ? const Center(child: Text("Select a ticket to view conversation", style: TextStyle(color: Colors.grey, fontSize: 11)))
                                : Column(
                                    children: [
                                      // Chat Header
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(selectedTicket!.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  Text("Department: ${selectedTicket!.department}", style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: selectedTicket!.status == 'OPEN' ? Colors.redAccent.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                                foregroundColor: selectedTicket!.status == 'OPEN' ? Colors.redAccent : Colors.greenAccent,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: toggleTicketStatus,
                                              child: Text(selectedTicket!.status == 'OPEN' ? "Close" : "Reopen", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Messages
                                      Expanded(
                                        child: isLoadingMessages
                                            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2))
                                            : messages.isEmpty
                                                ? const Center(child: Text("No messages yet.", style: TextStyle(color: Colors.grey, fontSize: 11)))
                                                : ListView.builder(
                                                    padding: const EdgeInsets.all(12),
                                                    itemCount: messages.length,
                                                    itemBuilder: (context, index) {
                                                      final msg = messages[index];
                                                      bool isAdmin = msg.senderId != selectedTicket!.studentId;
                                                      return Align(
                                                        alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                                        child: Container(
                                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                                          padding: const EdgeInsets.all(10),
                                                          constraints: const BoxConstraints(maxWidth: 260),
                                                          decoration: BoxDecoration(
                                                            color: isAdmin ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(color: isAdmin ? Colors.blueAccent.withOpacity(0.3) : Colors.white10),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(isAdmin ? "Support Agent" : msg.sender?.firstName ?? 'User', style: TextStyle(color: isAdmin ? Colors.blueAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                                                              const SizedBox(height: 2),
                                                              Text(msg.messageText, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                      ),

                                      // Reply Input
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: replyCtrl,
                                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                                decoration: InputDecoration(
                                                  hintText: "Type your response...",
                                                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                                  filled: true,
                                                  fillColor: Colors.black.withOpacity(0.4),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.blueAccent, size: 18),
                                              onPressed: isSending ? null : handleSendReply,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Text("$title: ", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label, String statusKey) {
    bool isActive = filterStatus == statusKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterStatus = statusKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey)),
        ),
      ),
    );
  }
}