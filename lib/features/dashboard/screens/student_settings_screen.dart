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

      if (profileData != null) {
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
      }
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

      final fileExt = image.name.split('.').pop();
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Avatar upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload avatar."), backgroundColor: Colors.redAccent),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account details saved successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Profile update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Database error. Failed to save details."), backgroundColor: Colors.redAccent),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your password has been secured!"), backgroundColor: Colors.green),
      );
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      debugPrint("Password update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update password: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("⚙️", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Account Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text("Customize your identity, secure your data, and manage preferences.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= تب‌های عمودی منوی تنظیمات =================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildMenuTab("profile", "Personal Info", "👤"),
                const SizedBox(width: 8),
                _buildMenuTab("security", "Security", "🔒"),
                const SizedBox(width: 8),
                _buildMenuTab("preferences", "Preferences", "⚙️"),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= محتوای تب‌ها =================
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: activeTab == "profile"
                      ? _buildProfileTab()
                      : activeTab == "security"
                          ? _buildSecurityTab()
                          : _buildPreferencesTab(),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMenuTab(String id, String label, String emoji) {
    bool isSelected = activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
        const Text("Personal Identity", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 14),

        // بخش عکس پروفایل
        Center(
          child: GestureDetector(
            onTap: _handleAvatarUpload,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.amber.withOpacity(0.2),
                  backgroundImage: profile['avatar_url'] != null && profile['avatar_url'].isNotEmpty
                      ? NetworkImage(profile['avatar_url'])
                      : null,
                  child: profile['avatar_url'] == null || profile['avatar_url'].isEmpty
                      ? Text(profile['first_name'].isNotEmpty ? profile['first_name'][0] : "U", style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildTextField("First Name", profile['first_name'], (val) => profile['first_name'] = val),
        const SizedBox(height: 10),
        _buildTextField("Last Name", profile['last_name'], (val) => profile['last_name'] = val),
        const SizedBox(height: 10),
        _buildTextField("Father's Name", profile['father_name'], (val) => profile['father_name'] = val),
        const SizedBox(height: 10),
        _buildTextField("Date of Birth", profile['date_of_birth'], (val) => profile['date_of_birth'] = val),
        const SizedBox(height: 10),
        _buildTextField("Email Address", profile['email'], (_) {}, enabled: false),
        const SizedBox(height: 10),
        _buildTextField("Phone Number", profile['phone_number'], (val) => profile['phone_number'] = val),
        const SizedBox(height: 10),
        _buildTextField("Country / Region", profile['country'], (val) => profile['country'] = val),
        const SizedBox(height: 10),
        _buildTextField("Bio / Headline", profile['bio'], (val) => profile['bio'] = val, maxLines: 3),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isSaving ? null : _handleSaveProfile,
            child: Text(isSaving ? "Saving..." : "Save Profile Details", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
        const Text("Vault Security", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        Text("Update your password to keep your data heavily secured.", style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
        const SizedBox(height: 16),

        _buildPasswordField("New Secure Password", _newPasswordController),
        const SizedBox(height: 10),
        _buildPasswordField("Confirm Password", _confirmPasswordController),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isSaving ? null : _handleUpdatePassword,
            child: Text(isSaving ? "Updating..." : "Update Vault Password", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
        const Text("Notification Center", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        Text("Manage how the Academy communicates with you.", style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
        const SizedBox(height: 16),

        SwitchListTile(
          title: const Text("Academy Updates & Emails", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          subtitle: Text("Receive instant alerts about your live classes and grades.", style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
          value: academyUpdates,
          activeColor: Colors.amber,
          onChanged: (val) => setState(() => academyUpdates = val),
        ),
        const Divider(color: Colors.white10),
        SwitchListTile(
          title: const Text("Marketing & Exclusive Offers", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          subtitle: Text("Get notified about new courses and discounts.", style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
          value: marketingOffers,
          activeColor: Colors.amber,
          onChanged: (val) => setState(() => marketingOffers = val),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged, {bool enabled = true, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: InputDecoration(
            hintText: "••••••••",
            hintStyle: TextStyle(color: Colors.grey.shade700),
            filled: true,
            fillColor: Colors.black.withOpacity(0.4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
        ),
      ],
    );
  }
}

extension on List<String> {
  Object? pop() {}
}