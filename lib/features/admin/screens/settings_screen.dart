import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/localization/l10n_extensions.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/widgets/language_selector_sheet.dart';
import '../../../core/widgets/circular_country_flag.dart';
import '../../auth/screens/activity_log_screen.dart';
import '../../auth/screens/delete_account_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final supabase = Supabase.instance.client;
  final LocalAuthentication auth = LocalAuthentication();

  bool isLoading = true;
  bool isSaving = false;
  bool isLoggingOut = false;

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final avatarCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();

  String role = "super_admin";
  String userId = "";

  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    avatarCtrl.dispose();
    bioCtrl.dispose();
    newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _logout();
        return;
      }
      userId = user.id;

      // بارگذاری پروفایل ادمین
      final profile = await supabase
          .from("profiles")
          .select("*")
          .eq("id", userId)
          .maybeSingle();

      if (profile != null) {
        firstNameCtrl.text = profile['first_name'] ?? "";
        lastNameCtrl.text = profile['last_name'] ?? "";
        emailCtrl.text = profile['email'] ?? "";
        phoneCtrl.text = profile['phone_number'] ?? "";
        avatarCtrl.text = profile['avatar_url'] ?? "";
        bioCtrl.text = profile['bio'] ?? "";
        role = profile['role'] ?? "super_admin";
      }

      // بارگذاری تنظیمات امنیتی
      _biometricEnabled = await SecurityService.instance.isAppLockEnabled();
    } catch (e) {
      debugPrint("Error loading admin settings: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= تغییر رمز عبور =================
  Future<void> _changePassword() async {
    if (newPasswordCtrl.text.trim().length < 6) {
      if (!mounted) return;
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
        UserAttributes(password: newPasswordCtrl.text.trim()),
      );
      if (!mounted) return;
      newPasswordCtrl.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.passwordChangedSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${context.l10n.errorChangingPassword}: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ================= احراز هویت و تنظیم قفل بیومتریک و پین =================
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // اگر بیومتریک فعال می‌شود، کاربر ملزم به تنظیم یک پین ۴ رقمی است
      final String? existingPin = await SecurityService.instance.getPinCode();
      if (existingPin == null || existingPin.length != 4) {
        if (!mounted) return;
        _showPinSetupDialog();
        return;
      }

      final canAuth = await SecurityService.instance.canCheckBiometrics();
      if (canAuth) {
        final authenticated = await SecurityService.instance
            .authenticateBiometric(
              reason: 'Authenticate to enable biometric app lock for Admin',
            );
        if (authenticated && mounted) {
          await SecurityService.instance.saveSecuritySettings(
            enabled: true,
            pin: existingPin,
          );
          setState(() => _biometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.biometricLoginEnabled),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.biometricsNotSupported),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      await SecurityService.instance.disableSecurity();
      setState(() => _biometricEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("App Lock Disabled / قفل برنامه غیرفعال شد"),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  // ================= دیالوگ تنظیم پین‌کد برای اولین بار =================
  void _showPinSetupDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.l10n.setAppPinLock,
          style: const TextStyle(
            color: textDark,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.enter4DigitPin,
              style: const TextStyle(
                color: textGrey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              cursorColor: primaryPink,
              decoration: InputDecoration(
                hintText: "••••",
                counterText: "",
                filled: true,
                fillColor: lightPinkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length == 4 && int.tryParse(pin) != null) {
                Navigator.pop(ctx);
                await SecurityService.instance.saveSecuritySettings(
                  enabled: true,
                  pin: pin,
                );
                setState(() => _biometricEnabled = true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.biometricLoginEnabled),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.enter4DigitPin),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(
              context.l10n.save,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  // ================= دیالوگ ویرایش مشخصات ادمین =================
  void _showEditProfileDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cardBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.editProfile,
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(context.l10n.firstName, firstNameCtrl),
                const SizedBox(height: 10),
                _buildField(context.l10n.lastName, lastNameCtrl),
                const SizedBox(height: 10),
                _buildField(
                  context.l10n.phoneNumber,
                  phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _buildField(context.l10n.bio, bioCtrl, maxLines: 2),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              await supabase
                                  .from("profiles")
                                  .update({
                                    "first_name": firstNameCtrl.text.trim(),
                                    "last_name": lastNameCtrl.text.trim(),
                                    "phone_number": phoneCtrl.text.trim(),
                                    "bio": bioCtrl.text.trim(),
                                    "updated_at": DateTime.now()
                                        .toIso8601String(),
                                  })
                                  .eq("id", userId);

                              if (mounted) {
                                Navigator.pop(ctx);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.profileUpdated),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text("Error updating profile: $e"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            } finally {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            context.l10n.saveChanges,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: lightPinkBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ================= خروج از حساب =================
  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.l10n.logout,
          style: const TextStyle(fontWeight: FontWeight.w900, color: textDark),
        ),
        content: Text(
          context.l10n.confirmLogout,
          style: const TextStyle(color: textGrey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.logout,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoggingOut = true);
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Logout error: $e");
    } finally {
      if (mounted) setState(() => isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = LanguageService.instance.currentLanguage;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= ۱. هدر پروفایل ادمین =================
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          surfaceWhite,
                          lightPinkBg.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: primaryPink.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
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
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: lightPinkBg,
                          backgroundImage: avatarCtrl.text.isNotEmpty
                              ? NetworkImage(avatarCtrl.text)
                              : null,
                          child: avatarCtrl.text.isEmpty
                              ? const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 36,
                                  color: primaryPink,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${firstNameCtrl.text} ${lastNameCtrl.text}"
                                        .trim()
                                        .isEmpty
                                    ? "Administrator"
                                    : "${firstNameCtrl.text} ${lastNameCtrl.text}",
                                style: const TextStyle(
                                  color: textDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                emailCtrl.text,
                                style: const TextStyle(
                                  color: textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryPink,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  role.toUpperCase().replaceAll('_', ' '),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: primaryPink,
                          ),
                          tooltip: context.l10n.editProfile,
                          onPressed: _showEditProfileDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ================= ۲. بخش زبان برنامه (Language Selection) =================
                  _buildSectionHeader(context.l10n.appPreferences),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.translate_rounded,
                          color: primaryPink,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        context.l10n.language,
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          CircularCountryFlag(
                            countryCode: currentLang.countryCode,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentLang.name,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: textGrey,
                        size: 14,
                      ),
                      onTap: () {
                        LanguageSelectorSheet.show(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ================= ۳. امنیت و لاگ فعالیت‌ها =================
                  _buildSectionHeader(context.l10n.appLockAndPrivacy),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.fingerprint_rounded,
                              color: primaryPink,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            context.l10n.biometricAuth,
                            style: const TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.biometricAuthDesc,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 11,
                            ),
                          ),
                          value: _biometricEnabled,
                          activeThumbColor: primaryPink,
                          activeTrackColor: lightPinkBg,
                          onChanged: _toggleBiometric,
                        ),
                        const Divider(height: 1, color: cardBorder, indent: 64),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.devices_rounded,
                              color: primaryPink,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            context.l10n.activityLog,
                            style: const TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.activeSessions,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: textGrey,
                            size: 14,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ActivityLogScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: cardBorder, indent: 64),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: primaryPink,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            context.l10n.pushNotifications,
                            style: const TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.notifications,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 11,
                            ),
                          ),
                          value: _notificationsEnabled,
                          activeThumbColor: primaryPink,
                          activeTrackColor: lightPinkBg,
                          onChanged: (val) =>
                              setState(() => _notificationsEnabled = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ================= ۴. تغییر رمز عبور =================
                  _buildSectionHeader(context.l10n.changePassword),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: newPasswordCtrl,
                          obscureText: true,
                          cursorColor: primaryPink,
                          decoration: InputDecoration(
                            hintText: context.l10n.newPassword,
                            hintStyle: const TextStyle(
                              color: textGrey,
                              fontSize: 12,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: textGrey,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: lightPinkBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isSaving ? null : _changePassword,
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    context.l10n.updatePassword,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ================= ۵. دکمه خروج =================
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: isLoggingOut ? null : _logout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      label: isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              context.l10n.logout,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent.withValues(alpha: 0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(
                        context.l10n.deleteAccount,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: textDark,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}
