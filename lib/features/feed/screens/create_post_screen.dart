import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudflare_storage_service.dart';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;
  const CreatePostScreen({super.key, this.onPostSuccess});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final supabase = Supabase.instance.client;
  bool isLoadingProfile = true;
  bool isPosting = false;
  File? _selectedImageFile;

  Map<String, dynamic>? userProfile;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String selectedMood = "🚀 Excited";
  final List<String> moods = ["🚀 Excited", "💡 Learning", "📊 Analysis", "🔥 Motivated", "📢 Announcement"];

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await supabase
            .from('profiles')
            .select('first_name, last_name, avatar_url, role')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          setState(() {
            userProfile = res;
            isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _publishPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in both title and content fields."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isPosting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      String? uploadedImageUrl;
      if (_selectedImageFile != null) {
        final fileName = "post_${DateTime.now().millisecondsSinceEpoch}.jpg";
        uploadedImageUrl = await CloudflareStorageService.instance.upload(
          bucket: "safiacademy-media",
          path: "feed/$fileName",
          file: _selectedImageFile,
          contentType: "image/jpeg",
        );
      }

      Map<String, dynamic> insertData = {
        'student_id': user.id,
        'title': "[$selectedMood] $title",
        'content': content,
      };
      if (uploadedImageUrl != null) insertData['image_url'] = uploadedImageUrl;

      await supabase.from("discussion_posts").insert(insertData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post published successfully! 🎉"), backgroundColor: Colors.green),
        );
        
        _titleController.clear();
        _contentController.clear();
        setState(() => _selectedImageFile = null);

        if (widget.onPostSuccess != null) {
          widget.onPostSuccess!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to publish post: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String authorName = "Academy Member";
    String roleLabel = "Public Post 🌍";
    Color roleColor = primaryPink;
    
    if (userProfile != null) {
      authorName = "${userProfile!['first_name'] ?? ''} ${userProfile!['last_name'] ?? ''}".trim();
      if (userProfile!['role'] == 'teacher') {
        roleLabel = "Instructor Post 🎓";
        roleColor = Colors.blueAccent;
      } else if (userProfile!['role'] == 'admin' || userProfile!['role'] == 'super_admin') {
        roleLabel = "Admin Announcement 🛡️";
        roleColor = Colors.deepPurple;
      } else {
        roleLabel = "Student Post 🌍";
      }
    }
    String avatarUrl = userProfile?['avatar_url'] ?? '';

    return AcademyLoadingOverlay(
      isLoading: isPosting,
      message: "PUBLISHING POST...",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          iconTheme: const IconThemeData(color: textDark),
          title: const Text("Create New Post ✍️", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: primaryPink.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: isPosting ? null : _publishPost,
                child: const Text("Publish", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5).withOpacity(0.4), surfaceWhite],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: cardBorder, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // پروفایل کاربر
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: lightPinkBg,
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(authorName.isNotEmpty ? authorName[0] : 'U', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 18))
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(authorName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(roleLabel, style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // انتخاب Vibe / Topic
                              const Text("SELECT VIBE / TOPIC", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: moods.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final m = moods[index];
                                    bool isSelected = selectedMood == m;
                                    return ChoiceChip(
                                      label: Text(m, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : textDark)),
                                      selected: isSelected,
                                      selectedColor: primaryPink,
                                      backgroundColor: cardBorder,
                                      onSelected: (selected) => setState(() => selectedMood = m),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // فیلد عنوان با کرسرصورتی و متن تیره
                              TextField(
                                controller: _titleController,
                                cursorColor: primaryPink,
                                style: const TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w900),
                                decoration: const InputDecoration(
                                  hintText: "Give your post a catching title...",
                                  hintStyle: TextStyle(color: textGrey, fontSize: 18, fontWeight: FontWeight.w600),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                              const Divider(color: cardBorder, height: 32, thickness: 1.5),

                              // فیلد متن اصلی با کرسر صورتی و متن خوانا
                              TextField(
                                controller: _contentController,
                                cursorColor: primaryPink,
                                maxLines: null,
                                minLines: 6,
                                style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w500, height: 1.6),
                                decoration: const InputDecoration(
                                  hintText: "What's on your mind? Share trading setups, ideas, or questions with the academy...",
                                  hintStyle: TextStyle(color: textGrey, fontSize: 14, height: 1.6),
                                  border: InputBorder.none,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // پیش‌نمایش تصویر انتخاب شده
                              if (_selectedImageFile != null) ...[
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 6))],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(_selectedImageFile!, height: 240, width: double.infinity, fit: BoxFit.cover),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12, right: 12,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedImageFile = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // نوار ابزار پایین برای عکس و تگ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: const Border(top: BorderSide(color: cardBorder, width: 1.5)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, -4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Attach Media", style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.photo_library_rounded, color: Colors.green, size: 24),
                                onPressed: () => _pickImage(ImageSource.gallery),
                                tooltip: "Gallery",
                              ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt_rounded, color: primaryPink, size: 24),
                                onPressed: () => _pickImage(ImageSource.camera),
                                tooltip: "Camera",
                              ),
                              IconButton(
                                icon: const Icon(Icons.tag_rounded, color: Colors.blue, size: 24),
                                onPressed: () => _contentController.text += " #SafiAcademy #Trading ",
                                tooltip: "Add Tags",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class AcademyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AcademyLoadingOverlay({super.key, required this.isLoading, required this.child, this.message = "LOADING..."});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withOpacity(0.95),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFF494AC), strokeWidth: 3),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}