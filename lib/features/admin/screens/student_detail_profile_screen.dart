import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentDetailProfileScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailProfileScreen({super.key, required this.studentId});

  @override
  State<StudentDetailProfileScreen> createState() => _StudentDetailProfileScreenState();
}

class _StudentDetailProfileScreenState extends State<StudentDetailProfileScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;
  Map<String, dynamic>? studentData;
  String? messageText;
  bool isSuccessMessage = false;

  // فیلدهای اطلاعاتی (قفل‌شده)
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  // فیلدهای قابل ویرایش و مدیریت ادمین (کیف پول، امتیاز و نقش)
  final walletCtrl = TextEditingController();
  final scoreCtrl = TextEditingController();
  String selectedRole = 'student';

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    bioCtrl.dispose();
    walletCtrl.dispose();
    scoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentProfile() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("profiles")
          .select("*")
          .eq("id", widget.studentId)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          studentData = response;
          firstNameCtrl.text = response['first_name'] ?? '';
          lastNameCtrl.text = response['last_name'] ?? '';
          emailCtrl.text = response['email'] ?? '';
          phoneCtrl.text = response['phone_number'] ?? '';
          bioCtrl.text = response['bio'] ?? '';
          
          walletCtrl.text = (response['wallet_balance'] ?? 0).toString();
          scoreCtrl.text = (response['total_score'] ?? 0).toString();

          final r = response['role'] ?? 'student';
          selectedRole = ['student', 'teacher', 'super_admin'].contains(r) ? r : 'student';

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching student profile: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleUpdateProfile() async {
    FocusScope.of(context).unfocus();
    setState(() {
      isSaving = true;
      messageText = null;
    });

    try {
      double newWallet = double.tryParse(walletCtrl.text.trim()) ?? 0.0;
      int newScore = int.tryParse(scoreCtrl.text.trim()) ?? 0;

      // فراخوانی تابع RPC اصلاح شده در دیتابیس
      await supabase.rpc(
        'admin_update_user_profile',
        params: {
          'target_user_id': widget.studentId,
          'new_wallet': newWallet,
          'new_score': newScore,
          'new_role': selectedRole,
        },
      );

      // دریافت اطلاعات جدید برای اطمینان از اعمال تغییرات
      final updatedData = await supabase
          .from("profiles")
          .select("*")
          .eq("id", widget.studentId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (updatedData != null) studentData = updatedData;
          messageText = 'Admin changes successfully synchronized with database! ✅';
          isSuccessMessage = true;
        });
      }

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      debugPrint("Database Update Error: $e");
      if (mounted) {
        setState(() {
          messageText = 'Failed to update database: ${e.toString()}';
          isSuccessMessage = false;
        });
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
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
              Text(
                "LOADING PROFILE...",
                style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    if (studentData == null) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Student Profile Not Found", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
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

    final avatarUrl = studentData!['avatar_url'];

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
                          Icon(Icons.arrow_back_rounded, color: textDark, size: 16),
                          SizedBox(width: 6),
                          Text("Back to Students", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // هدر پروفایل
                  Container(
                    padding: const EdgeInsets.all(20),
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
                          radius: 30,
                          backgroundColor: lightPinkBg,
                          backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                              ? Text(
                                  firstNameCtrl.text.isNotEmpty ? firstNameCtrl.text[0] : 'S',
                                  style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 20),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${firstNameCtrl.text} ${lastNameCtrl.text}",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                emailCtrl.text,
                                style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        )
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
                          Icon(
                            isSuccessMessage ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: isSuccessMessage ? Colors.green.shade700 : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              messageText!,
                              style: TextStyle(color: isSuccessMessage ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // اطلاعات شخصی (قفل‌شده)
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
                        const SizedBox(height: 14),
                        _buildLockedInput("BIOGRAPHY", bioCtrl, maxLines: 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // کنترل‌های ادمین (کیف پول، امتیاز و انتخاب رول با دیزاین لوکس)
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
                            Text("ADMIN CONTROLS & DATABASE SYNC", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2)),
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
                        
                        // منوی کشویی جدید با استایل و آیکون‌های بسیار شیک
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
                                      Text("Student (Normal Access)", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
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
                                      Text("Administrator (Full Access)", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
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
                          : const Text("SYNC CHANGES TO DATABASE 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
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
}