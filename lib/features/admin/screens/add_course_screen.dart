import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';
import '../../../core/services/cloudflare_storage_service.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final supabase = Supabase.instance.client;

  // Controllers for form fields
  final titleCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  final inst1NameCtrl = TextEditingController();
  final inst1BioCtrl = TextEditingController();
  final inst1ImgCtrl = TextEditingController();

  final inst2NameCtrl = TextEditingController();
  final inst2BioCtrl = TextEditingController();
  final inst2ImgCtrl = TextEditingController();

  String selectedLanguage = 'English';
  bool isSubmitting = false;

  File? thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  // Luxury Light-Pink Palette
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void dispose() {
    titleCtrl.dispose();
    categoryCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    inst1NameCtrl.dispose();
    inst1BioCtrl.dispose();
    inst1ImgCtrl.dispose();
    inst2NameCtrl.dispose();
    inst2BioCtrl.dispose();
    inst2ImgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (pickedFile != null) {
      setState(() {
        thumbnailFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (titleCtrl.text.isEmpty ||
        categoryCtrl.text.isEmpty ||
        descCtrl.text.isEmpty ||
        priceCtrl.text.isEmpty) {
      _showError(context.l10n.fillRequiredFields);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      String thumbnailUrl = "";

      if (thumbnailFile != null) {
        final fileExt = thumbnailFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        final bytes = await thumbnailFile!.readAsBytes();
        thumbnailUrl = await CloudflareStorageService.instance.upload(
          bucket: 'safiacademy-media',
          path: 'course-thumbnails/$fileName',
          bytes: bytes,
        );
      }

      await supabase.from('courses').insert({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'category': categoryCtrl.text.trim(),
        'price': double.tryParse(priceCtrl.text) ?? 0.0,
        'language': selectedLanguage,
        'instructor_name': inst1NameCtrl.text.trim(),
        'instructor_bio': inst1BioCtrl.text.trim(),
        'instructor_image_url': inst1ImgCtrl.text.trim(),
        'instructor_2_name': inst2NameCtrl.text.trim(),
        'instructor_2_bio': inst2BioCtrl.text.trim(),
        'instructor_2_image_url': inst2ImgCtrl.text.trim(),
        'thumbnail_url': thumbnailUrl,
        'is_published': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.adminSyncSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      _showError("${context.l10n.failedToUpdateDatabase}: ${error.toString()}");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: Text(
          context.l10n.addNewCourse,
          style: const TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryPink.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryPink.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: lightPinkBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      context.l10n.adminCommandCenter,
                      style: const TextStyle(
                        color: primaryPink,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.manageCourses,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.manageCoursesSubtitle,
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Course Details Section
            _buildSection(
              title: context.l10n.courseDetails,
              children: [
                _buildTextField(
                  titleCtrl,
                  "${context.l10n.courseTitle} *",
                  "Fintech Mastery...",
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        categoryCtrl,
                        "${context.l10n.courseCategory} *",
                        "Finance, Tech...",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${context.l10n.language} *",
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: cardBorder.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder, width: 1.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLanguage,
                                dropdownColor: surfaceWhite,
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: textGrey,
                                ),
                                items: ['English', 'Persian', 'Pashto'].map((
                                  String value,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => selectedLanguage = val!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  descCtrl,
                  "${context.l10n.courseDescription} *",
                  "Write a compelling summary...",
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Instructor 1
            _buildSection(
              title: context.l10n.leadInstructor,
              subtitle: context.l10n.leadInstructor,
              isRequired: true,
              children: [
                _buildTextField(inst1NameCtrl, context.l10n.teacherName, "Instructor Name"),
                const SizedBox(height: 12),
                _buildTextField(
                  inst1BioCtrl,
                  context.l10n.biographyTeacherInfo,
                  "Brief background...",
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildTextField(inst1ImgCtrl, "Image URL", "https://..."),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Instructor 2 (Optional)
            _buildSection(
              title: context.l10n.coInstructor,
              subtitle: "${context.l10n.coInstructor} (${context.l10n.optional})",
              children: [
                _buildTextField(inst2NameCtrl, context.l10n.teacherName, "Instructor 2 Name"),
                const SizedBox(height: 12),
                _buildTextField(
                  inst2BioCtrl,
                  context.l10n.biographyTeacherInfo,
                  "Brief background...",
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildTextField(inst2ImgCtrl, "Image URL", "https://..."),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Asset Upload & Price
            _buildSection(
              title: "${context.l10n.thumbnailUrl} & ${context.l10n.coursePrice}",
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 170,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardBorder.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryPink.withValues(alpha: 0.3),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: thumbnailFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              thumbnailFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                color: primaryPink,
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.l10n.thumbnailUrl,
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.upload,
                                style: const TextStyle(color: textGrey, fontSize: 10),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryPink,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  context.l10n.upload,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  priceCtrl,
                  "${context.l10n.coursePrice} *",
                  "0.00",
                  isNumber: true,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isSubmitting ? null : _handleSubmit,
                child: Text(
                  isSubmitting ? context.l10n.uploading : context.l10n.createCourseAction,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    bool isRequired = false,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              if (isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lightPinkBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.l10n.required.toUpperCase(),
                    style: const TextStyle(
                      color: primaryPink,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textGrey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(
            color: textDark,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
            filled: true,
            fillColor: cardBorder.withValues(alpha: 0.5),
            contentPadding: maxLines > 1
                ? const EdgeInsets.all(14)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: cardBorder),
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
