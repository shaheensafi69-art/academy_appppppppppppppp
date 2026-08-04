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
  bool isSubmittingGrade = false;
  String searchQuery = "";

  // مودال ممیزی
  TradingJournalItem? selectedJournal;
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();

  // پالت رنگی لایت (سفید صدفی و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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

      if ((forexClassGroups as List).isEmpty) {
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

      if ((classStudents as List).isEmpty) {
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
          .inFilter("student_id", studentIds)
          .order("trade_date", ascending: false);

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
      return const Center(child: CircularProgressIndicator(color: primaryPink));
    }

    // بررسی دسترسی استاد به دوره فارکس
    if (!hasAccess) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: primaryPink, size: 44),
              const SizedBox(height: 14),
              const Text("Access Restricted", style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                "The Trading Journal Audit system is exclusively available for instructors actively teaching the Financial Markets & Forex Trading masterclass.",
                style: TextStyle(color: textGrey, fontSize: 11),
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

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= هدر صفحه =================
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [surfaceWhite, lightPinkBg.withValues(alpha: 0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: primaryPink.withValues(alpha: 0.15), width: 1.5),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryPink.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.trending_up_rounded, color: primaryPink, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Trading Journals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                                SizedBox(height: 3),
                                Text("Audit student ledger submissions and verify risk compliance.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        onChanged: (val) => setState(() => searchQuery = val),
                        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "Search student, symbol, strategy...",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          prefixIcon: const Icon(Icons.search_rounded, color: primaryPink, size: 18),
                          filled: true,
                          fillColor: cardBorder.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ================= لیست ژورنال‌ها =================
                const Text("Student Trade Submissions", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),

                filteredJournals.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredJournals.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final journal = filteredJournals[index];
                          bool isWin = journal.profitLossUsd >= 0;
                          bool isGraded = journal.teacherScore != null;

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isGraded ? Colors.green.withValues(alpha: 0.3) : cardBorder,
                                width: 1.5,
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
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
                                          radius: 16,
                                          backgroundColor: lightPinkBg,
                                          backgroundImage: journal.avatarUrl != null ? NetworkImage(journal.avatarUrl!) : null,
                                          child: journal.avatarUrl == null
                                              ? Text(journal.firstName[0], style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold))
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text("${journal.firstName} ${journal.lastName}", style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isGraded ? Colors.green.withValues(alpha: 0.12) : lightPinkBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isGraded ? "Audited (${journal.teacherScore})" : "● Pending Audit",
                                        style: TextStyle(
                                          color: isGraded ? Colors.green.shade700 : primaryPink,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(journal.symbol, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: journal.positionType.toUpperCase() == 'BUY' ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            journal.positionType.toUpperCase(),
                                            style: TextStyle(
                                              color: journal.positionType.toUpperCase() == 'BUY' ? Colors.green.shade700 : Colors.redAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      isWin ? "+\$${journal.profitLossUsd.toStringAsFixed(2)}" : "-\$${journal.profitLossUsd.abs().toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: isWin ? Colors.green.shade700 : Colors.redAccent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Lots: ${journal.lotSize} | R&R: ${journal.rrMultiple}R", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryPink,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          selectedJournal = journal;
                                          _scoreController.text = journal.teacherScore?.toString() ?? "";
                                          _feedbackController.text = journal.teacherFeedback ?? "";
                                        });
                                      },
                                      child: const Text("Audit Trade", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
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
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.query_stats_rounded, size: 36, color: textGrey),
                            SizedBox(height: 10),
                            Text("No Trading Journals", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 4),
                            Text("No student trading ledgers found.", style: TextStyle(color: textGrey, fontSize: 10), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // ================= مودال ممیزی معامله =================
          if (selectedJournal != null)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: primaryPink.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: primaryPink.withValues(alpha: 0.1), blurRadius: 25, offset: const Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Audit Sheet: ${selectedJournal!.firstName} ${selectedJournal!.lastName}",
                        style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 10),
                    Text("Symbol: ${selectedJournal!.symbol} (${selectedJournal!.positionType})", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text("Entry: \$${selectedJournal!.entryPrice} | Exit: \$${selectedJournal!.exitPrice}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (selectedJournal!.chartImageUrl != null) ...[
                      GestureDetector(
                        onTap: () => _launchURL(selectedJournal!.chartImageUrl!),
                        child: const Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 16, color: Colors.blueAccent),
                            SizedBox(width: 6),
                            Text("View Chart Screenshot", style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text("Execution Score (0-100) *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _scoreController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Score (e.g. 95)",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        filled: true,
                        fillColor: cardBorder.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Academic Audit Feedback", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      style: const TextStyle(color: textDark, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Tactical feedback...",
                        hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                        filled: true,
                        fillColor: cardBorder.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: textGrey),
                            onPressed: () => setState(() => selectedJournal = null),
                            child: const Text("Cancel", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: isSubmittingGrade ? null : _saveEvaluation,
                            child: Text(isSubmittingGrade ? "Saving..." : "Save Audit", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
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