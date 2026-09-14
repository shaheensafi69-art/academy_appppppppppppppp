import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';

class AwardItem {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final int pointsRequired;

  AwardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.pointsRequired,
  });

  factory AwardItem.fromJson(Map<String, dynamic> json) {
    return AwardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'] ?? '🏆',
      pointsRequired: json['points_required'] ?? 0,
    );
  }
}

class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key});

  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  final supabase = Supabase.instance.client;

  List<AwardItem> awards = [];
  bool isLoading = true;
  bool isSubmitting = false;
  String? deletingId;
  Map<String, String>? message;

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final iconCtrl = TextEditingController(text: "🏆");
  final pointsCtrl = TextEditingController(text: "0");

  // Luxury Light-Pink Theme Palette
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchAwards();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    iconCtrl.dispose();
    pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAwards() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("awards")
          .select("*")
          .order("points_required", ascending: true);

      final List<AwardItem> loaded = (response as List)
          .map((item) => AwardItem.fromJson(item))
          .toList();

      if (mounted) {
        setState(() {
          awards = loaded;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching awards: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleCreateAward() async {
    if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
      setState(() {
        message = {'type': 'error', 'text': context.l10n.fillRequiredFields};
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      message = null;
    });

    try {
      final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
      final icon = iconCtrl.text.trim().isNotEmpty
          ? iconCtrl.text.trim()
          : "🏆";

      final response = await supabase
          .from("awards")
          .insert({
            'title': titleCtrl.text.trim(),
            'description': descCtrl.text.trim(),
            'icon_url': icon,
            'points_required': points,
          })
          .select()
          .single();

      final newAward = AwardItem.fromJson(response);

      setState(() {
        awards.add(newAward);
        awards.sort((a, b) => a.pointsRequired.compareTo(b.pointsRequired));
        message = {'type': 'success', 'text': context.l10n.publishAwardAction};
        titleCtrl.clear();
        descCtrl.clear();
        iconCtrl.text = "🏆";
        pointsCtrl.text = "0";
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => message = null);
      });
    } catch (e) {
      setState(() {
        message = {'type': 'error', 'text': e.toString()};
      });
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> handleDeleteAward(String id) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorder, width: 1.5),
        ),
        title: Text(
          context.l10n.deleteAward,
          style: const TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          context.l10n.confirmDelete,
          style: const TextStyle(
            color: textGrey,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(
                color: textGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.l10n.delete,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    setState(() => deletingId = id);
    try {
      await supabase.from("awards").delete().eq("id", id);
      setState(() {
        awards.removeWhere((a) => a.id == id);
      });
    } catch (e) {
      debugPrint("Failed to delete award: $e");
    } finally {
      if (mounted) setState(() => deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: primaryPink,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.loadingDirectory,
                style: const TextStyle(
                  color: textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: primaryPink.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryPink.withValues(alpha: 0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          context.l10n.awardsAndRecognition,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: primaryPink,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: primaryPink,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.awardsAndRecognition,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.awardsSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMiniStat(
                    context.l10n.awardsAndRecognition,
                    awards.length.toString(),
                    Icons.military_tech_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Create New Badge Form
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(28),
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
                  Text(
                    context.l10n.createAwardTitle.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: textGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message!['type'] == 'success'
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: message!['type'] == 'success'
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.redAccent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            message!['type'] == 'success'
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            color: message!['type'] == 'success'
                                ? Colors.green.shade700
                                : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message!['text']!,
                              style: TextStyle(
                                color: message!['type'] == 'success'
                                    ? Colors.green.shade700
                                    : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Badge Title
                  Text(
                    "${context.l10n.awardTitle.toUpperCase()} *",
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: textGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g. Master Trader",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                        borderSide: const BorderSide(
                          color: primaryPink,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    "${context.l10n.awardDescription.toUpperCase()} *",
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: textGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.all(16),
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
                        borderSide: const BorderSide(
                          color: primaryPink,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Icon & Points Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.awardIcon.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: textGrey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: iconCtrl,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: "🏆",
                                filled: true,
                                fillColor: cardBorder.withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: cardBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: cardBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: primaryPink,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.pointsRequired.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: textGrey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: pointsCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: "0",
                                filled: true,
                                fillColor: cardBorder.withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: cardBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: cardBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: primaryPink,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

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
                      onPressed: isSubmitting ? null : handleCreateAward,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              context.l10n.publishAwardAction,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Academy Registry
            Row(
              children: [
                Text(
                  context.l10n.availableAwards.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textGrey,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1.5, color: cardBorder)),
              ],
            ),
            const SizedBox(height: 14),

            awards.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Text(
                      context.l10n.noAwardsFound,
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: awards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final award = awards[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: lightPinkBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: primaryPink.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                award.iconUrl,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    award.title,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    award.description,
                                    style: const TextStyle(
                                      color: textGrey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${award.pointsRequired} ${context.l10n.pointsRequired}",
                                    style: const TextStyle(
                                      color: primaryPink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: deletingId == award.id
                                  ? null
                                  : () => handleDeleteAward(award.id),
                              child: deletingId == award.id
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.redAccent,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.delete_outline_rounded,
                                      color: textGrey,
                                      size: 20,
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: textGrey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
