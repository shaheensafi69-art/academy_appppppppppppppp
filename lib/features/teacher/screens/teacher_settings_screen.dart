import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/auth_gate.dart';

class TeacherSettingsScreen extends StatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  State<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends State<TeacherSettingsScreen> {
  final supabase = Supabase.instance.client;
  bool isSavingPassword = false;

  // تنظیمات (Toggles)
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _darkMode = false;

  // فرم تغییر رمز عبور
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  String? messageText;
  bool isSuccessMessage = true;

  // پالت رنگی اختصاصی
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      _showMessage("New passwords do not match.", false);
      return;
    }
    if (_newPassController.text.length < 6) {
      _showMessage("Password must be at least 6 characters.", false);
      return;
    }

    setState(() => isSavingPassword = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPassController.text),
      );

      _showMessage("Password updated successfully! 🔒", true);
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
    } catch (e) {
      _showMessage("Failed to update password: $e", false);
    } finally {
      if (mounted) setState(() => isSavingPassword = false);
    }
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  void _showMessage(String text, bool success) {
    setState(() {
      messageText = text;
      isSuccessMessage = success;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => messageText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= هدر صفحه تنظیمات =================
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPink.withValues(alpha: 0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.settings_rounded, color: primaryPink, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("App Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Configure your app preferences, security, and notifications.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // پیام سیستم (Toast)
              if (messageText != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isSuccessMessage ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSuccessMessage ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(isSuccessMessage ? Icons.check_circle_rounded : Icons.error_rounded, color: isSuccessMessage ? Colors.green.shade700 : Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.green.shade700 : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900))),
                    ],
                  ),
                ),

              // ================= ۱. تنظیمات اعلان‌ها و ترجیحات =================
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, color: primaryPink, size: 20),
                        SizedBox(width: 8),
                        Text("Preferences & Notifications", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      "Push Notifications",
                      "Receive alerts for student assignments and class updates",
                      _pushNotifications,
                      (val) => setState(() => _pushNotifications = val),
                    ),
                    const Divider(height: 24, color: cardBorder),
                    _buildSwitchTile(
                      "Email Alerts",
                      "Get important academy emails and reports",
                      _emailAlerts,
                      (val) => setState(() => _emailAlerts = val),
                    ),
                    const Divider(height: 24, color: cardBorder),
                    _buildSwitchTile(
                      "Dark Appearance (Coming Soon)",
                      "Switch interface to dark mode theme",
                      _darkMode,
                      (val) => setState(() => _darkMode = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ================= ۲. تغییر رمز عبور و امنیت =================
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_reset_rounded, color: primaryPink, size: 20),
                        SizedBox(width: 8),
                        Text("Security & Password", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const Text("New Password", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPassController,
                      obscureText: true,
                      style: const TextStyle(color: textDark, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "At least 6 characters",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        filled: true,
                        fillColor: cardBorder.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text("Confirm New Password", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPassController,
                      obscureText: true,
                      style: const TextStyle(color: textDark, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Re-enter new password",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        filled: true,
                        fillColor: cardBorder.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSavingPassword ? null : _handleUpdatePassword,
                        child: Text(isSavingPassword ? "Updating Password..." : "Update Security Password 🔒", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ================= ۳. خروج از حساب کاربری =================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Sign Out Session", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13)),
                          SizedBox(height: 2),
                          Text("Safely terminate your current faculty session.", style: TextStyle(color: textGrey, fontSize: 10)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _logout,
                      child: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 10)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeColor: primaryPink,
          onChanged: onChanged,
        ),
      ],
    );
  }
}