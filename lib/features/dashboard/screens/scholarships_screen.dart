import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ScholarshipItem {
  final String id;
  final String title;
  final String language;
  final String continent;
  final String country;
  final String university;
  final String degreeLevel;
  final String deadline;
  final String description;
  final String eligibilityCriteria;
  final String requiredDocuments;
  final String? applyLink;
  final String? coverImage;

  ScholarshipItem({
    required this.id,
    required this.title,
    required this.language,
    required this.continent,
    required this.country,
    required this.university,
    required this.degreeLevel,
    required this.deadline,
    required this.description,
    required this.eligibilityCriteria,
    required this.requiredDocuments,
    this.applyLink,
    this.coverImage,
  });

  factory ScholarshipItem.fromJson(Map<String, dynamic> json) {
    return ScholarshipItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Scholarship',
      language: json['language']?.toString().toLowerCase() ?? 'en',
      continent: json['continent']?.toString() ?? 'Global',
      country: json['country']?.toString() ?? 'International',
      university: json['university']?.toString() ?? 'University',
      degreeLevel: json['degree_level']?.toString() ?? 'All Degrees',
      deadline: json['deadline']?.toString() ?? 'Open Deadline',
      description: json['description']?.toString() ?? 'No description provided.',
      eligibilityCriteria: json['eligibility_criteria']?.toString() ?? 'Standard criteria apply.',
      requiredDocuments: json['required_documents']?.toString() ?? 'Standard documents required.',
      applyLink: json['apply_link']?.toString(),
      coverImage: json['cover_image']?.toString(),
    );
  }
}

// ================= صفحه جزئیات اسکالرشیپ (Scholarship Detail Screen) =================
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

  @override
  Widget build(BuildContext context) {
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
              // تصویر کاور یا بنر حرفه‌ای
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: scholarship.coverImage != null && scholarship.coverImage!.isNotEmpty
                    ? Image.network(
                        scholarship.coverImage!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildFallbackBanner(),
                      )
                    : _buildFallbackBanner(),
              ),
              const SizedBox(height: 20),

              // برچسب‌ها (کشور، مقطع، قاره)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBadge("${scholarship.country} • ${scholarship.degreeLevel}", primaryPink, lightPinkBg),
                  _buildBadge(scholarship.continent, textGrey, cardBorder),
                ],
              ),
              const SizedBox(height: 12),

              Text(scholarship.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16, height: 1.3)),
              const SizedBox(height: 4),
              Text(scholarship.university, style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // مهلت اقدام فشرده و شیک
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Deadline", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(scholarship.deadline.split('T')[0], style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // توضیحات
              const Text("Description", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 6),
              Text(scholarship.description, style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),

              // شرایط پذیرش فشرده
              const Text("Eligibility Criteria", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: lightPinkBg.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                child: Text(scholarship.eligibilityCriteria, style: const TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3)),
              ),
              const SizedBox(height: 16),

              // مدارک مورد نیاز فشرده
              const Text("Required Documents", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(12)),
                child: Text(scholarship.requiredDocuments, style: const TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3)),
              ),
              const SizedBox(height: 24),

              // دکمه اپلای
              if (scholarship.applyLink != null && scholarship.applyLink!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                    label: const Text("APPLY NOW 🚀", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    onPressed: () => _launchURL(scholarship.applyLink!),
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(right: -15, bottom: -15, child: Icon(Icons.school_rounded, size: 90, color: Colors.white.withOpacity(0.15))),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                SizedBox(height: 8),
                Text("Global Academic Grant", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text("Verified International Opportunity", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= صفحه لیست اسکالرشیپ‌ها (Scholarships Screen) =================
class ScholarshipsScreen extends StatefulWidget {
  const ScholarshipsScreen({super.key});

  @override
  State<ScholarshipsScreen> createState() => _ScholarshipsScreenState();
}

class _ScholarshipsScreenState extends State<ScholarshipsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ScholarshipItem> allScholarships = [];
  
  String selectedRegion = "All";
  List<String> regions = ["All"];

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchScholarships();
  }

  Future<void> _fetchScholarships() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase.from("scholarships").select("*");

      // خواندن و فیلتر دقیق فقط زبان انگلیسی (en)
      allScholarships = (response as List)
          .map((s) => ScholarshipItem.fromJson(s))
          .where((item) => item.language == 'en')
          .toList();

      Set<String> regionSet = {"All"};
      for (var item in allScholarships) {
        if (item.continent.isNotEmpty) {
          regionSet.add(item.continent);
        }
      }
      regions = regionSet.toList();
    } catch (e) {
      debugPrint("Error fetching scholarships: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredScholarships = selectedRegion == "All"
        ? allScholarships
        : allScholarships.where((s) => s.continent.toLowerCase() == selectedRegion.toLowerCase()).toList();

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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                  boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.school_rounded, color: primaryPink, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Global Scholarships", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 2),
                          Text("Explore English academic grants & opportunities.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // دکمه‌های فیلتر ریژن فشرده و زیبا
              if (regions.isNotEmpty) ...[
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: regions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final reg = regions[index];
                      final isSelected = selectedRegion == reg;
                      return GestureDetector(
                        onTap: () => setState(() => selectedRegion = reg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? primaryPink : cardBorder,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            reg,
                            style: TextStyle(
                              color: isSelected ? Colors.white : textGrey,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text("Available Opportunities", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 10),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                  : filteredScholarships.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredScholarships.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sch = filteredScholarships[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScholarshipDetailScreen(scholarship: sch),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorder, width: 1.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (sch.coverImage != null && sch.coverImage!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                                        child: Image.network(
                                          sch.coverImage!,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(6)),
                                                child: Text("${sch.country} • ${sch.degreeLevel}", style: const TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                                              ),
                                              Text(sch.deadline.split('T')[0], style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(sch.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(sch.university, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.all(30),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: const Text("No active English scholarships available.", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}