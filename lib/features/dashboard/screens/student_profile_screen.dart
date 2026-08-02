import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSaving = false;
  String activeTab = "profile"; // "profile", "security", "preferences"

  // اطلاعات پروفایل
  Map<String, dynamic> profile = {
    'first_name': '',
    'last_name': '',
    'father_name': '',
    'date_of_birth': '',
    'email': '',
    'phone_number': '',
    'country': '',
    'bio': '',
    'avatar_url': '',
  };

  // رمز عبور جدید
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // ترجیحات (Toggleها)
  bool academyUpdates = true;
  bool marketingOffers = false;

  final ImagePicker _picker = ImagePicker();

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
    _fetchUserData();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profileData = await supabase
          .from("profiles")
          .select("*")
          .eq("id", user.id)
          .single();

      setState(() {
        profile = {
          'first_name': profileData['first_name'] ?? '',
          'last_name': profileData['last_name'] ?? '',
          'father_name': profileData['father_name'] ?? '',
          'date_of_birth': profileData['date_of_birth'] ?? '',
          'email': user.email ?? profileData['email'] ?? '',
          'phone_number': profileData['phone_number'] ?? '',
          'country': profileData['country'] ?? '',
          'bio': profileData['bio'] ?? '',
          'avatar_url': profileData['avatar_url'] ?? '',
        };
      });
        } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleAvatarUpload() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => isSaving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = image.name.split('.').last;
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final bytes = await image.readAsBytes();

      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        profile['avatar_url'] = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Avatar upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload avatar."), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _handleSaveProfile() async {
    setState(() => isSaving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({
            'first_name': profile['first_name'],
            'last_name': profile['last_name'],
            'father_name': profile['father_name'],
            'date_of_birth': profile['date_of_birth'].isEmpty ? null : profile['date_of_birth'],
            'phone_number': profile['phone_number'],
            'country': profile['country'],
            'bio': profile['bio'],
          })
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account details saved successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Profile update error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Database error. Failed to save details."), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _handleUpdatePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters."), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPass));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your password has been secured!"), backgroundColor: Colors.green),
        );
      }
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      debugPrint("Password update error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update password: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= هدر صفحه =================
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Account Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                        const SizedBox(height: 3),
                        const Text("Customize your identity, secure your data, and manage preferences.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= تب‌های منوی تنظیمات =================
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildMenuTab("profile", "Personal Info", Icons.person_rounded),
                  const SizedBox(width: 10),
                  _buildMenuTab("security", "Security", Icons.lock_rounded),
                  const SizedBox(width: 10),
                  _buildMenuTab("preferences", "Preferences", Icons.tune_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= محتوای تب‌ها =================
            isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5))
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: activeTab == "profile"
                        ? _buildProfileTab()
                        : activeTab == "security"
                            ? _buildSecurityTab()
                            : _buildPreferencesTab(),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTab(String id, String label, IconData icon) {
    bool isSelected = activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryPink : lightPinkBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryPink : cardBorder, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: primaryPink.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : primaryPink),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : textDark, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  // ================= تب مشخصات فردی =================
  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Personal Identity", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 16),

        // بخش عکس پروفایل
        Center(
          child: GestureDetector(
            onTap: _handleAvatarUpload,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: lightPinkBg,
                  backgroundImage: profile['avatar_url'] != null && profile['avatar_url'].isNotEmpty
                      ? NetworkImage(profile['avatar_url'])
                      : null,
                  child: profile['avatar_url'] == null || profile['avatar_url'].isEmpty
                      ? Text(profile['first_name'].isNotEmpty ? profile['first_name'][0] : "U", style: const TextStyle(color: primaryPink, fontSize: 24, fontWeight: FontWeight.w900))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: primaryPink, shape: BoxShape.circle, border: Border.all(color: surfaceWhite, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildTextField("First Name", profile['first_name'], (val) => profile['first_name'] = val),
        const SizedBox(height: 14),
        _buildTextField("Last Name", profile['last_name'], (val) => profile['last_name'] = val),
        const SizedBox(height: 14),
        _buildTextField("Father's Name", profile['father_name'], (val) => profile['father_name'] = val),
        const SizedBox(height: 14),
        _buildTextField("Date of Birth", profile['date_of_birth'], (val) => profile['date_of_birth'] = val),
        const SizedBox(height: 14),
        _buildTextField("Email Address", profile['email'], (_) {}, enabled: false),
        const SizedBox(height: 14),
        _buildTextField("Phone Number", profile['phone_number'], (val) => profile['phone_number'] = val),
        const SizedBox(height: 14),
        _buildTextField("Country / Region", profile['country'], (val) => profile['country'] = val),
        const SizedBox(height: 14),
        _buildTextField("Bio / Headline", profile['bio'], (val) => profile['bio'] = val, maxLines: 3),
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
            onPressed: isSaving ? null : _handleSaveProfile,
            child: Text(isSaving ? "Saving..." : "Save Profile Details", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  // ================= تب امنیت =================
  Widget _buildSecurityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Vault Security", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        const Text("Update your password to keep your data heavily secured.", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),

        _buildPasswordField("New Secure Password", _newPasswordController),
        const SizedBox(height: 14),
        _buildPasswordField("Confirm Password", _confirmPasswordController),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: lightPinkBg,
              foregroundColor: primaryPink,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: isSaving ? null : _handleUpdatePassword,
            child: Text(isSaving ? "Updating..." : "Update Vault Password", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  // ================= تب ترجیحات =================
  Widget _buildPreferencesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notification Center", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        const Text("Manage how the Academy communicates with you.", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Academy Updates & Emails", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
          subtitle: const Text("Receive instant alerts about your live classes and grades.", style: TextStyle(color: textGrey, fontSize: 10)),
          value: academyUpdates,
          activeThumbColor: primaryPink,
          onChanged: (val) => setState(() => academyUpdates = val),
        ),
        const Divider(color: cardBorder, height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Marketing & Exclusive Offers", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold)),
          subtitle: const Text("Get notified about new courses and discounts.", style: TextStyle(color: textGrey, fontSize: 10)),
          value: marketingOffers,
          activeThumbColor: primaryPink,
          onChanged: (val) => setState(() => marketingOffers = val),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged, {bool enabled = true, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(color: enabled ? textDark : textGrey, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? cardBorder.withOpacity(0.5) : cardBorder.withOpacity(0.2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "••••••••",
            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
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