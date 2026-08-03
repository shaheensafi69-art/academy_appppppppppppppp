import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'scholarships_screen.dart';

class ScholarshipDetailScreen extends StatelessWidget {
  final ScholarshipItem scholarship;

  const ScholarshipDetailScreen({super.key, required this.scholarship});

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
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

  // تابع هوشمند و دقیق برای استخراج و تبدیل ایمن ساختار آرایه‌ای یا رشته‌ای دیتابیس
  Iterable<String> _parseToList(dynamic rawData) {
    if (rawData == null) return [];

    // اگر دیتابیس داده را به صورت لیست (آرایه JSON) برگرداند
    if (rawData is List) {
      return rawData
          .map((e) => _cleanParsedItem(e.toString()))
          .where((e) => e.length > 2);
    }

    // اگر به صورت متن رشته‌ای باشد
    String rawText = rawData.toString().trim();
    if (rawText.isEmpty) return [];

    // پاکسازی براکت‌های ابتدایی و انتهایی
    if (rawText.startsWith('[') && rawText.endsWith(']')) {
      rawText = rawText.substring(1, rawText.length - 1);
    }

    // جداسازی بر اساس کاما، نقطه یا خط جدید
    List<String> items = rawText.split(RegExp(r'\.,\s*|\.\s+|\n|,\s+'));

    return items
        .map((e) => _cleanParsedItem(e))
        .where((e) => e.length > 2)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // دریافت لیست‌های کاملاً تفکیک‌شده و منظم
    final criteriaList = _parseToList(scholarship.eligibilityCriteria);
    final documentsList = _parseToList(scholarship.requiredDocuments);

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: const Text("Scholarship Overview", style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بنر کاور
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: scholarship.coverImage != null && scholarship.coverImage!.isNotEmpty
                    ? Image.network(
                        scholarship.coverImage!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackBanner(),
                      )
                    : _buildFallbackBanner(),
              ),
              const SizedBox(height: 20),

              // برچسب‌ها
              Row(
                children: [
                  _buildBadge(Icons.public_rounded, scholarship.continent, primaryPink, lightPinkBg),
                  const SizedBox(width: 8),
                  _buildBadge(Icons.location_on_rounded, scholarship.country, textDark, cardBorder),
                  const SizedBox(width: 8),
                  _buildBadge(Icons.school_rounded, scholarship.degreeLevel, textGrey, cardBorder),
                ],
              ),
              const SizedBox(height: 16),

              // عنوان و دانشگاه
              Text(
                scholarship.title,
                style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18, height: 1.25),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 14, color: primaryPink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scholarship.university,
                      style: const TextStyle(color: primaryPink, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // کارت مهلت اقدام
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lightPinkBg.withOpacity(0.6), surfaceWhite],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: primaryPink, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.timer_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("APPLICATION DEADLINE", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text(scholarship.deadline.split('T')[0], style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // درباره بورسیه
              _buildSectionHeader(Icons.info_outline_rounded, "About Scholarship"),
              const SizedBox(height: 8),
              Text(
                scholarship.description,
                style: const TextStyle(color: textGrey, fontSize: 12, height: 1.6, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 22),

              // شرایط پذیرش (نمایش خط‌به‌خط و تک‌مارک)
              _buildSectionHeader(Icons.verified_user_rounded, "Eligibility Criteria"),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: Column(
                  children: criteriaList.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded, color: primaryPink, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 22),

              // مدارک مورد نیاز (نمایش خط‌به‌خط و تک‌مارک)
              _buildSectionHeader(Icons.folder_shared_rounded, "Required Documents"),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: Column(
                  children: documentsList.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.description_rounded, color: primaryPink, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            doc,
                            style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // دکمه اپلای
              if (scholarship.applyLink != null && scholarship.applyLink!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      shadowColor: primaryPink.withOpacity(0.4),
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: const Text("APPLY FOR SCHOLARSHIP NOW 🚀", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    onPressed: () => _launchURL(scholarship.applyLink!),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryPink),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(Icons.school_rounded, size: 110, color: Colors.white.withOpacity(0.12)),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 28),
                SizedBox(height: 10),
                Text("Global Academic Grant", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text("Verified International Opportunity", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}