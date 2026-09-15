import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/widgets/language_selector_sheet.dart';
import '../../auth/screens/activity_log_screen.dart';

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
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  bool _pinLockEnabled = false;
  String _userPin = "";

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
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
          _userPin = res['pin_code']?.toString() ?? '';
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

  // به‌روزرسانی تنظیمات امنیتی در دیتابیس (اصلاح خطای سینتکس)
  Future<void> _saveSecuritySettingsToDb({String? pin, bool? biometric}) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final updateData = {
        'student_id': user.id,
        'pin_code': pin ?? _userPin,
        'is_biometric_enabled': biometric ?? _biometricEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('student_security_settings').upsert(updateData);
    } catch (e) {
      debugPrint("Error saving security settings: $e");
    }
  }

  // تغییر رمز عبور
  Future<void> _changePassword() async {
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.passwordMinLength),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );
      _newPasswordController.clear();
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.passwordChangedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error changing password: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // احراز هویت بیومتریک (اثر انگشت / تشخیص چهره) با اتصال اجباری پین
  Future<void> _toggleBiometric(bool value) async {
    try {
      if (value) {
        final String? existingPin = await SecurityService.instance.getPinCode();
        if (existingPin == null || existingPin.length != 4) {
          if (!mounted) return;
          _showSetPinDialog(andEnableBiometric: true);
          return;
        }

        bool canAuthenticate = await SecurityService.instance
            .canCheckBiometrics();
        if (canAuthenticate) {
          bool authenticated = await SecurityService.instance
              .authenticateBiometric(
                reason: 'Authenticate to enable biometric security',
              );
          if (authenticated) {
            setState(() {
              _biometricEnabled = true;
              _pinLockEnabled = true;
            });
            await SecurityService.instance.saveSecuritySettings(
              enabled: true,
              pin: existingPin,
            );
            await _saveSecuritySettingsToDb(biometric: true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.biometricLoginEnabled),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          if (!mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.biometricsNotSupported),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        setState(() => _biometricEnabled = false);
        await SecurityService.instance.disableSecurity();
        await _saveSecuritySettingsToDb(biometric: false);
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    }
  }

  // تنظیم پین‌کد امنیتی با دیزاین حرفه‌ای
  void _showSetPinDialog({bool andEnableBiometric = false}) {
    TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.dialpad_rounded, color: primaryPink, size: 40),
            const SizedBox(height: 12),
            Text(
              context.l10n.pinLock,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: textDark,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          obscuringCharacter: '⬤',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 16,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          decoration: InputDecoration(
            hintText: "••••",
            hintStyle: const TextStyle(color: textGrey, letterSpacing: 16),
            filled: true,
            fillColor: cardBorder,
            counterText: "",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryPink, width: 2),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(
                () => _pinLockEnabled = false,
              ); // برگشت به حالت خاموش در صورت انصراف
            },
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(
                color: textGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              if (pinController.text.length == 4) {
                setState(() {
                  _userPin = pinController.text;
                  _pinLockEnabled = true;
                  if (andEnableBiometric) _biometricEnabled = true;
                });
                await SecurityService.instance.saveSecuritySettings(
                  enabled: andEnableBiometric || _biometricEnabled,
                  pin: _userPin,
                );
                await _saveSecuritySettingsToDb(
                  pin: _userPin,
                  biometric: andEnableBiometric ? true : null,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.pinSavedSuccess),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.pinMustBe4Digits),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(
              context.l10n.savePin,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: CircularProgressIndicator(color: primaryPink, strokeWidth: 3),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFF0F5).withOpacity(0.5), surfaceWhite],
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
                          colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: primaryPink.withOpacity(0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPink.withOpacity(0.06),
                            blurRadius: 25,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: primaryPink.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: primaryPink,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.appSettings,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.preferencesAndLanguage,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: textGrey,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ================= ۱. بخش تغییر رمز عبور =================
                    Text(
                      context.l10n.accountSecurity,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            context.l10n.newPassword,
                            context.l10n.enterStrongPassword,
                            _newPasswordController,
                            obscureText: true,
                            icon: Icons.lock_outline_rounded,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: isSaving ? null : _changePassword,
                              child: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      context.l10n.updatePassword,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ================= ۲. بخش قفل‌های بیومتریک و پین =================
                    Text(
                      context.l10n.appLockAndPrivacy,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // بیومتریک
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: lightPinkBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.fingerprint_rounded,
                                      color: primaryPink,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.biometricAuth,
                                        style: const TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        context.l10n.biometricAuthDesc,
                                        style: const TextStyle(
                                          color: textGrey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _biometricEnabled,
                                activeColor: primaryPink,
                                activeTrackColor: lightPinkBg,
                                onChanged: _toggleBiometric,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: cardBorder, thickness: 1.5),
                          ),
                          // پین‌کد
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardBorder,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.dialpad_rounded,
                                      color: textDark,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.pinLock,
                                        style: const TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _pinLockEnabled
                                            ? context.l10n.active
                                            : context.l10n.pending,
                                        style: TextStyle(
                                          color: _pinLockEnabled
                                              ? Colors.green
                                              : textGrey,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _pinLockEnabled,
                                activeColor: primaryPink,
                                activeTrackColor: lightPinkBg,
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: cardBorder, thickness: 1.5),
                          ),
                          // لاگ فعالیت‌ها
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ActivityLogScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: lightPinkBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.devices_rounded,
                                        color: primaryPink,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n.activityLog,
                                          style: const TextStyle(
                                            color: textDark,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          context.l10n.activeSessions,
                                          style: const TextStyle(
                                            color: textGrey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: textGrey,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ================= ۳. بخش تنظیمات اپلیکیشن =================
                    Text(
                      context.l10n.preferencesAndLanguage,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardBorder,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.language_rounded,
                                      color: textDark,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    context.l10n.language,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              ValueListenableBuilder<Locale>(
                                valueListenable:
                                    LanguageService.instance.localeNotifier,
                                builder: (context, locale, child) {
                                  final currentLang =
                                      LanguageService.instance.currentLanguage;
                                  return InkWell(
                                    onTap: () =>
                                        LanguageSelectorSheet.show(context),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cardBorder.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: cardBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            currentLang.flag,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            currentLang.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textDark,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: textDark,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardBorder,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active_rounded,
                                      color: textDark,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    context.l10n.pushNotifications,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _notificationsEnabled,
                                activeColor: primaryPink,
                                activeTrackColor: lightPinkBg,
                                onChanged: (val) =>
                                    setState(() => _notificationsEnabled = val),
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
                          backgroundColor: Colors.redAccent.withOpacity(0.12),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.3),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          context.l10n.logOut,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 80), // فاصله برای Bottom Nav
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ویجت کمکی برای ساخت تکست‌فیلد
  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    bool obscureText = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textDark,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ), // رنگ متن تیره
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: textGrey, size: 20)
                : null,
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: cardBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryPink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
