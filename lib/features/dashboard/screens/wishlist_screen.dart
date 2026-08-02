import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistItem {
  final String id;
  final String courseId;
  final String title;
  final String category;
  final double price;
  final String? thumbnailUrl;
  final String instructorName;

  WishlistItem({
    required this.id,
    required this.courseId,
    required this.title,
    required this.category,
    required this.price,
    this.thumbnailUrl,
    required this.instructorName,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json, Map<String, dynamic> courseData) {
    return WishlistItem(
      id: json['id']?.toString() ?? '',
      courseId: courseData['id']?.toString() ?? '',
      title: courseData['title'] ?? '',
      category: courseData['category'] ?? 'General',
      price: (courseData['price'] ?? 0).toDouble(),
      thumbnailUrl: courseData['thumbnail_url'],
      instructorName: courseData['instructor_name'] ?? 'Instructor',
    );
  }
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<WishlistItem> wishlist = [];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // واکشی دوره‌های علاقه‌مندی شاگرد از جدول wishlists (یا جداول مرتبط دوره‌های محبوب)
      final res = await supabase
          .from("wishlists")
          .select("id, course_id, courses(*)")
          .eq("student_id", user.id);

      if (res is List) {
        wishlist = res.map((item) {
          final courseObj = item['courses'];
          final courseData = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0] : {}) : (courseObj ?? {});
          return WishlistItem.fromJson(item, courseData);
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching wishlist: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(String wishId) async {
    try {
      await supabase.from("wishlists").delete().eq("id", wishId);
      setState(() {
        wishlist.removeWhere((w) => w.id == wishId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Course removed from wishlist.")),
        );
      }
    } catch (e) {
      debugPrint("Error removing item: $e");
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر صفحه
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
                      child: const Icon(Icons.favorite_rounded, color: primaryPink, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("My Wishlist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Access your saved favorite courses and enroll whenever you're ready.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Saved Courses", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                  : wishlist.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: wishlist.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = wishlist[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorder, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: lightPinkBg,
                                      borderRadius: BorderRadius.circular(16),
                                      image: item.thumbnailUrl != null
                                          ? DecorationImage(image: NetworkImage(item.thumbnailUrl!), fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: item.thumbnailUrl == null
                                        ? const Icon(Icons.menu_book_rounded, color: primaryPink, size: 28)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(item.category.toUpperCase(), style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                            GestureDetector(
                                              onTap: () => _removeFromWishlist(item.id),
                                              child: const Icon(Icons.favorite_rounded, color: primaryPink, size: 18),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(item.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text("Instructor: ${item.instructorName}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Text("\$${item.price.toStringAsFixed(2)}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                      ],
                                    ),
                                  ),
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
                          child: const Text("Your wishlist is empty. Save courses to view them later!", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}