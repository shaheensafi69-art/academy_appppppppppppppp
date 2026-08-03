import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherDetailScreen extends StatefulWidget {
  final String teacherId;
  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;
  Map<String, dynamic>? teacher;
  Map<String, dynamic>? teacherInfo;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> teacherCourses = [];
  List<Map<String, dynamic>> payouts = [];
  int totalStudents = 0;

  // Controllers برای اطلاعات شخصی (قفل‌شده)
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // Controllers برای اطلاعات قابل ویرایش ادمین
  final walletCtrl = TextEditingController();
  final scoreCtrl = TextEditingController();
  String selectedRole = 'teacher';

  // Controllers برای اطلاعات تکمیلی (teacher_info)
  final infoBioCtrl = TextEditingController();
  final achievementsCtrl = TextEditingController();

  // مودال تسویه حساب
  bool isPayoutModalOpen = false;
  double payoutAmount = 0;
  bool isProcessingPayout = false;
  String? messageText;
  bool isSuccessMessage = false;

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
    _fetchTeacherFullData();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    walletCtrl.dispose();
    scoreCtrl.dispose();
    infoBioCtrl.dispose();
    achievementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTeacherFullData() async {
    setState(() => isLoading = true);
    try {
      final profileData = await supabase
          .from("profiles")
          .select("*")
          .eq("id", widget.teacherId)
          .single();

      Map<String, dynamic>? infoData;
      try {
        infoData = await supabase
            .from("teacher_info")
            .select("*")
            .eq("id", widget.teacherId)
            .maybeSingle();
      } catch (_) {
        infoData = null;
      }

      final classesData = await supabase
          .from("class_groups")
          .select("id, class_name, is_active, course:courses(title), class_students(student_id)")
          .eq("teacher_id", widget.teacherId);

      Set uniqueStudents = {};
      List<Map<String, dynamic>> formattedClasses = [];

      for (var cls in (classesData as List)) {
        if (cls['class_students'] != null) {
          for (var cs in (cls['class_students'] as List)) {
            uniqueStudents.add(cs['student_id']);
          }
        }
        formattedClasses.add({
          'id': cls['id'],
          'class_name': cls['class_name'],
          'is_active': cls['is_active'],
          'students_count': (cls['class_students'] as List?)?.length ?? 0,
          'course_title': cls['course'] != null ? (cls['course'] is List ? cls['course'][0]['title'] : cls['course']['title']) : 'General'
        });
      }

      List<Map<String, dynamic>> assignedCourses = [];
      if (infoData != null) {
        final tCourses = await supabase
            .from("teacher_info_courses")
            .select("course:courses(id, title, category)")
            .eq("teacher_info_id", widget.teacherId);
        
        assignedCourses = (tCourses as List).map((tc) => tc['course'] as Map<String, dynamic>).toList();
      }

      final transactionsData = await supabase
          .from("transactions")
          .select("id, amount, status, created_at")
          .eq("student_id", widget.teacherId)
          .eq("transaction_type", "withdrawal")
          .order("created_at", ascending: false);

      if (mounted) {
        setState(() {
          teacher = profileData;
          teacherInfo = infoData;
          
          firstNameCtrl.text = profileData['first_name'] ?? '';
          lastNameCtrl.text = profileData['last_name'] ?? '';
          emailCtrl.text = profileData['email'] ?? '';
          phoneCtrl.text = profileData['phone_number'] ?? '';
          walletCtrl.text = (profileData['wallet_balance'] ?? 0).toString();
          scoreCtrl.text = (profileData['total_score'] ?? 0).toString();

          infoBioCtrl.text = infoData?['bio'] ?? profileData['bio'] ?? '';
          achievementsCtrl.text = infoData?['achievements'] ?? '';

          final r = profileData['role'] ?? 'teacher';
          selectedRole = ['student', 'teacher', 'super_admin'].contains(r) ? r : 'teacher';

          classes = formattedClasses;
          teacherCourses = assignedCourses;
          totalStudents = uniqueStudents.length;
          payouts = (transactionsData as List?)?.cast<Map<String, dynamic>>() ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching teacher details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleUpdateProfile() async {
    setState(() {
      isSaving = true;
      messageText = null;
    });

    try {
      String fName = firstNameCtrl.text.trim();
      String lName = lastNameCtrl.text.trim();
      String bio = infoBioCtrl.text.trim();
      String achievements = achievementsCtrl.text.trim();
      double newWallet = double.tryParse(walletCtrl.text.trim()) ?? 0.0;
      int newScore = int.tryParse(scoreCtrl.text.trim()) ?? 0;

      await supabase
          .from("profiles")
          .update({
            'wallet_balance': newWallet,
            'total_score': newScore,
            'role': selectedRole,
            'bio': bio.isNotEmpty ? bio : null,
          })
          .eq("id", widget.teacherId);

      await supabase.from("teacher_info").upsert({
        'id': widget.teacherId,
        'first_name': fName,
        'last_name': lName,
        'bio': bio.isNotEmpty ? bio : null,
        'achievements': achievements.isNotEmpty ? achievements : null,
        'date_of_birth': teacherInfo?['date_of_birth'],
        'avatar_url': teacher!['avatar_url'],
      });

      setState(() {
        teacher!['wallet_balance'] = newWallet;
        teacher!['total_score'] = newScore;
        teacher!['role'] = selectedRole;
        teacher!['bio'] = bio;

        messageText = 'Instructor profile & admin controls successfully synchronized! 🚀';
        isSuccessMessage = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      setState(() {
        messageText = 'Failed to update profile: ${e.toString()}';
        isSuccessMessage = false;
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> handleProcessPayout() async {
    if (teacher == null) return;
    double currentBalance = (teacher!['wallet_balance'] ?? 0).toDouble();

    if (payoutAmount <= 0 || payoutAmount > currentBalance) {
      setState(() {
        messageText = 'Invalid payout amount.';
        isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      isProcessingPayout = true;
      messageText = null;
    });

    try {
      double newBalance = currentBalance - payoutAmount;

      await supabase
          .from("profiles")
          .update({'wallet_balance': newBalance})
          .eq("id", widget.teacherId);

      await supabase.from("transactions").insert({
        'student_id': widget.teacherId,
        'amount': -payoutAmount,
        'transaction_type': 'withdrawal',
        'status': 'COMPLETED',
        'reference_id': 'PAYOUT-${DateTime.now().millisecondsSinceEpoch}'
      });

      setState(() {
        teacher!['wallet_balance'] = newBalance;
        walletCtrl.text = newBalance.toString();
        payouts.insert(0, {
          'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
          'amount': -payoutAmount,
          'status': 'COMPLETED',
          'created_at': DateTime.now().toIso8601String(),
        });
        messageText = 'Payout successfully processed!';
        isSuccessMessage = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            isPayoutModalOpen = false;
            messageText = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        messageText = 'Failed to process payout: ${e.toString()}';
        isSuccessMessage = false;
      });
    } finally {
      if (mounted) setState(() => isProcessingPayout = false);
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
              Text("LOADING INSTRUCTOR DATA...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    if (teacher == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              const Text("Instructor Not Found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    double walletBalance = (teacher!['wallet_balance'] ?? 0).toDouble();
    final avatarUrl = teacher!['avatar_url'];

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, color: textDark, size: 14),
                          SizedBox(width: 6),
                          Text("Back to Faculty", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Profile Header Card
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
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: lightPinkBg,
                          backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                              ? Text(firstNameCtrl.text.isNotEmpty ? firstNameCtrl.text[0] : 'T', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 20))
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${firstNameCtrl.text} ${lastNameCtrl.text}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark)),
                              const SizedBox(height: 4),
                              Text(emailCtrl.text, style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Metrics
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat("Assigned Classes", classes.length.toString(), Icons.menu_book_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMiniStat("Total Students", totalStudents.toString(), Icons.group_rounded)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Wallet & Payout Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("WALLET BALANCE & PAYOUTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("\$${walletBalance.toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade700, fontSize: 22, fontWeight: FontWeight.w900)),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: walletBalance > 0 ? () {
                                setState(() {
                                  payoutAmount = walletBalance;
                                  messageText = null;
                                  isPayoutModalOpen = true;
                                });
                              } : null,
                              child: const Text("Process Payout", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (messageText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSuccessMessage ? Colors.green.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSuccessMessage ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(isSuccessMessage ? Icons.check_circle_rounded : Icons.error_rounded, color: isSuccessMessage ? Colors.green.shade700 : Colors.redAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // بخش اول: اطلاعات شخصی (قفل‌شده)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: textGrey, size: 14),
                            SizedBox(width: 6),
                            Text("PERSONAL DETAILS (LOCKED)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildLockedInput("FIRST NAME", firstNameCtrl)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildLockedInput("LAST NAME", lastNameCtrl)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildLockedInput("EMAIL ADDRESS", emailCtrl),
                        const SizedBox(height: 14),
                        _buildLockedInput("PHONE NUMBER", phoneCtrl),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // بخش دوم: کنترل‌های ادمین و اطلاعات تکمیلی قابل ویرایش
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: primaryPink.withOpacity(0.25), width: 1.5),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: primaryPink, size: 16),
                            SizedBox(width: 6),
                            Text("ADMIN CONTROLS & TEACHER INFO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(child: _buildEditableInput("WALLET BALANCE (\$)", walletCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildEditableInput("ACADEMIC SCORE (PTS)", scoreCtrl, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text("SYSTEM ROLE & PROMOTION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        
                        // منوی کشویی لوکس و شیک
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardBorder.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRole,
                              dropdownColor: surfaceWhite,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryPink),
                              items: const [
                                DropdownMenuItem(
                                  value: 'student',
                                  child: Row(
                                    children: [
                                      Icon(Icons.school_rounded, color: Color(0xFF00897B), size: 18),
                                      SizedBox(width: 12),
                                      Text("Student (Demote)", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'teacher',
                                  child: Row(
                                    children: [
                                      Icon(Icons.psychology_rounded, color: Color(0xFF3949AB), size: 18),
                                      SizedBox(width: 12),
                                      Text("Instructor / Mentor", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'super_admin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings_rounded, color: primaryPink, size: 18),
                                      SizedBox(width: 12),
                                      Text("Administrator (Super Admin)", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => selectedRole = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text("BIOGRAPHY (TEACHER INFO)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: infoBioCtrl,
                          maxLines: 4,
                          cursorColor: primaryPink,
                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: _inputFieldDecoration("Write comprehensive faculty biography..."),
                        ),
                        const SizedBox(height: 16),

                        const Text("ACHIEVEMENTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: achievementsCtrl,
                          maxLines: 3,
                          cursorColor: primaryPink,
                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: _inputFieldDecoration("List awards, certifications or achievements..."),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSaving ? null : handleUpdateProfile,
                      child: isSaving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text("SAVE CHANGES & SYNC PROFILE 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Assigned Courses / Specialties Section
                  const Text("SPECIALIZED COURSES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  teacherCourses.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: const Text("No specialized courses linked.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: teacherCourses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final crs = teacherCourses[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder, width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(crs['title'] ?? 'Course', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                    child: Text(crs['category'] ?? 'Tech', style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),

                  // Assigned Classes Section
                  const Text("ASSIGNED COHORTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  classes.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(30),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: const Text("No assigned classes.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: classes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final cls = classes[index];
                            return Container(
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
                                        Text(cls['class_name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text("Course: ${cls['course_title']}", style: const TextStyle(color: textGrey, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                    child: Text("${cls['students_count']} Students", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
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
          ),
        ),
      ),

      // Payout Modal BottomSheet
      bottomSheet: isPayoutModalOpen
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Process Payout: ${firstNameCtrl.text}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                      GestureDetector(
                        onTap: () {
                          if (!isProcessingPayout) setState(() => isPayoutModalOpen = false);
                        },
                        child: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("PAYOUT AMOUNT (USD)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: payoutAmount.toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: payoutAmount.toString().length)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      payoutAmount = double.tryParse(val) ?? 0;
                    },
                    style: TextStyle(color: Colors.green.shade700, fontSize: 18, fontWeight: FontWeight.w900),
                    decoration: _inputFieldDecoration("0.00").copyWith(
                      prefixText: "\$ ",
                      prefixStyle: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isProcessingPayout ? null : handleProcessPayout,
                      child: isProcessingPayout
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text("CONFIRM & SETTLE PAYOUT 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildLockedInput(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          readOnly: true,
          style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withOpacity(0.8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            suffixIcon: const Icon(Icons.lock_rounded, size: 14, color: textGrey),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableInput(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          cursorColor: primaryPink,
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
      filled: true,
      fillColor: cardBorder.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lightPinkBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryPink, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}