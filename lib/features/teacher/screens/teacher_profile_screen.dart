import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String _avatarUrl = '';
  String _email = '';

  final ImagePicker _picker = ImagePicker();

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _fatherNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _bioController.dispose();
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
        _firstNameController.text = profileData['first_name'] ?? '';
        _lastNameController.text = profileData['last_name'] ?? '';
        _fatherNameController.text = profileData['father_name'] ?? '';
        _dobController.text = profileData['date_of_birth'] ?? '';
        _email = user.email ?? profileData['email'] ?? '';
        _phoneController.text = profileData['phone_number'] ?? '';
        _countryController.text = profileData['country'] ?? '';
        _bioController.text = profileData['bio'] ?? '';
        _avatarUrl = profileData['avatar_url'] ?? '';
      });
    } catch (e) {
      debugPrint("Error fetching instructor profile: $e");
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
        _avatarUrl = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated successfully! ✅"), backgroundColor: Colors.green),
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
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'father_name': _fatherNameController.text.trim(),
            'date_of_birth': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
            'phone_number': _phoneController.text.trim(),
            'country': _countryController.text.trim(),
            'bio': _bioController.text.trim(),
          })
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Instructor profile updated successfully! ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Profile update error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Database error. Failed to save profile."), backgroundColor: Colors.redAccent),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= هدر صفحه =================
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: primaryPink.withValues(alpha: 0.08), blurRadius: 25, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: lightPinkBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.person_rounded, color: primaryPink, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Instructor Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                              SizedBox(height: 3),
                              Text("Manage your faculty identity, credentials, and professional bio.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ================= فرم اطلاعات پروفایل =================
                  isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                      : Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 6))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Personal & Professional Identity", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 20),

                              // بخش آواتار با افکت جذاب
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [primaryPink, lightPinkBg],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 46,
                                        backgroundColor: surfaceWhite,
                                        backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                                        child: _avatarUrl.isEmpty
                                            ? Text(
                                                _firstNameController.text.isNotEmpty ? _firstNameController.text[0].toUpperCase() : "I",
                                                style: const TextStyle(color: primaryPink, fontSize: 28, fontWeight: FontWeight.w900),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _handleAvatarUpload,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryPink,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: surfaceWhite, width: 2.5),
                                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
                                          ),
                                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // فیلدهای اطلاعاتی در قالب ریسپانسیو
                              LayoutBuilder(
                                builder: (context, boxConstraints) {
                                  bool isWide = boxConstraints.maxWidth > 500;
                                  if (isWide) {
                                    return Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: _buildTextField("First Name", _firstNameController)),
                                            const SizedBox(width: 14),
                                            Expanded(child: _buildTextField("Last Name", _lastNameController)),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(child: _buildTextField("Father's Name", _fatherNameController)),
                                            const SizedBox(width: 14),
                                            Expanded(child: _buildTextField("Date of Birth", _dobController)),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(child: _buildReadOnlyField("Email Address", _email)),
                                            const SizedBox(width: 14),
                                            Expanded(child: _buildTextField("Phone Number", _phoneController, keyboardType: TextInputType.phone)),
                                          ],
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        _buildTextField("First Name", _firstNameController),
                                        const SizedBox(height: 14),
                                        _buildTextField("Last Name", _lastNameController),
                                        const SizedBox(height: 14),
                                        _buildTextField("Father's Name", _fatherNameController),
                                        const SizedBox(height: 14),
                                        _buildTextField("Date of Birth", _dobController),
                                        const SizedBox(height: 14),
                                        _buildReadOnlyField("Email Address", _email),
                                        const SizedBox(height: 14),
                                        _buildTextField("Phone Number", _phoneController, keyboardType: TextInputType.phone),
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField("Country / Region", _countryController),
                              const SizedBox(height: 16),
                              _buildTextField("Professional Bio / Headline", _bioController, maxLines: 3),
                              const SizedBox(height: 28),

                              // دکمه ذخیره نهایی
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryPink,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    shadowColor: primaryPink.withValues(alpha: 0.3),
                                  ),
                                  onPressed: isSaving ? null : _handleSaveProfile,
                                  child: Text(
                                    isSaving ? "SAVING CHANGES..." : "SAVE PROFILE DETAILS 🚀",
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBorder.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Text(
            value.isEmpty ? "Not provided" : value,
            style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}