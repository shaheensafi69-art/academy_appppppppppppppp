import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        thumbnailFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (titleCtrl.text.isEmpty || categoryCtrl.text.isEmpty || descCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
      _showError("Please fill all required fields.");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      String thumbnailUrl = "";

      // 1. Upload Thumbnail (if selected)
      if (thumbnailFile != null) {
        final fileExt = thumbnailFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await supabase.storage.from('course-thumbnails').upload(fileName, thumbnailFile!);
        thumbnailUrl = supabase.storage.from('course-thumbnails').getPublicUrl(fileName);
      }

      // 2. Insert into Database
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
          const SnackBar(content: Text("Course created successfully! 🚀"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // بازگشت به صفحه قبل
      }
    } catch (error) {
      _showError("Error: ${error.toString()}");
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
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Create Course", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Blobs (نورهای محو پس‌زمینه)
          Positioned(
            top: 50, left: -100,
            child: _buildGlowOrb(Colors.amber.withOpacity(0.15), 300),
          ),
          Positioned(
            top: 300, right: -100,
            child: _buildGlowOrb(Colors.blue.withOpacity(0.15), 250),
          ),
          Positioned(
            bottom: -50, left: 50,
            child: _buildGlowOrb(Colors.purple.withOpacity(0.15), 300),
          ),

          // Main Form Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text("ADMIN STUDIO", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Design a premium course page.", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 12),
                  Text("Every field is styled for clarity and impact. Upload assets, add instructors, and publish your course.", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                  const SizedBox(height: 30),

                  // 1. Course Details Section
                  _buildGlassSection(
                    title: "Course Details",
                    children: [
                      _buildTextField(titleCtrl, "Course Title", "Fintech Mastery...", isRequired: true),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(categoryCtrl, "Category", "Finance, Tech...", isRequired: true)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Language", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedLanguage,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1a1a1a),
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                      items: ['English', 'Persian', 'Pashto'].map((String value) {
                                        return DropdownMenuItem<String>(value: value, child: Text(value));
                                      }).toList(),
                                      onChanged: (val) => setState(() => selectedLanguage = val!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(descCtrl, "Description", "Write a compelling summary...", maxLines: 4, isRequired: true),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Instructor 1
                  _buildGlassSection(
                    title: "Instructor 1",
                    subtitle: "Primary course instructor",
                    isRequired: true,
                    children: [
                      _buildTextField(inst1NameCtrl, "Name", "Instructor Name"),
                      const SizedBox(height: 12),
                      _buildTextField(inst1BioCtrl, "Bio", "Brief background...", maxLines: 3),
                      const SizedBox(height: 12),
                      _buildTextField(inst1ImgCtrl, "Image URL", "https://..."),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Instructor 2 (Optional)
                  _buildGlassSection(
                    title: "Instructor 2",
                    subtitle: "Optional co-instructor",
                    children: [
                      _buildTextField(inst2NameCtrl, "Name", "Instructor 2 Name"),
                      const SizedBox(height: 12),
                      _buildTextField(inst2BioCtrl, "Bio", "Brief background...", maxLines: 3),
                      const SizedBox(height: 12),
                      _buildTextField(inst2ImgCtrl, "Image URL", "https://..."),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Asset Upload & Price
                  _buildGlassSection(
                    title: "Asset & Pricing",
                    children: [
                      // Upload Box
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.amber.withOpacity(0.3), style: BorderStyle.solid),
                          ),
                          child: thumbnailFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.file(thumbnailFile!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
                                    const SizedBox(height: 12),
                                    const Text("Upload 16:9 Thumbnail", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                                      child: const Text("Choose File", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                    )
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(priceCtrl, "Price (USD)", "e.g. 99.99", isRequired: true, isNumber: true),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                        child: const Text("The course is saved as a draft and will be published after you submit. You can edit it later.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      )
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 10,
                        shadowColor: Colors.amber.withOpacity(0.3),
                      ),
                      onPressed: isSubmitting ? null : _handleSubmit,
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text("PUBLISH COURSE NOW", style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === Helper Widgets ===

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 100, spreadRadius: 50),
        ],
      ),
    );
  }

  Widget _buildGlassSection({required String title, String? subtitle, bool isRequired = false, required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]
                    ],
                  ),
                  if (isRequired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Text("REQUIRED", style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    )
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool isRequired = false, int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            if (isRequired) const Text("REQUIRED", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.amber)),
          ),
        ),
      ],
    );
  }
}