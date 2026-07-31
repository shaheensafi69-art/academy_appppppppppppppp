import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/auth_gate.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;
  bool isLoggingOut = false;
  Map<String, String>? message;

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final fatherNameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final avatarCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  String role = "admin";
  int totalScore = 0;
  double walletBalance = 0;
  String referralCode = "";
  String userId = "";

  @override
  void initState() {
    super.initState();
    _fetchAdminProfile();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    fatherNameCtrl.dispose();
    dobCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    countryCtrl.dispose();
    avatarCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminProfile() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _logout();
        return;
      }

      userId = user.id;
      final profile = await supabase
          .from("profiles")
          .select("*")
          .eq("id", userId)
          .single();

      firstNameCtrl.text = profile['first_name'] ?? "";
      lastNameCtrl.text = profile['last_name'] ?? "";
      fatherNameCtrl.text = profile['father_name'] ?? "";
      dobCtrl.text = profile['date_of_birth'] ?? "";
      emailCtrl.text = profile['email'] ?? "";
      phoneCtrl.text = profile['phone_number'] ?? "";
      countryCtrl.text = profile['country'] ?? "";
      avatarCtrl.text = profile['avatar_url'] ?? "";
      bioCtrl.text = profile['bio'] ?? "";

      role = profile['role'] ?? "admin";
      totalScore = profile['total_score'] ?? 0;
      walletBalance = (profile['wallet_balance'] ?? 0).toDouble();
      referralCode = profile['referral_code'] ?? "";
        } catch (e) {
      debugPrint("Error fetching admin profile: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleSaveChanges() async {
    setState(() {
      isSaving = true;
      message = null;
    });

    try {
      await supabase
          .from("profiles")
          .update({
            'first_name': firstNameCtrl.text.trim(),
            'last_name': lastNameCtrl.text.trim(),
            'father_name': fatherNameCtrl.text.trim(),
            'date_of_birth': dobCtrl.text.trim().isNotEmpty ? dobCtrl.text.trim() : null,
            'phone_number': phoneCtrl.text.trim(),
            'country': countryCtrl.text.trim(),
            'bio': bioCtrl.text.trim(),
            'avatar_url': avatarCtrl.text.trim(),
          })
          .eq("id", userId);

      setState(() {
        message = {'type': 'success', 'text': 'System configuration and profile metrics synced successfully!'};
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => message = null);
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed to update configuration: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  Future<void> handleLogoutButton() async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a0f),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: const Text("Secure Logout", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to securely log out of the command center?", style: TextStyle(color: Colors.grey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmLogout != true) return;

    setState(() => isLoggingOut = true);
    await _logout();
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
              const CircularProgressIndicator(color: Colors.indigoAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("SYNCHRONIZING CORE ENGINE...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          // Background Ambience Glow
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.indigoAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.indigoAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "SYSTEM SETTINGS",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.2),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.15),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                              ),
                              icon: isLoggingOut ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)) : const Icon(Icons.logout, size: 14),
                              label: Text(isLoggingOut ? "Logging out..." : "Logout", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                              onPressed: isLoggingOut ? null : handleLogoutButton,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Administrator Profile",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Manage your master admin profile and configure parameters.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message!['type'] == 'success' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: message!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(message!['type'] == 'success' ? Icons.check_circle : Icons.error, color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ================= SECTION 1: IDENTITY =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("IDENTITY CONFIGURATION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.2)),
                        const SizedBox(height: 14),

                        // Avatar
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.black,
                              backgroundImage: avatarCtrl.text.trim().isNotEmpty ? NetworkImage(avatarCtrl.text.trim()) : null,
                              child: avatarCtrl.text.trim().isEmpty ? Text(firstNameCtrl.text.isNotEmpty ? firstNameCtrl.text[0] : 'A', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("AVATAR VECTOR URL", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: avatarCtrl,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                    decoration: InputDecoration(
                                      hintText: "https://...",
                                      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.04),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Colors.indigoAccent, width: 1.5)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Names
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("FIRST NAME *", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: firstNameCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: _inputDeco(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("LAST NAME *", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: lastNameCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: _inputDeco(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Father Name & DOB
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("FATHER'S NAME", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: fatherNameCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: _inputDeco(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("DATE OF BIRTH", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: dobCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: _inputDeco(hint: "YYYY-MM-DD"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= SECTION 2: COMMUNICATIONS & LOCATION =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("COMMUNICATIONS & GEOGRAPHY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.2)),
                        const SizedBox(height: 14),

                        // Email (Read Only)
                        const Text("PRIMARY EMAIL (PROTECTED)", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: emailCtrl,
                          enabled: false,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          decoration: _inputDeco(),
                        ),
                        const SizedBox(height: 12),

                        // Phone & Country
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("PHONE NUMBER", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: phoneCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: _inputDeco(hint: "+44..."),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("COUNTRY NODE", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: countryCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: _inputDeco(hint: "UK"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bio
                        const Text("PROFESSIONAL BIOGRAPHY", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: bioCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: _inputDeco(hint: "Write credentials..."),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= SECTION 3: METRICS & AFFILIATES =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("INTERNAL METRICS & AFFILIATES", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.2)),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(child: _buildInfoBox("Academic Score", "$totalScore Pts", Colors.indigoAccent)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildInfoBox("Wallet Balance", "\$${walletBalance.toStringAsFixed(2)}", Colors.amberAccent)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildInfoBox("Affiliate Code", referralCode.isNotEmpty ? referralCode : "NONE", Colors.purpleAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSaving ? null : handleSaveChanges,
                      child: isSaving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("SAVE CONFIGURATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.indigoAccent, width: 1.5)),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}