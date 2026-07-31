import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherSettingsScreen extends StatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  State<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends State<TeacherSettingsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSavingProfile = false;
  bool isSavingPassword = false;

  String? messageText;
  bool isSuccessMessage = true;

  // فیلدهای فرم پروفایل
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();
  String email = "";
  String userId = "";

  // فرم تغییر رمز عبور
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _avatarController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      userId = user.id;

      final data = await supabase
          .from("profiles")
          .select("*")
          .eq("id", userId)
          .maybeSingle();

      if (data != null) {
        _firstNameController.text = data['first_name'] ?? '';
        _lastNameController.text = data['last_name'] ?? '';
        email = data['email'] ?? user.email ?? '';
        _phoneController.text = data['phone_number'] ?? '';
        _countryController.text = data['country'] ?? '';
        _dobController.text = data['date_of_birth'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _avatarController.text = data['avatar_url'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleUpdateProfile() async {
    setState(() => isSavingProfile = true);
    try {
      await supabase.from("profiles").update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'country': _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        'date_of_birth': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'avatar_url': _avatarController.text.trim().isEmpty ? null : _avatarController.text.trim(),
      }).eq("id", userId);

      _showMessage("Profile updated successfully!", true);
    } catch (e) {
      _showMessage("Failed to update profile: $e", false);
    } finally {
      if (mounted) setState(() => isSavingProfile = false);
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      _showMessage("Passwords do not match.", false);
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

      _showMessage("Security credentials updated successfully!", true);
      _newPassController.clear();
      _confirmPassController.clear();
    } catch (e) {
      _showMessage("Failed to update password: $e", false);
    } finally {
      if (mounted) setState(() => isSavingPassword = false);
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
    }

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
                    color: Colors.pink.withOpacity(0.15),
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
                      Text("Manage your academic profile and security credentials.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
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
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isSuccessMessage ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSuccessMessage ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(isSuccessMessage ? Icons.check_circle : Icons.error, color: isSuccessMessage ? Colors.greenAccent : Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(messageText!, style: TextStyle(color: isSuccessMessage ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

          // ================= ۱. فرم پروفایل عمومی =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f).withOpacity(0.8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Public Profile Data", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("First Name", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _firstNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Last Name", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _lastNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text("Phone Number", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 12),

                const Text("Country / Region", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _countryController,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 12),

                const Text("Avatar Image URL", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _avatarController,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "https://...",
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 12),

                const Text("Professional Biography", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Write a short bio...",
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSavingProfile ? null : _handleUpdateProfile,
                    child: Text(isSavingProfile ? "Saving..." : "Save Profile Updates 💾", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= ۲. فرم امنیت و تغییر رمز عبور =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f).withOpacity(0.8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Security & Authentication", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 14),

                const Text("New Password", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _newPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 12),

                const Text("Confirm New Password", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _confirmPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.pink.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSavingPassword ? null : _handleUpdatePassword,
                    child: Text(isSavingPassword ? "Updating..." : "Update Password 🔒", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}