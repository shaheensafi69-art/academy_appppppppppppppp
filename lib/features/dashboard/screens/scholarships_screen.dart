import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ScholarshipItem {
  final String id;
  final String title;
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
      title: json['title'] ?? '',
      continent: json['continent'] ?? '',
      country: json['country'] ?? '',
      university: json['university'] ?? '',
      degreeLevel: json['degree_level'] ?? '',
      deadline: json['deadline'] ?? '',
      description: json['description'] ?? '',
      eligibilityCriteria: json['eligibility_criteria'] ?? '',
      requiredDocuments: json['required_documents'] ?? '',
      applyLink: json['apply_link'],
      coverImage: json['cover_image'],
    );
  }
}

class ScholarshipsScreen extends StatefulWidget {
  const ScholarshipsScreen({super.key});

  @override
  State<ScholarshipsScreen> createState() => _ScholarshipsScreenState();
}

class _ScholarshipsScreenState extends State<ScholarshipsScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ScholarshipItem> scholarships = [];

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
      final response = await supabase
          .from("scholarships")
          .select("*")
          .eq("is_active", true)
          .order("deadline", ascending: true);

      if (response is List) {
        scholarships = response.map((s) => ScholarshipItem.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching scholarships: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
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
                      child: const Icon(Icons.school_rounded, color: primaryPink, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Global Scholarships", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Explore international academic scholarships, eligibility, and apply directly.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Available Opportunities", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),

              isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5)))
                  : scholarships.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: scholarships.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final sch = scholarships[index];
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorder, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                        child: Text("${sch.country} • ${sch.degreeLevel}", style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                        child: Text("Deadline: ${sch.deadline.split('T')[0]}", style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(sch.title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(sch.university, style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Text(sch.description, style: const TextStyle(color: textGrey, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 14),
                                  
                                  // شرایط و مدارک مورد نیاز به صورت باکس مجزا
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cardBorder.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Eligibility: ${sch.eligibilityCriteria}", style: const TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text("Required Docs: ${sch.requiredDocuments}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                                      ],
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
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: sch.applyLink != null ? () => _launchURL(sch.applyLink!) : null,
                                      child: const Text("APPLY FOR SCHOLARSHIP 🚀", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
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
                          child: const Text("No active scholarships available at the moment.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}