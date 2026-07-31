import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String forexCourseId = "d9fa8678-76b4-4705-b579-7860407d43e8";

class TradingJournalItem {
  final String id;
  final String studentId;
  final String tradeDate;
  final String symbol;
  final String positionType;
  final String setupStrategy;
  final double lotSize;
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final double exitPrice;
  final double profitLossUsd;
  final double rrMultiple;
  final String emotions;
  final String analysisNotes;
  final String? chartImageUrl;
  final int? teacherScore;
  final String? teacherFeedback;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;

  TradingJournalItem({
    required this.id,
    required this.studentId,
    required this.tradeDate,
    required this.symbol,
    required this.positionType,
    required this.setupStrategy,
    required this.lotSize,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.exitPrice,
    required this.profitLossUsd,
    required this.rrMultiple,
    required this.emotions,
    required this.analysisNotes,
    this.chartImageUrl,
    this.teacherScore,
    this.teacherFeedback,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
  });
}

class TeacherTradingJournalScreen extends StatefulWidget {
  const TeacherTradingJournalScreen({super.key});

  @override
  State<TeacherTradingJournalScreen> createState() => _TeacherTradingJournalScreenState();
}

class _TeacherTradingJournalScreenState extends State<TeacherTradingJournalScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool hasAccess = false;
  List<TradingJournalItem> journals = [];
  bool isSubmittingGrade = false; // Added this line
  String searchQuery = "";

  // مودال ممیزی
  TradingJournalItem? selectedJournal;
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccessAndFetchJournals();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndFetchJournals() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // ۱. بررسی دسترسی استاد به دوره فارکس
      final forexClassGroups = await supabase
          .from("class_groups")
          .select("id")
          .eq("teacher_id", user.id)
          .eq("course_id", forexCourseId);

      if (forexClassGroups == null || (forexClassGroups as List).isEmpty) {
        setState(() {
          hasAccess = false;
          isLoading = false;
        });
        return;
      }

      setState(() => hasAccess = true);
      final classIds = (forexClassGroups as List).map((cg) => cg['id']).toList();

      // ۲. دریافت شاگردان کلاس‌های فارکس استاد
      final classStudents = await supabase
          .from("class_students")
          .select("student_id")
          .inFilter("class_group_id", classIds);

      if (classStudents == null || (classStudents as List).isEmpty) {
        setState(() {
          journals = [];
          isLoading = false;
        });
        return;
      }

      final studentIds = (classStudents as List).map((cs) => cs['student_id']).toSet().toList();

      // ۳. واکشی پروفایل و ژورنال‌های شاگردان
      final profiles = await supabase
          .from("profiles")
          .select("id, first_name, last_name, email, avatar_url")
          .inFilter("id", studentIds);

      final journalsData = await supabase
          .from("trading_journals")
          .select("*")
          .inFilter("student_id", studentIds) // Corrected: Use named argument for ascending
          .order("trade_date", ascending: false);

      if (journalsData != null) {
        journals = (journalsData as List).map((j) {
          final p = (profiles as List?)?.firstWhere(
            (prof) => prof['id'] == j['student_id'],
            orElse: () => null,
          );

          return TradingJournalItem(
            id: j['id'] ?? '',
            studentId: j['student_id'] ?? '',
            tradeDate: j['trade_date'] ?? '',
            symbol: j['symbol'] ?? 'EURUSD',
            positionType: j['position_type'] ?? 'BUY',
            setupStrategy: j['setup_strategy'] ?? '',
            lotSize: (j['lot_size'] ?? 0).toDouble(),
            entryPrice: (j['entry_price'] ?? 0).toDouble(),
            stopLoss: (j['stop_loss'] ?? 0).toDouble(),
            takeProfit: (j['take_profit'] ?? 0).toDouble(),
            exitPrice: (j['exit_price'] ?? 0).toDouble(),
            profitLossUsd: (j['profit_loss_usd'] ?? 0).toDouble(),
            rrMultiple: (j['rr_multiple'] ?? 0).toDouble(),
            emotions: j['emotions'] ?? '',
            analysisNotes: j['analysis_notes'] ?? '',
            chartImageUrl: j['chart_image_url'],
            teacherScore: j['teacher_score'],
            teacherFeedback: j['teacher_feedback'],
            firstName: p?['first_name'] ?? 'Unknown',
            lastName: p?['last_name'] ?? 'Scholar',
            email: p?['email'] ?? '',
            avatarUrl: p?['avatar_url'],
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error loading trading journals: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveEvaluation() async {
    if (selectedJournal == null) return;

    final scoreNum = int.tryParse(_scoreController.text.trim());

    setState(() => isSubmittingGrade = true);
    try {
      await supabase.from("trading_journals").update({
        'teacher_score': scoreNum,
        'teacher_feedback': _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
      }).eq("id", selectedJournal!.id);

      setState(() {
        journals = journals.map((item) {
          if (item.id == selectedJournal!.id) {
            return TradingJournalItem(
              id: item.id, studentId: item.studentId, tradeDate: item.tradeDate,
              symbol: item.symbol, positionType: item.positionType, setupStrategy: item.setupStrategy,
              lotSize: item.lotSize, entryPrice: item.entryPrice, stopLoss: item.stopLoss,
              takeProfit: item.takeProfit, exitPrice: item.exitPrice, profitLossUsd: item.profitLossUsd,
              rrMultiple: item.rrMultiple, emotions: item.emotions, analysisNotes: item.analysisNotes,
              chartImageUrl: item.chartImageUrl, teacherScore: scoreNum, teacherFeedback: _feedbackController.text.trim(),
              firstName: item.firstName, lastName: item.lastName, email: item.email, avatarUrl: item.avatarUrl,
            );
          }
          return item;
        }).toList();
        selectedJournal = null;
      });
    } catch (e) {
      debugPrint("Evaluation failed: $e");
    } finally {
      if (mounted) setState(() => isSubmittingGrade = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
    }

    // بررسی دسترسی استاد به دوره فارکس
    if (!hasAccess) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.purpleAccent, size: 40),
              const SizedBox(height: 12),
              const Text("Access Restricted", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                "The Trading Journal Audit system is exclusively available for instructors actively teaching the Financial Markets & Forex Trading masterclass.",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filteredJournals = journals.where((j) {
      final q = searchQuery.toLowerCase();
      return j.symbol.toLowerCase().contains(q) ||
          j.firstName.toLowerCase().contains(q) ||
          j.setupStrategy.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= هدر صفحه =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text("📈", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Trading Journals",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text("Audit student ledger submissions and verify risk compliance.",
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Search student, symbol...",
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ================= لیست ژورنال‌ها =================
          filteredJournals.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredJournals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final journal = filteredJournals[index];
                    bool isWin = journal.profitLossUsd >= 0;
                    bool isGraded = journal.teacherScore != null;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.purple.withOpacity(0.2),
                                    backgroundImage: journal.avatarUrl != null ? NetworkImage(journal.avatarUrl!) : null,
                                    child: journal.avatarUrl == null
                                        ? Text(journal.firstName[0], style: const TextStyle(color: Colors.purpleAccent, fontSize: 10))
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text("${journal.firstName} ${journal.lastName}",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isGraded ? Colors.purple.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(isGraded ? "Audited (${journal.teacherScore})" : "Pending Audit",
                                    style: TextStyle(color: isGraded ? Colors.purpleAccent : Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(journal.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: journal.positionType.toUpperCase() == 'BUY' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(journal.positionType,
                                        style: TextStyle(color: journal.positionType.toUpperCase() == 'BUY' ? Colors.greenAccent : Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              Text(
                                isWin ? "+\$${journal.profitLossUsd}" : "-\$${journal.profitLossUsd.abs()}",
                                style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Lots: ${journal.lotSize} | R&R: ${journal.rrMultiple}R", style: const TextStyle(color: Colors.grey, fontSize: 9)),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.06),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedJournal = journal;
                                    _scoreController.text = journal.teacherScore?.toString() ?? "";
                                    _feedbackController.text = journal.teacherFeedback ?? "";
                                  });
                                },
                                child: const Text("Audit Trade", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a0f),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text("No trading journals found.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 30),

          // ================= مودال ممیزی معامله =================
          if (selectedJournal != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d0d14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.purple.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Audit Sheet: ${selectedJournal!.firstName} ${selectedJournal!.lastName}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text("Symbol: ${selectedJournal!.symbol} (${selectedJournal!.positionType})", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    Text("Entry: \$${selectedJournal!.entryPrice} | Exit: \$${selectedJournal!.exitPrice}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    const SizedBox(height: 10),
                    if (selectedJournal!.chartImageUrl != null) ...[
                      GestureDetector(
                        onTap: () => _launchURL(selectedJournal!.chartImageUrl!),
                        child: const Text("📊 View Chart Screenshot", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Text("Execution Score (0-100) *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _scoreController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: "Score (e.g. 95)",
                        hintStyle: TextStyle(color: Colors.grey.shade700),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Academic Audit Feedback", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: "Tactical feedback...",
                        hintStyle: TextStyle(color: Colors.grey.shade700),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.5),
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => selectedJournal = null),
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                            onPressed: isSubmittingGrade ? null : _saveEvaluation,
                            child: Text(isSubmittingGrade ? "Saving..." : "Save Audit", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}