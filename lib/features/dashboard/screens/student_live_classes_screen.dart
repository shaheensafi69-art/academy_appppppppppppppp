import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/language_service.dart';
import 'student_class_detail_screen.dart';
import 'student_groups_screen.dart';

class ClassGroup {
  final String id;
  final String className;
  final String scheduleInfo;
  final bool isActive;
  final String startDate;
  final String? meetingLink;
  final String? signalGroupLink;
  final bool isPaid;
  final Map<String, dynamic>? teacher;
  final Map<String, dynamic> rawData;

  ClassGroup({
    required this.id,
    required this.className,
    required this.scheduleInfo,
    required this.isActive,
    required this.startDate,
    this.meetingLink,
    this.signalGroupLink,
    required this.isPaid,
    required this.teacher,
    required this.rawData,
  });

  factory ClassGroup.fromJson(Map<String, dynamic> json, String userId) {
    final studentRelationObj = json['class_students'];
    final studentRelation = studentRelationObj is List
        ? studentRelationObj.firstWhere((cs) => cs['student_id'] == userId, orElse: () => null)
        : studentRelationObj;

    final teacherObj = json['teacher'];
    final teacherData = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;

    final bool paid = studentRelation?['is_paid'] ?? false;
    final bool isTrial = studentRelation?['is_trial'] ?? false;
    final String? trialEndsAtStr = studentRelation?['trial_ends_at'];
    bool hasAccess = paid;
    if (isTrial && trialEndsAtStr != null) {
      final trialEndsAt = DateTime.tryParse(trialEndsAtStr);
      if (trialEndsAt != null && trialEndsAt.isAfter(DateTime.now())) {
        hasAccess = true;
      }
    }

    return ClassGroup(
      id: json['id'] ?? '',
      className: json['class_name'] ?? 'Unknown Class',
      scheduleInfo: json['schedule_info'] ?? '',
      isActive: json['is_active'] ?? false,
      startDate: json['start_date'] ?? '',
      meetingLink: json['meeting_link'],
      signalGroupLink: json['signal_group_link'],
      isPaid: hasAccess,
      teacher: teacherData,
      rawData: json,
    );
  }
}

class StudentLiveClassesScreen extends StatefulWidget {
  const StudentLiveClassesScreen({super.key});

  @override
  State<StudentLiveClassesScreen> createState() => _StudentLiveClassesScreenState();
}

class _StudentLiveClassesScreenState extends State<StudentLiveClassesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ClassGroup> classes = [];

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // Silently invoke the RPC to expire any outdated free trials in the database
      try {
        await supabase.rpc("expire_class_trials");
      } catch (err) {
        debugPrint("Silent trial expiration RPC failed: $err");
      }

      final response = await supabase
          .from("class_groups")
          .select("id, class_name, schedule_info, is_active, start_date, end_date, class_time, class_days, meeting_link, signal_group_link, teacher:profiles!teacher_id(first_name, last_name), class_students!inner(student_id, is_paid, is_trial, trial_ends_at)")
          .eq("class_students.student_id", userId)
          .order("is_active", ascending: false)
          .order("start_date", ascending: false);

      setState(() {
        classes = (response as List).map((cls) => ClassGroup.fromJson(cls, userId)).toList();
      });
    } catch (e) {
      debugPrint("Error loading enrolled classes: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveSessions = classes.where((c) => c.isActive).toList();
    final generalClasses = classes.where((c) => !c.isActive).toList();

    return AcademyLoadingOverlay(
      isLoading: isLoading,
      message: context.l10n.loading,
      child: Scaffold(
        backgroundColor: surfaceWhite,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= بنر کلاس‌ها =================
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: primaryPink.withValues(alpha: 0.08), blurRadius: 25, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.podcasts_rounded, color: primaryPink, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.liveCampus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          const SizedBox(height: 3),
                          Text(context.l10n.joinLiveMeetingRoom, style: const TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudentGroupsScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, color: primaryPink, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.safiCommunity,
                              style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // پخش زنده
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text("${context.l10n.live} (${liveSessions.length})", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),

              liveSessions.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: liveSessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final room = liveSessions[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => StudentClassDetailScreen(classData: room.rawData, isPaid: room.isPaid)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: room.isPaid ? primaryPink.withValues(alpha: 0.3) : cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    room.isPaid
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                                            child: Text(context.l10n.live, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5)),
                                            child: Text(context.l10n.pending, style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                          ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGrey),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(room.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text("${context.l10n.instructor}: ${room.teacher != null ? '${room.teacher!['first_name']} ${room.teacher!['last_name']}' : 'Faculty Member'}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text("${context.l10n.schedule}: ${room.scheduleInfo}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: Text(context.l10n.noClassesToday, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 28),

              // کلاس‌های برنامه‌ریزی‌شده
              Text(context.l10n.upcomingClasses, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 12),

              generalClasses.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: generalClasses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final room = generalClasses[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => StudentClassDetailScreen(classData: room.rawData, isPaid: room.isPaid)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    room.isPaid
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                            child: Text(context.l10n.schedule, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900)),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5)),
                                            child: Text(context.l10n.pending, style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                          ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGrey),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(room.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text("${context.l10n.instructor}: ${room.teacher != null ? '${room.teacher!['first_name']} ${room.teacher!['last_name']}' : 'Faculty Member'}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text("${context.l10n.schedule}: ${room.scheduleInfo}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: Text(context.l10n.noActiveClasses, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ویجت کاستوم لودینگ آکادمی
// ============================================================================

class AcademyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AcademyLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = "LOADING...",
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withValues(alpha: 0.95),
            alignment: Alignment.center,
            child: _AcademyThinkingLoadingAnimation(message: message),
          ),
      ],
    );
  }
}

class _AcademyThinkingLoadingAnimation extends StatefulWidget {
  final String message;
  const _AcademyThinkingLoadingAnimation({required this.message});

  @override
  State<_AcademyThinkingLoadingAnimation> createState() => _AcademyThinkingLoadingAnimationState();
}

class _AcademyThinkingLoadingAnimationState extends State<_AcademyThinkingLoadingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      const Color(0xFFF494AC).withValues(alpha: 0.0),
                      const Color(0xFFF494AC).withValues(alpha: 0.8),
                      const Color(0xFFF494AC),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF4F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF494AC).withValues(alpha: 0.25), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.girl_rounded,
                    size: 54,
                    color: Color(0xFFF494AC),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: Color(0xFFF494AC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          widget.message,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}