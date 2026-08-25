import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'scholarships_screen.dart'; // مطمئن شوید مدل ScholarshipItem در این فایل است

class ScholarshipDetailScreen extends StatelessWidget {
  final ScholarshipItem scholarship;

  const ScholarshipDetailScreen({super.key, required this.scholarship});

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  String _cleanParsedItem(String value) {
    return value
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(';', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();
  }

  // استخراج و تبدیل ایمن ساختار آرایه‌ای یا رشته‌ای دیتابیس
  List<String> _parseToList(dynamic rawData) {
    if (rawData == null) return [];

    if (rawData is List) {
      return rawData
          .map((e) => _cleanParsedItem(e.toString()))
          .where((e) => e.length > 2)
          .toList();
    }

    String rawText = rawData.toString().trim();
    if (rawText.isEmpty) return [];

    if (rawText.startsWith('[') && rawText.endsWith(']')) {
      rawText = rawText.substring(1, rawText.length - 1);
    }

    List<String> items = rawText.split(RegExp(r'\.,\s*|\.\s+|\n|,\s+'));

    return items
        .map((e) => _cleanParsedItem(e))
        .where((e) => e.length > 2)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final criteriaList = _parseToList(scholarship.eligibilityCriteria);
    final documentsList = _parseToList(scholarship.requiredDocuments);

    return Scaffold(
      backgroundColor: surfaceWhite,
      // دکمه اپلای را در یک باتم‌بار ثابت قرار می‌دهیم تا همیشه در دسترس باشد
      bottomNavigationBar: scholarship.applyLink != null && scholarship.applyLink!.isNotEmpty
          ? Container(
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                top: 16, 
                bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 24
              ),
              decoration: BoxDecoration(
                color: surfaceWhite,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text("APPLY FOR SCHOLARSHIP NOW", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  onPressed: () => _launchURL(scholarship.applyLink!),
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ================= هدر تصویر متحرک (SliverAppBar) =================
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            stretch: true,
            backgroundColor: surfaceWhite,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  scholarship.coverImage != null && scholarship.coverImage!.isNotEmpty
                      ? Image.network(
                          scholarship.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildFallbackBanner(),
                        )
                      : _buildFallbackBanner(),
                  // گرادینت تیره برای خوانایی دکمه بک و زیبایی تصویر
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= محتوای اصلی =================
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)), // گرد کردن لبه‌های بالای محتوا
              ),
              transform: Matrix4.translationValues(0.0, -32.0, 0.0), // کشیدن محتوا روی عکس
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // برچسب‌ها (Tags)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(Icons.public_rounded, scholarship.continent, primaryPink, lightPinkBg),
                        _buildBadge(Icons.location_on_rounded, scholarship.country, textDark, cardBorder),
                        _buildBadge(Icons.school_rounded, scholarship.degreeLevel, textGrey, cardBorder),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // عنوان اصلی بورسیه
                    Text(
                      scholarship.title,
                      style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, height: 1.3, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 10),

                    // نام دانشگاه / موسسه
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: lightPinkBg, shape: BoxShape.circle),
                          child: const Icon(Icons.account_balance_rounded, size: 16, color: primaryPink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            scholarship.university,
                            style: const TextStyle(color: primaryPink, fontSize: 14, fontWeight: FontWeight.w800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: cardBorder, height: 1, thickness: 1.5),
                    const SizedBox(height: 24),

                    // کارت مهلت ثبت‌نام (Deadline)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [lightPinkBg.withOpacity(0.5), surfaceWhite],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: primaryPink, borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.timer_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("APPLICATION DEADLINE", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Text(scholarship.deadline.split('T')[0], style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // توضیحات بورسیه
                    _buildSectionHeader(Icons.info_outline_rounded, "About Scholarship"),
                    const SizedBox(height: 12),
                    Text(
                      scholarship.description,
                      style: const TextStyle(color: Color(0xFF374151), fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),

                    // شرایط پذیرش
                    if (criteriaList.isNotEmpty) ...[
                      _buildSectionHeader(Icons.verified_user_rounded, "Eligibility Criteria"),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: criteriaList.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.check_circle_rounded, color: primaryPink, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(item, style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600, height: 1.5)),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // مدارک مورد نیاز
                    if (documentsList.isNotEmpty) ...[
                      _buildSectionHeader(Icons.folder_shared_rounded, "Required Documents"),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: documentsList.map((doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.description_rounded, color: Colors.blueAccent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(doc, style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600, height: 1.5)),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(text.toUpperCase(), style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 22, color: primaryPink),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18)),
      ],
    );
  }

  // بنر جایگزین در صورت نداشتن عکس کاور
  Widget _buildFallbackBanner() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF494AC), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Icon(Icons.school_rounded, size: 200, color: Colors.white.withOpacity(0.08)),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text("Global Academic Grant", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text("Verified International Opportunity", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}