// ignore_for_file: dead_null_aware_expression

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';

class TeacherStudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const TeacherStudentDetailScreen({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState extends State<TeacherStudentDetailScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isUpdatingScore = false;
  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> enrolledClasses = [];
  List<Map<String, dynamic>> submissions = [];
  List<Map<String, dynamic>> attendanceRecords = [];

  late TabController _tabController;
  final TextEditingController _pointsCtrl = TextEditingController();

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchCompleteStudentDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCompleteStudentDetails() async {
    setState(() => isLoading = true);
    try {
      // 1. واکشی پروفایل کامل دانشجو
      final prof = await supabase
          .from("profiles")
          .select("*")
          .eq("id", widget.studentId)
          .maybeSingle();

      // 2. واکشی کلاس‌های ثبت‌نام شده دانشجو
      final classesRes = await supabase
          .from("class_students")
          .select(
            "id, joined_at, is_paid, class_groups(id, class_name, schedule_info, is_active, course:courses(title))",
          )
          .eq("student_id", widget.studentId);

      // 3. واکشی سوابق تکالیف ارسال‌شده
      final subsRes = await supabase
          .from("assignment_submissions")
          .select(
            "id, created_at, grade, feedback, file_url, assignments(id, title, course:courses(title))",
          )
          .eq("student_id", widget.studentId)
          .order("created_at", ascending: false);

      // 4. واکشی سوابق حضور و غیاب
      final attRes = await supabase
          .from("attendance_logs")
          .select(
            "id, session_date, status, created_at, class_groups(class_name)",
          )
          .eq("student_id", widget.studentId)
          .order("session_date", ascending: false)
          .limit(20);

      setState(() {
        profileData = prof;
        enrolledClasses = List<Map<String, dynamic>>.from(classesRes ?? []);
        submissions = List<Map<String, dynamic>>.from(subsRes ?? []);
        // ignore: dead_null_aware_expression
        attendanceRecords = List<Map<String, dynamic>>.from(attRes ?? []);
      });
    } catch (e) {
      debugPrint("Error loading student details for teacher: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _awardBonusPoints() async {
    final ptsText = _pointsCtrl.text.trim();
    if (ptsText.isEmpty) return;
    final int? pts = int.tryParse(ptsText);
    if (pts == null) return;

    setState(() => isUpdatingScore = true);
    try {
      final currentScore = (profileData?['total_score'] ?? 0) as int;
      final newScore = currentScore + pts;

      await supabase
          .from("profiles")
          .update({'total_score': newScore})
          .eq("id", widget.studentId);

      setState(() {
        profileData?['total_score'] = newScore;
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.savedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUpdatingScore = false);
    }
  }

  void _showAwardPointsDialog() {
    _pointsCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorder, width: 1.5),
        ),
        title: Text(
          context.l10n.academicScore,
          style: const TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${context.l10n.academicScore}: ${profileData?['total_score'] ?? 0} Pts",
              style: const TextStyle(color: textGrey, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "+10, +50...",
                hintStyle: const TextStyle(color: textGrey, fontSize: 12),
                filled: true,
                fillColor: lightPinkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryPink, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(color: textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isUpdatingScore ? null : _awardBonusPoints,
            child: Text(
              context.l10n.save,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fName = profileData?['first_name'] ?? widget.studentName ?? '';
    final lName = profileData?['last_name'] ?? '';
    final fullName = "$fName $lName".trim().isNotEmpty
        ? "$fName $lName".trim()
        : context.l10n.studentName;
    final email = profileData?['email'] ?? '';
    final avatarUrl = profileData?['avatar_url'];
    final score = profileData?['total_score'] ?? 0;
    final wallet = (profileData?['wallet_balance'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          fullName,
          style: const TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.amber),
            tooltip: context.l10n.academicScore,
            onPressed: _showAwardPointsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textGrey),
            onPressed: _fetchCompleteStudentDetails,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryPink,
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                // ================= کارت هویت دانشجو =================
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        surfaceWhite,
                        lightPinkBg.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: primaryPink.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPink.withValues(alpha: 0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: lightPinkBg,
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                fName.isNotEmpty ? fName[0] : 'S',
                                style: const TextStyle(
                                  color: primaryPink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        "$score Pts",
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "\$${wallet.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= نوار تب‌ها =================
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lightPinkBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: primaryPink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: textGrey,
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    tabs: [
                      Tab(text: context.l10n.personalInfo),
                      Tab(text: context.l10n.classes),
                      Tab(text: context.l10n.assignments),
                      Tab(text: context.l10n.liveCampus),
                    ],
                  ),
                ),

                // ================= محتوای تب‌ها =================
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // تب ۱: مشخصات فردی
                      _buildPersonalInfoTab(),
                      // تب ۲: کلاس‌ها و دوره‌ها
                      _buildClassesTab(),
                      // تب ۳: تکالیف ارسال‌شده
                      _buildSubmissionsTab(),
                      // تب ۴: سوابق حضور و غیاب
                      _buildAttendanceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildInfoCard(
          children: [
            _buildDetailRow(
              context.l10n.fatherName,
              profileData?['father_name'] ?? '—',
            ),
            _buildDetailRow(
              context.l10n.dateOfBirth,
              profileData?['date_of_birth'] ?? '—',
            ),
            _buildDetailRow(
              context.l10n.phoneNumber,
              profileData?['phone_number'] ?? '—',
            ),
            _buildDetailRow(
              context.l10n.country,
              profileData?['country'] ?? '—',
            ),
            _buildDetailRow(
              context.l10n.walletBalance,
              "\$${(profileData?['wallet_balance'] ?? 0).toStringAsFixed(2)}",
            ),
            _buildDetailRow(
              context.l10n.academicScore,
              "${profileData?['total_score'] ?? 0} Pts",
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.bio,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightPinkBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (profileData?['bio'] != null &&
                        profileData!['bio'].toString().isNotEmpty)
                    ? profileData!['bio'].toString()
                    : context.l10n.noDescription,
                style: const TextStyle(
                  color: textGrey,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClassesTab() {
    if (enrolledClasses.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noAssignedClasses,
          style: const TextStyle(
            color: textGrey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: enrolledClasses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = enrolledClasses[index];
        final cls = item['class_groups'] as Map<String, dynamic>?;
        final clsName = cls?['class_name'] ?? 'Class';
        final schedule = cls?['schedule_info'] ?? '';
        final courseTitle = (cls?['course'] is Map)
            ? cls!['course']['title']
            : 'General Course';
        final isPaid = item['is_paid'] == true;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightPinkBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clsName,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${context.l10n.course}: $courseTitle",
                      style: const TextStyle(color: textGrey, fontSize: 10),
                    ),
                    if (schedule.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        schedule,
                        style: const TextStyle(
                          color: primaryPink,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPaid ? context.l10n.active : context.l10n.pending,
                  style: TextStyle(
                    color: isPaid ? Colors.green : Colors.amber.shade800,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmissionsTab() {
    if (submissions.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noSubmissionsFound,
          style: const TextStyle(
            color: textGrey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: submissions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sub = submissions[index];
        final asg = sub['assignments'] as Map<String, dynamic>?;
        final title = asg?['title'] ?? context.l10n.assignments;
        final grade = sub['grade'];
        final feedback = sub['feedback'] ?? '';
        final date = (sub['created_at'] ?? '').toString().split('T')[0];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: grade != null
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      grade != null ? "$grade / 100" : context.l10n.pending,
                      style: TextStyle(
                        color: grade != null ? Colors.green : Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "${context.l10n.dateTime}: $date",
                style: const TextStyle(color: textGrey, fontSize: 9),
              ),
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightPinkBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${context.l10n.feedback}: $feedback",
                    style: const TextStyle(color: textDark, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    if (attendanceRecords.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noDataFound,
          style: const TextStyle(
            color: textGrey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: attendanceRecords.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final att = attendanceRecords[index];
        final cls = att['class_groups'] as Map<String, dynamic>?;
        final clsName = cls?['class_name'] ?? 'Class';
        final status = att['status'] ?? 'present';
        final date = att['session_date'] ?? '';

        Color badgeColor = Colors.green;
        if (status == 'absent') badgeColor = Colors.redAccent;
        if (status == 'late') badgeColor = Colors.orange;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clsName,
                    style: const TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(color: textGrey, fontSize: 10),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
