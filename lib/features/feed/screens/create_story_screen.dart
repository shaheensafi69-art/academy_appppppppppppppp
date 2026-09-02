import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/cloudflare_storage_service.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _mediaUrlController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  bool isUploading = false;
  bool isUploadingFile = false;
  String mediaType = 'image'; // 'image' یا 'video'

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  final List<String> sampleMedia = [
    "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80",
    "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800&q=80",
    "https://images.unsplash.com/photo-1531482615713-2afd69097998?w=800&q=80",
    "https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&q=80",
  ];

  @override
  void dispose() {
    _mediaUrlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadMedia() async {
    final picker = ImagePicker();
    XFile? file;
    if (mediaType == 'image') {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } else {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (file != null) {
      setState(() => isUploadingFile = true);
      try {
        final bytes = await file.readAsBytes();
        final ext = mediaType == 'image' ? 'jpg' : 'mp4';
        final fileName = "story_${DateTime.now().millisecondsSinceEpoch}.$ext";

        final publicUrl = await CloudflareStorageService.instance.upload(
          bucket: "story",
          path: fileName,
          bytes: bytes,
          contentType: mediaType == 'image' ? 'image/jpeg' : 'video/mp4',
        );
        setState(() {
          _mediaUrlController.text = publicUrl;
          isUploadingFile = false;
        });
      } catch (e) {
        setState(() => isUploadingFile = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("خطا در آپلود فایل استوری: $e")),
          );
        }
      }
    }
  }

  Future<void> _publishStory() async {
    final mediaUrl = _mediaUrlController.text.trim();
    if (mediaUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("لطفاً آدرس تصویر یا ویدیوی استوری را وارد کنید 📸"),
        ),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isUploading = true);

    try {
      // انقضای ۲۴ ساعته خودکار
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24)).toIso8601String();

      await supabase.from("user_stories").insert({
        'user_id': user.id,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'caption': _captionController.text.trim(),
        'expires_at': expiresAt,
        'created_at': now.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("استوری ۲۴ ساعته شما با موفقیت منتشر شد! 🎉"),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error publishing story: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("خطا در انتشار استوری: $e")));
        setState(() => isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create 24h Story 📸",
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: (isUploading || isUploadingFile)
                  ? null
                  : _publishStory,
              child: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "SHARE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // کارت راهنما ۲۴ ساعته
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightPinkBg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryPink.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined, color: primaryPink, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "استوری شما دقیقاً پس از ۲۴ ساعت به صورت خودکار از فید آکادمی حذف خواهد شد.",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // نوع رسانه (تصویر یا ویدیو)
            const Text(
              "Media Type",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("📷 Image")),
                    selected: mediaType == 'image',
                    selectedColor: primaryPink,
                    labelStyle: TextStyle(
                      color: mediaType == 'image' ? Colors.white : textDark,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => mediaType = 'image');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("🎥 Video")),
                    selected: mediaType == 'video',
                    selectedColor: primaryPink,
                    labelStyle: TextStyle(
                      color: mediaType == 'video' ? Colors.white : textDark,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => mediaType = 'video');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // دکمه انتخاب از گالری
            GestureDetector(
              onTap: isUploadingFile ? null : _pickAndUploadMedia,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: primaryPink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryPink.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      mediaType == 'image'
                          ? Icons.photo_library_rounded
                          : Icons.video_library_rounded,
                      color: primaryPink,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isUploadingFile
                            ? "آپلود فایل به استوری... ⏳"
                            : (_mediaUrlController.text.isNotEmpty
                                  ? "فایل آپلود شد! ✅"
                                  : "انتخاب فایل ${mediaType == 'image' ? 'تصویر' : 'ویدیو'} از گالری 📸"),
                        style: const TextStyle(
                          color: primaryPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isUploadingFile)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: primaryPink,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ورودی URL
            const Text(
              "Media URL (یا لینک آپلود شده)",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mediaUrlController,
              style: const TextStyle(fontSize: 13, color: textDark),
              decoration: InputDecoration(
                hintText: "https://example.com/story.jpg",
                hintStyle: const TextStyle(color: textGrey, fontSize: 12),
                filled: true,
                fillColor: cardBorder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryPink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // تصاویر پیش‌فرض آزمایشی
            const Text(
              "Or Select Quick Media Sample:",
              style: TextStyle(
                fontSize: 12,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sampleMedia.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final url = sampleMedia[index];
                  return GestureDetector(
                    onTap: () {
                      _mediaUrlController.text = url;
                      setState(() {});
                    },
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: _mediaUrlController.text == url
                              ? primaryPink
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // توضیحات (Caption)
            const Text(
              "Caption / Text Overlay",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: textDark),
              decoration: InputDecoration(
                hintText: "Write a message for your peers...",
                hintStyle: const TextStyle(color: textGrey, fontSize: 12),
                filled: true,
                fillColor: cardBorder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryPink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // پیش‌نمایش استوری
            if (_mediaUrlController.text.isNotEmpty) ...[
              const Text(
                "Story Preview",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(_mediaUrlController.text),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      _captionController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
