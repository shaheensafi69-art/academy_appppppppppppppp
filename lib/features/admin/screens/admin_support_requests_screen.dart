import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';
import 'admin_support_chat_screen.dart';

class SupportRequest {
  final String id;
  final String studentId;
  final String subject;
  final String department;
  final String status;
  final String createdAt;
  final Map<String, dynamic>? student;
  final List<dynamic> messages;

  SupportRequest({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.department,
    required this.status,
    required this.createdAt,
    this.student,
    this.messages = const [],
  });

  factory SupportRequest.fromJson(Map<String, dynamic> json) {
    final studentObj = json['profiles'] ?? json['student'];
    final Map<String, dynamic>? studentMap = studentObj is List
        ? (studentObj.isNotEmpty ? studentObj[0] : null)
        : studentObj;
    final List<dynamic> msgs = (json['ticket_messages'] as List?) ?? [];

    return SupportRequest(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      subject: json['subject'] ?? 'Live Support',
      department: json['department'] ?? 'General',
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] ?? '',
      student: studentMap,
      messages: msgs,
    );
  }

  String get fullName {
    if (student == null) return 'User';
    final f = (student!['first_name'] ?? '').toString();
    final l = (student!['last_name'] ?? '').toString();
    final name = "$f $l".trim();
    return name.isEmpty ? 'User' : name;
  }

  String get role => (student?['role'] ?? '').toString();
  bool get isTeacher => role == 'teacher';

  String? get lastMessage {
    if (messages.isEmpty) return null;
    final sorted = List.from(messages);
    sorted.sort(
      (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
    );
    return sorted.last['message_text']?.toString();
  }

  bool get hasAdminReply {
    if (messages.isEmpty) return false;
    for (var msg in messages) {
      final sid = msg['sender_id']?.toString();
      if (sid != null && sid.isNotEmpty && sid != 'ai' && sid != studentId) {
        return true;
      }
    }
    return false;
  }

  int get messageCount => messages.length;
}

class AdminSupportRequestsScreen extends StatefulWidget {
  const AdminSupportRequestsScreen({super.key});

  @override
  State<AdminSupportRequestsScreen> createState() =>
      _AdminSupportRequestsScreenState();
}

