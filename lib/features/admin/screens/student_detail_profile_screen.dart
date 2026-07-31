import 'dart:ui';
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

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  final walletCtrl = TextEditingController();
  final scoreCtrl = TextEditingController();

  String selectedRole = 'student';

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
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
          .single();

      if (mounted) {
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
      String fName = firstNameCtrl.text.trim();
      String lName = lastNameCtrl.text.trim();
      String email = emailCtrl.text.trim();
      String phone = phoneCtrl.text.trim();
      String bio = bioCtrl.text.trim();
      double newWallet = double.tryParse(walletCtrl.text.trim()) ?? 0.0;
      int newScore = int.tryParse(scoreCtrl.text.trim()) ?? 0;

      // حذف فیلد updated_at برای جلوگیری از ارور دیتابیس
      final updatedData = await supabase
          .from("profiles")
          .update({
            'first_name': fName,
            'last_name': lName,
            'email': email,
            'phone_number': phone.isNotEmpty ? phone : null,
            'bio': bio.isNotEmpty ? bio : null,
            'wallet_balance': newWallet,
            'total_score': newScore,
            'role': selectedRole,
          })
          .eq("id", widget.studentId)
          .select()
          .single();

      if (mounted) {
        setState(() {
          studentData = updatedData;
          messageText = selectedRole != 'student'
              ? 'Profile updated & successfully promoted to ${selectedRole.toUpperCase()}! 🚀'
              : 'Student profile updated in database successfully!';
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
                    const Text("PROFILE SPECIFICATIONS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isSmall = constraints.maxWidth < 340;
                        if (isSmall) {
                          return Column(
                            children: [
                              _buildLabeledInput("FIRST NAME", firstNameCtrl, "First Name"),
                              const SizedBox(height: 14),
                              _buildLabeledInput("LAST NAME", lastNameCtrl, "Last Name"),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildLabeledInput("FIRST NAME", firstNameCtrl, "First Name")),
                            const SizedBox(width: 12),
                            Expanded(child: _buildLabeledInput("LAST NAME", lastNameCtrl, "Last Name")),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    _buildLabeledInput("EMAIL ADDRESS", emailCtrl, "Email address"),
                    const SizedBox(height: 14),

                    _buildLabeledInput("PHONE NUMBER", phoneCtrl, "Phone number", keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),

                    _buildLabeledInput("BIOGRAPHY", bioCtrl, "Write comprehensive student biography...", maxLines: 4),
                    const SizedBox(height: 14),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isSmall = constraints.maxWidth < 340;
                        if (isSmall) {
                          return Column(
                            children: [
                              _buildLabeledInput("WALLET BALANCE (\$)", walletCtrl, "0.00", keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                              const SizedBox(height: 14),
                              _buildLabeledInput("ACADEMIC SCORE (PTS)", scoreCtrl, "0", keyboardType: TextInputType.number),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildLabeledInput("WALLET BALANCE (\$)", walletCtrl, "0.00", keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildLabeledInput("ACADEMIC SCORE (PTS)", scoreCtrl, "0", keyboardType: TextInputType.number)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    const Text("SYSTEM ROLE & PROMOTION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      dropdownColor: surfaceWhite,
                      isExpanded: true,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _inputFieldDecoration("Select role"),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text("Student (Normal)", overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'teacher', child: Text("Instructor / Mentor", overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'super_admin', child: Text("Administrator", overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedRole = val);
                      },
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
                      : const Text("SAVE CHANGES & UPDATE DATABASE 🚀", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledInput(String label, TextEditingController controller, String hint, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: _inputFieldDecoration(hint),
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
}