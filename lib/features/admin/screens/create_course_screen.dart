import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSubmitting = false;
  List<Map<String, dynamic>> teachers = [];
  Map<String, String>? message;

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: "0");
  final thumbCtrl = TextEditingController();
  String? selectedTeacherId;
  bool isPublished = false;  

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    try {
      final response = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url")
          .inFilter("role", ["teacher", "super_admin"]) // Fix: Removed extra positional argument for 'order'
          .order("first_name", ascending: true);

      if (mounted) {
        setState(() {
          teachers = (response as List?)?.cast<Map<String, dynamic>>() ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching teachers: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleCreate() async {
    if (titleCtrl.text.trim().isEmpty || selectedTeacherId == null) {
      setState(() {
        message = {'type': 'error', 'text': 'Title and Lead Instructor are required.'};
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      message = null;
    });

    try {
      double price = double.tryParse(priceCtrl.text.trim()) ?? 0;

      await supabase.from("courses").insert({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'price': price,
        'teacher_id': selectedTeacherId,
        'thumbnail_url': thumbCtrl.text.trim().isNotEmpty ? thumbCtrl.text.trim() : null,
        'is_published': isPublished,
      });

      setState(() {
        message = {'type': 'success', 'text': 'Course successfully deployed!'};
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': 'Failed: ${e.toString()}'};
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text("Back to Library", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text("Course Builder", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 16),

              if (message != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: message!['type'] == 'success' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 14),
              ],

              // Form fields container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0a0a0f),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("COURSE TITLE *", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "e.g. Masterclass in Advanced AI",
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text("CURRICULUM DESCRIPTION", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Syllabus details...",
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("PRICE (USD)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.04),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("STATUS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<bool>(
                                initialValue: isPublished,
                                dropdownColor: const Color(0xFF0a0a0f),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.04),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                items: const [
                                  DropdownMenuItem(value: true, child: Text("Published")),
                                  DropdownMenuItem(value: false, child: Text("Draft")),
                                ],
                                onChanged: (val) => setState(() => isPublished = val ?? false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text("LEAD INSTRUCTOR *", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTeacherId,
                      dropdownColor: const Color(0xFF0a0a0f),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Select Instructor",
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: teachers.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['id'],
                          child: Text("${t['first_name']} ${t['last_name']}"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedTeacherId = val),
                    ),
                    const SizedBox(height: 12),

                    const Text("THUMBNAIL URL", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: thumbCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "https://...",
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting ? null : handleCreate,
                  child: isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("CREATE & DEPLOY COURSE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}