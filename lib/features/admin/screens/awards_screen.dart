import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Map<String, String>? message; // {'type': 'success'/'error', 'text': ...}

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final iconCtrl = TextEditingController(text: "🏆");
  final pointsCtrl = TextEditingController(text: "0");

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
        message = {'type': 'error', 'text': 'Title and description are required.'};
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      message = null;
    });

    try {
      final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
      final icon = iconCtrl.text.trim().isNotEmpty ? iconCtrl.text.trim() : "🏆";

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
        message = {'type': 'success', 'text': 'Honor badge successfully created!'};
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
        message = {'type': 'error', 'text': 'Failed to create badge: ${e.toString()}'};
      });
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> handleDeleteAward(String id) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a0f),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: const Text("Delete Badge", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to delete this badge? Students who already have it might lose it from their profile.", style: TextStyle(color: Colors.grey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
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
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING HONORS SYSTEM...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          // Background Ambience Glow
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.amber.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "HONORS & BADGES",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Academy Honors",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Create and manage official academy badges for outstanding achievements.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        _buildMiniStat("Total Badges", awards.length.toString(), Icons.military_tech_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= CREATE NEW BADGE FORM =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("CREATE NEW BADGE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1.2)),
                        const SizedBox(height: 12),

                        if (message != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: message!['type'] == 'success' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: message!['type'] == 'success' ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(message!['type'] == 'success' ? Icons.check_circle : Icons.error, color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(message!['text']!, style: TextStyle(color: message!['type'] == 'success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Badge Title
                        const Text("BADGE TITLE *", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "e.g. Top Scholar",
                            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.amber, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        const Text("DESCRIPTION *", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: descCtrl,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "What is this badge awarded for?",
                            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            contentPadding: const EdgeInsets.all(12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.amber, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Icon & Points Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("ICON / EMOJI", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: iconCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: "🏆",
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.04),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.amber, width: 1.5)),
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
                                  const Text("POINTS VALUE", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: pointsCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: "0",
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.04),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.amber, width: 1.5)),
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
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting ? null : handleCreateAward,
                            child: isSubmitting
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Text("SAVE BADGE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ================= ACADEMY REGISTRY (LIST) =================
                  const Text("ACADEMY REGISTRY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 10),

                  awards.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(30),
                          alignment: Alignment.center,
                          child: Text("No badges have been created yet.", style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: awards.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final award = awards[index];
                            return _buildGlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(award.iconUrl, style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(award.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(award.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                        const SizedBox(height: 4),
                                        Text("${award.pointsRequired} Points Required", style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: deletingId == award.id ? null : () => handleDeleteAward(award.id),
                                    child: deletingId == award.id
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                        : const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.8)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}