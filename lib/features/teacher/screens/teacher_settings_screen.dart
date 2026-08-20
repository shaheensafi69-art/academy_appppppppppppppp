import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/routing/auth_gate.dart';

class TeacherSettingsScreen extends StatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  State<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends State<TeacherSettingsScreen> {
  final supabase = Supabase.instance.client;
  final LocalAuthentication auth = LocalAuthentication();

  bool isSaving = false;
  final TextEditingController _newPasswordController = TextEditingController();

  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  bool _pinLockEnabled = false;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void dispose() {
    _newPasswordController.dispose();
    super.dispose();
  }

  // تغییر رمز عبور
  Future<void> _changePassword() async {
    if (_newPasswordController.text.trim().length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );
      if (!mounted) return;
      _newPasswordController.clear();
      FocusScope.of(context).unfocus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password changed successfully! 🔒"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error changing password: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // احراز هویت بیومتریک
  Future<void> _toggleBiometric(bool value) async {
    try {
      if (value) {
        bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
        bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

        if (canAuthenticate) {
          bool authenticated = await auth.authenticate(
            localizedReason: 'Authenticate to enable biometric security',
            biometricOnly: true,
          );
          if (!mounted) return;
          if (authenticated) {
            setState(() => _biometricEnabled = true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric login enabled! 🔓"), backgroundColor: Colors.green));
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometrics not supported on this device."), backgroundColor: Colors.redAccent));
        }
      } else {
        setState(() => _biometricEnabled = false);
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    }
  }

  // دیالوگ پین‌کد
  void _showSetPinDialog() {
    TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.dialpad_rounded, color: primaryPink, size: 40),
            SizedBox(height: 12),
            Text("Set App PIN Lock", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textDark)),
          ],
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          obscuringCharacter: '⬤',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold, color: textDark),
          decoration: InputDecoration(
            hintText: "••••",
            hintStyle: const TextStyle(color: textGrey, letterSpacing: 16),
            filled: true,
            fillColor: cardBorder,
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 2)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _pinLockEnabled = false);
            },
            child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink, 
              foregroundColor: Colors.white, 
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              if (pinController.text.length == 4) {
                setState(() {
                  _pinLockEnabled = true;
                });
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN code successfully saved! 🔑"), backgroundColor: Colors.green));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN must be 4 digits."), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text("Save PIN", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFF0F5).withValues(alpha: 0.5), surfaceWhite],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= هدر صفحه =================
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                        boxShadow: [BoxShadow(color: primaryPink.withValues(alpha: 0.06), blurRadius: 25, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: const Icon(Icons.settings_rounded, color: primaryPink, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("App Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                                SizedBox(height: 4),
                                Text("Manage your app preferences, security, and credentials.", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ================= ۱. بخش تغییر رمز عبور =================
                    const Text("Account Security", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("New Password", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newPasswordController,
                            cursorColor: primaryPink,
                            obscureText: true,
                            style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: "Enter a strong password (min 6 chars)...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 13),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: textGrey, size: 20),
                              filled: true,
                              fillColor: cardBorder.withValues(alpha: 0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: isSaving ? null : _changePassword,
                              child: isSaving 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("UPDATE PASSWORD 🔒", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ================= ۲. قفل بیومتریک و پین =================
                    const Text("App Lock & Privacy", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.fingerprint_rounded, color: primaryPink, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Biometric Login", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                      Text("Face ID or Touch ID", style: TextStyle(color: textGrey, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _biometricEnabled,
                                activeThumbColor: primaryPink,
                                activeTrackColor: lightPinkBg,
                                onChanged: _toggleBiometric,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: cardBorder, thickness: 1.5),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.dialpad_rounded, color: textDark, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("App PIN Lock", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                      Text(_pinLockEnabled ? "Enabled" : "Disabled", style: TextStyle(color: _pinLockEnabled ? Colors.green : textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _pinLockEnabled,
                                activeThumbColor: primaryPink,
                                activeTrackColor: lightPinkBg,
                                onChanged: (val) {
                                  if (val) {
                                    _showSetPinDialog();
                                  } else {
                                    setState(() {
                                      _pinLockEnabled = false;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ================= ۳. تنظیمات اپلیکیشن =================
                    const Text("App Preferences", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.language_rounded, color: textDark, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text("Language", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                              PopupMenuButton<String>(
                                offset: const Offset(0, 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                color: surfaceWhite,
                                elevation: 10,
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'English',
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("English", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textDark)),
                                        Icon(Icons.check_rounded, color: primaryPink, size: 18),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    enabled: false,
                                    value: 'Persian (Soon)',
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Persian (Dari)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textGrey)),
                                        Text("SOON", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    enabled: false,
                                    value: 'Arabic (Soon)',
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Arabic", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textGrey)),
                                        Text("SOON", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (val) {
                                  if (val == 'English') {
                                    setState(() => _selectedLanguage = val);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cardBorder.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cardBorder, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_selectedLanguage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: primaryPink),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: cardBorder, thickness: 1.5),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.notifications_active_rounded, color: textDark, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text("Push Notifications", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                              Switch.adaptive(
                                value: _notificationsEnabled,
                                activeThumbColor: primaryPink,
                                activeTrackColor: lightPinkBg,
                                onChanged: (val) => setState(() => _notificationsEnabled = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ================= خروج امن =================
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text("SECURE SIGN OUT", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}