class _AdminSupportRequestsScreenState
    extends State<AdminSupportRequestsScreen> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _ticketsSubscription;

  bool isLoading = true;
  String? errorMessage;

  List<SupportRequest> requests = [];
  String filterRole = "ALL";
  String filterStatus = "ALL";
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Luxury Light-Pink Theme Palette
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  static const Color colorPending = Color(0xFFFFB300);
  static const Color colorActive = Color(0xFF10B981);
  static const Color colorClosed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _ticketsSubscription?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _ticketsSubscription = supabase
        .channel('public:tickets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tickets',
          callback: (payload) {
            _fetchRequests();
          },
        )
        .subscribe();
  }

  Future<void> _fetchRequests() async {
    if (!mounted) return;
    if (requests.isEmpty) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final data = await supabase
          .from('tickets')
          .select(
            '*, profiles!tickets_student_id_fkey(first_name,last_name,avatar_url,email,role), ticket_messages(id,message_text,sender_id,created_at)',
          )
          .order('created_at', ascending: false);

      _parseData(data);
    } catch (e1) {
      try {
        final data2 = await supabase
            .from('tickets')
            .select(
              '*, profiles!fk_tickets_student(first_name,last_name,avatar_url,email,role), ticket_messages(id,message_text,sender_id,created_at)',
            )
            .order('created_at', ascending: false);

        _parseData(data2);
      } catch (e2) {
        debugPrint('DB Error: $e2');
        if (mounted) {
          setState(() {
            errorMessage = e2.toString();
          });
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _parseData(dynamic data) {
    final List<SupportRequest> parsed = [];
    for (var item in (data as List)) {
      parsed.add(SupportRequest.fromJson(item));
    }
    if (mounted) {
      setState(() {
        requests = parsed;
        errorMessage = null;
      });
    }
  }

  List<SupportRequest> get filtered {
    return requests.where((r) {
      final matchesRole =
          filterRole == "ALL" ||
          (filterRole == "TEACHER" && r.isTeacher) ||
          (filterRole == "STUDENT" && !r.isTeacher);

      bool matchesStatus = true;
      if (filterStatus == "OPEN") {
        matchesStatus = r.status.toLowerCase() == 'open';
      } else if (filterStatus == "ACTIVE") {
        matchesStatus =
            r.status.toLowerCase() == 'escalated' ||
            r.status.toLowerCase() == 'answered';
      } else if (filterStatus == "CLOSED") {
        matchesStatus = r.status.toLowerCase() == 'closed';
      }

      final q = searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          r.subject.toLowerCase().contains(q) ||
          r.fullName.toLowerCase().contains(q) ||
          (r.lastMessage?.toLowerCase().contains(q) ?? false);

      return matchesRole && matchesStatus && matchesSearch;
    }).toList();
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m";
      if (diff.inHours < 24) return "${diff.inHours}h";
      return "${dt.day}/${dt.month}";
    } catch (_) {
      return "";
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'closed') return colorClosed;
    if (s == 'escalated' || s == 'answered') return colorActive;
    return colorPending;
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;

    int pendingCount = requests
        .where((r) => r.status.toLowerCase() == 'open')
        .length;
    int activeCount = requests
        .where(
          (r) =>
              r.status.toLowerCase() == 'escalated' ||
              r.status.toLowerCase() == 'answered',
        )
        .length;
    int closedCount = requests
        .where((r) => r.status.toLowerCase() == 'closed')
        .length;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Column(
                    children: [
                      Text(
                        context.l10n.supportHelpDesk,
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        context.l10n.liveSupportSubtitle,
                        style: const TextStyle(
                          color: textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: primaryPink,
                      size: 22,
                    ),
                    onPressed: _fetchRequests,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Stat Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context.l10n.pending.toUpperCase(),
                      pendingCount,
                      colorPending,
                      Icons.hourglass_top_rounded,
                      "OPEN",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      "ACTIVE",
                      activeCount,
                      colorActive,
                      Icons.support_agent_rounded,
                      "ACTIVE",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      context.l10n.ticketStatusClosed.toUpperCase(),
                      closedCount,
                      colorClosed,
                      Icons.check_circle_rounded,
                      "CLOSED",
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => searchQuery = v),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.searchSupportHint,
                    hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primaryPink,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // Filter Role Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _filterChip(
                      context.l10n.allUsers,
                      "ALL",
                      filterRole,
                      (v) => setState(() => filterRole = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      context.l10n.studentsOnly,
                      "STUDENT",
                      filterRole,
                      (v) => setState(() => filterRole = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      context.l10n.teachersOnly,
                      "TEACHER",
                      filterRole,
                      (v) => setState(() => filterRole = v),
                    ),
                  ),
                ],
              ),
            ),

            // Requests List
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryPink),
                    )
                  : errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mark_chat_read_rounded,
                              size: 36,
                              color: primaryPink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.noSupportRequests,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ).copyWith(bottom: 90),
                      physics: const BouncingScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final r = list[index];
                        return _buildRequestCard(r);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    int count,
    Color color,
    IconData icon,
    String statusKey,
  ) {
    bool isSelected = filterStatus == statusKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          filterStatus = isSelected ? "ALL" : statusKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? lightPinkBg : surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryPink : cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? primaryPink.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.02),
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
                Icon(icon, color: isSelected ? primaryPink : color, size: 18),
                Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? primaryPink : textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isSelected ? primaryPink : textGrey,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(SupportRequest r) {
    final statusColor = _getStatusColor(r.status);
    final hasAdminReplied = r.hasAdminReply;

    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminSupportChatScreen(
                  ticketId: r.id,
                  requesterName: r.fullName,
                  isTeacher: r.isTeacher,
                  initialStatus: r.status,
                ),
              ),
            ).then((_) => _fetchRequests());
          },
          child: Row(
            children: [
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: r.isTeacher
                              ? Colors.indigo.shade50
                              : lightPinkBg,
                          border: Border.all(
                            color: r.isTeacher
                                ? Colors.indigo.shade100
                                : primaryPink.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            r.isTeacher
                                ? Icons.psychology_rounded
                                : Icons.person_rounded,
                            color: r.isTeacher
                                ? Colors.indigo.shade400
                                : primaryPink,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.fullName,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _formatTime(r.createdAt),
                                  style: const TextStyle(
                                    color: textGrey,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.subject,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.lastMessage ?? context.l10n.noMessages,
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasAdminReplied &&
                                r.status.toLowerCase() != 'closed')
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: lightPinkBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: primaryPink.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.how_to_reg_rounded,
                                      size: 10,
                                      color: primaryPink,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      context.l10n.supportHelpDesk,
                                      style: const TextStyle(
                                        color: primaryPink,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
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
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    String key,
    String active,
    void Function(String) onTap,
  ) {
    final isActive = active == key;
    return GestureDetector(
      onTap: () => onTap(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryPink : cardBorder.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? primaryPink : cardBorder,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isActive ? Colors.white : textGrey,
          ),
        ),
      ),
    );
  }
}
