import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/routing/auth_gate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  final LocalAuthentication auth = LocalAuthentication();

  bool isLoading = true;
  bool isSaving = false;

  // فیلد رمز عبور جدید
  final TextEditingController _newPasswordController = TextEditingController();

  // تنظیمات امنیتی و اپ
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  bool _pinLockEnabled = false;
  String _userPin = "";

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchSecuritySettings();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    super.dispose();
  }

  // دریافت تنظیمات امنیتی دانشجو از جدول student_security_settings
  Future<void> _fetchSecuritySettings() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final res = await supabase
          .from('student_security_settings')
          .select('pin_code, is_biometric_enabled')
          .eq('student_id', user.id)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _userPin = res['pin_code'] ?? '';
          _pinLockEnabled = _userPin.isNotEmpty;
          _biometricEnabled = res['is_biometric_enabled'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching security settings: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // به‌روزرسانی تنظیمات امنیتی در دیتابیس
  Future<void> _saveSecuritySettingsToDb({String? pin, bool? biometric}) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final updateData = {
        'student_id': user.id,
        'pin_code': ?pin,
        'is_biometric_enabled': ?biometric,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('student_security_settings').upsert(updateData);
    } catch (e) {
      debugPrint("Error saving security settings: $e");
    }
  }

  // تغییر رمز عبور امن
  Future<void> _changePassword() async {
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters."), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );
      _newPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password changed successfully! 🔒"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error changing password: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // احراز هویت بیومتریک (اثر انگشت / تشخیص چهره)
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
          if (authenticated) {
            setState(() => _biometricEnabled = true);
            await _saveSecuritySettingsToDb(biometric: true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric login enabled! 🔓"), backgroundColor: Colors.green));
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometrics not supported on this device."), backgroundColor: Colors.red));
          }
        }
      } else {
        setState(() => _biometricEnabled = false);
        await _saveSecuritySettingsToDb(biometric: false);
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    }
  }

  // تنظیم پین‌کد امنیتی (PIN Lock)
  void _showSetPinDialog() {
    TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Set Security PIN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            hintText: "Enter 4-digit PIN",
            filled: true,
            fillColor: cardBorder,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              if (pinController.text.length == 4) {
                setState(() {
                  _userPin = pinController.text;
                  _pinLockEnabled = true;
                });
                await _saveSecuritySettingsToDb(pin: _userPin);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN code successfully saved! 🔑"), backgroundColor: Colors.green));
                }
              }
            },
            child: const Text("Save PIN"),
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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر صفحه
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.settings_rounded, color: primaryPink, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("App Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Manage your app preferences, security, and credentials.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ================= ۱. بخش امنیت و رمز عبور =================
              const Text("Security & Passwords", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildTextField("New Password", _newPasswordController, obscureText: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryPink,
                          side: const BorderSide(color: primaryPink, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _changePassword,
                        child: const Text("UPDATE PASSWORD 🔒", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const Divider(height: 30, color: cardBorder),

                    // تنظیمات بیومتریک (اثر انگشت)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fingerprint_rounded, color: primaryPink, size: 20),
                            SizedBox(width: 10),
                            Text("Biometric Login", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        Switch(
                          value: _biometricEnabled,
                          activeThumbColor: primaryPink,
                          onChanged: _toggleBiometric,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // تنظیمات پین‌کد (PIN Lock)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: primaryPink, size: 20),
                            SizedBox(width: 10),
                            Text("App PIN Lock", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        Switch(
                          value: _pinLockEnabled,
                          activeThumbColor: primaryPink,
                          onChanged: (val) {
                            if (val) {
                              _showSetPinDialog();
                            } else {
                              setState(() {
                                _pinLockEnabled = false;
                                _userPin = "";
                              });
                              _saveSecuritySettingsToDb(pin: "");
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ================= ۲. بخش تنظیمات اپلیکیشن =================
              const Text("App Preferences", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Language", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          underline: const SizedBox(),
                          items: ['English', 'Persian (Dari)', 'Arabic'].map((lang) {
                            return DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLanguage = val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Push Notifications", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                        Switch(
                          value: _notificationsEnabled,
                          activeThumbColor: primaryPink,
                          onChanged: (val) => setState(() => _notificationsEnabled = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // خروج امن
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text("SECURE SIGN OUT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  onPressed: _logout,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }
}