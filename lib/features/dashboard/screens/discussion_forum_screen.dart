import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForumPostItem {
  final String id;
  final String studentId;
  final String title;
  final String content;
  final String createdAt;

  ForumPostItem({
    required this.id,
    required this.studentId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory ForumPostItem.fromJson(Map<String, dynamic> json) {
    return ForumPostItem(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class DiscussionForumScreen extends StatefulWidget {
  const DiscussionForumScreen({super.key});

  @override
  State<DiscussionForumScreen> createState() => _DiscussionForumScreenState();
}

class _DiscussionForumScreenState extends State<DiscussionForumScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isPosting = false;
  List<ForumPostItem> posts = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchForumPosts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchForumPosts() async {
    setState(() => isLoading = true);
    try {
      // واکشی مستقیم پست‌ها بدون Join پیچیده که به مشکل RLS برنخورد
      final res = await supabase
          .from("discussion_posts")
          .select("*")
          .order("created_at", ascending: false);

      posts = (res as List).map((p) => ForumPostItem.fromJson(p)).toList();
    } catch (e) {
      debugPrint("Forum posts fetch error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createNewPost() async {
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

      await supabase.from("discussion_posts").insert({
        'student_id': user.id,
        'title': title,
        'content': content,
      });

      _titleController.clear();
      _contentController.clear();
      await _fetchForumPosts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Discussion topic posted successfully! 🚀"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error posting topic: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post topic: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                          child: const Icon(Icons.forum_rounded, color: primaryPink, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Discussion Forum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                              SizedBox(height: 3),
                              Text("Exchange ideas, ask questions, and collaborate with other students.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ================= بخش ایجاد پست جدید =================
                  const Text("Start a New Discussion", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Topic title...",
                            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                            filled: true,
                            fillColor: cardBorder.withOpacity(0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contentController,
                          maxLines: 3,
                          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: "Write your question or topic details here...",
                            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                            filled: true,
                            fillColor: cardBorder.withOpacity(0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder, width: 1.5)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: isPosting ? null : _createNewPost,
                            child: isPosting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("PUBLISH TOPIC 🚀", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ================= لیست بحث‌ها و گفتگوها =================
                  const Text("Community Discussions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 12),

                  isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                      : posts.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: posts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: cardBorder, width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                            child: const Text("Academy Student", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                          ),
                                          Text(post.createdAt.isNotEmpty ? post.createdAt.split('T')[0] : '', style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(post.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      Text(post.content, style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(40),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorder, width: 1.5),
                              ),
                              child: const Text("No discussions started yet. Be the first to post!", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
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
}