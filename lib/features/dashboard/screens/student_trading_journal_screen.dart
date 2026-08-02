import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// شناسه ثابت کورس فارکس
const String forexCourseId = "d9fa8678-76b4-4705-b579-7860407d43e8";

class JournalEntry {
  final String id;
  final String tradeDate;
  final String symbol;
  final String positionType; // "LONG" | "SHORT"
  final String? setupStrategy;
  final double? lotSize;
  final double entryPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double? exitPrice;
  final double? profitLossUsd;
  final double? rrMultiple;
  final String? emotions;
  final String? analysisNotes;
  final String? chartImageUrl;
  final String createdAt;

  JournalEntry({
    required this.id,
    required this.tradeDate,
    required this.symbol,
    required this.positionType,
    this.setupStrategy,
    this.lotSize,
    required this.entryPrice,
    this.stopLoss,
    this.takeProfit,
    this.exitPrice,
    this.profitLossUsd,
    this.rrMultiple,
    this.emotions,
    this.analysisNotes,
    this.chartImageUrl,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] ?? '',
      tradeDate: json['trade_date'] ?? '',
      symbol: json['symbol'] ?? '',
      positionType: json['position_type'] ?? 'LONG',
      setupStrategy: json['setup_strategy'],
      lotSize: json['lot_size']?.toDouble(),
      entryPrice: (json['entry_price'] ?? 0).toDouble(),
      stopLoss: json['stop_loss']?.toDouble(),
      takeProfit: json['take_profit']?.toDouble(),
      exitPrice: json['exit_price']?.toDouble(),
      profitLossUsd: json['profit_loss_usd']?.toDouble(),
      rrMultiple: json['rr_multiple']?.toDouble(),
      emotions: json['emotions'],
      analysisNotes: json['analysis_notes'],
      chartImageUrl: json['chart_image_url'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class StudentTradingJournalScreen extends StatefulWidget {
  const StudentTradingJournalScreen({super.key});

  @override
  State<StudentTradingJournalScreen> createState() => _StudentTradingJournalScreenState();
}

class _StudentTradingJournalScreenState extends State<StudentTradingJournalScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool hasAccess = false;
  List<JournalEntry> entries = [];
  String filter = "all"; // "all", "win", "loss", "open"

  bool isModalOpen = false;
  bool isSubmitting = false;
  XFile? chartFile;
  final ImagePicker _picker = ImagePicker();

  // فرم ثبت معامله
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _strategyController = TextEditingController();
  final TextEditingController _lotController = TextEditingController();
  final TextEditingController _entryController = TextEditingController();
  final TextEditingController _slController = TextEditingController();
  final TextEditingController _tpController = TextEditingController();
  final TextEditingController _exitController = TextEditingController();
  final TextEditingController _pnlController = TextEditingController();
  final TextEditingController _rrController = TextEditingController();
  final TextEditingController _emotionsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String positionType = "LONG";
  String tradeDate = DateTime.now().toIso8601String().split('T')[0];

  Map<String, dynamic> stats = {
    'totalTrades': 0,
    'winRate': 0,
    'totalProfitLoss': 0.0,
  };

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _checkAccessAndFetchJournal();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _strategyController.dispose();
    _lotController.dispose();
    _entryController.dispose();
    _slController.dispose();
    _tpController.dispose();
    _exitController.dispose();
    _pnlController.dispose();
    _rrController.dispose();
    _emotionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndFetchJournal() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // ۱. بررسی دسترسی به دوره فارکس
      final enrollment = await supabase
          .from("enrollments")
          .select("id")
          .eq("student_id", user.id)
          .eq("course_id", forexCourseId)
          .maybeSingle();

      if (enrollment == null) {
        setState(() {
          hasAccess = false;
          isLoading = false;
        });
        return;
      }

      setState(() => hasAccess = true);

      // ۲. واکشی اطلاعات ژورنال
      final journalData = await supabase
          .from("trading_journals")
          .select("*")
          .eq("student_id", user.id)
          .order("trade_date", ascending: false)
          .order("created_at", ascending: false);

      final formatted = (journalData as List).map((j) => JournalEntry.fromJson(j)).toList();

      int closedTrades = 0;
      int winningTrades = 0;
      double netProfitLoss = 0;

      for (var entry in formatted) {
        if (entry.profitLossUsd != null) {
          closedTrades++;
          netProfitLoss += entry.profitLossUsd!;
          if (entry.profitLossUsd! > 0) winningTrades++;
        }
      }

      setState(() {
        entries = formatted;
        stats = {
          'totalTrades': formatted.length,
          'winRate': closedTrades > 0 ? ((winningTrades / closedTrades) * 100).round() : 0,
          'totalProfitLoss': netProfitLoss,
        };
      });
        } catch (e) {
      debugPrint("Error fetching journal: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickChartImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => chartFile = image);
    }
  }

  Future<void> _handleAddTrade() async {
    if (_symbolController.text.trim().isEmpty || _entryController.text.trim().isEmpty) return;

    setState(() => isSubmitting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      String? uploadedChartUrl;
      if (chartFile != null) {
        final fileExt = chartFile!.name.split('.').last;
        final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final bytes = await chartFile!.readAsBytes();

        await supabase.storage.from('journal_charts').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        uploadedChartUrl = supabase.storage.from('journal_charts').getPublicUrl(fileName);
      }

      await supabase.from("trading_journals").insert({
        'student_id': user.id,
        'trade_date': tradeDate,
        'symbol': _symbolController.text.trim().toUpperCase(),
        'position_type': positionType,
        'setup_strategy': _strategyController.text.trim().isEmpty ? null : _strategyController.text.trim(),
        'lot_size': _lotController.text.trim().isEmpty ? null : double.parse(_lotController.text.trim()),
        'entry_price': double.parse(_entryController.text.trim()),
        'stop_loss': _slController.text.trim().isEmpty ? null : double.parse(_slController.text.trim()),
        'take_profit': _tpController.text.trim().isEmpty ? null : double.parse(_tpController.text.trim()),
        'exit_price': _exitController.text.trim().isEmpty ? null : double.parse(_exitController.text.trim()),
        'profit_loss_usd': _pnlController.text.trim().isEmpty ? null : double.parse(_pnlController.text.trim()),
        'rr_multiple': _rrController.text.trim().isEmpty ? null : double.parse(_rrController.text.trim()),
        'emotions': _emotionsController.text.trim().isEmpty ? null : _emotionsController.text.trim(),
        'analysis_notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'chart_image_url': uploadedChartUrl,
      });

      setState(() {
        isModalOpen = false;
        chartFile = null;
        _symbolController.clear();
        _strategyController.clear();
        _lotController.clear();
        _entryController.clear();
        _slController.clear();
        _tpController.clear();
        _exitController.clear();
        _pnlController.clear();
        _rrController.clear();
        _emotionsController.clear();
        _notesController.clear();
      });

      await _checkAccessAndFetchJournal();
    } catch (e) {
      debugPrint("Failed to add trade: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  List<JournalEntry> get filteredEntries {
    return entries.where((entry) {
      bool isOpen = entry.profitLossUsd == null;
      if (filter == "win") return !isOpen && entry.profitLossUsd! > 0;
      if (filter == "loss") return !isOpen && entry.profitLossUsd! < 0;
      if (filter == "open") return isOpen;
      return true;
    }).toList();
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
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("LOADING TRADING JOURNAL...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    // ==========================================
    // UI 1: اگر کاربر دسترسی نداشت
    // ==========================================
    if (!hasAccess) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 36),
                ),
                const SizedBox(height: 16),
                const Text("Access Restricted", style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                  "The Professional Trading Journal is an exclusive tool reserved strictly for students enrolled in the Financial Markets & Forex Trading masterclass.",
                  style: TextStyle(color: textGrey, fontSize: 11, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================
    // UI 2: اگر کاربر دسترسی داشت
    // ==========================================
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(Icons.show_chart_rounded, color: primaryPink, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Trading Journal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                          SizedBox(height: 3),
                          Text("Log your executions and track your edge.", style: TextStyle(fontSize: 10, color: textGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text("Log Trade", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    onPressed: () => setState(() => isModalOpen = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // آمار کلی ریسپانسیو
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NET PNL (USD)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text(
                          "${stats['totalProfitLoss'] >= 0 ? '+' : ''}\$${stats['totalProfitLoss'].toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: stats['totalProfitLoss'] >= 0 ? Colors.green.shade700 : Colors.redAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("WIN RATE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text("${stats['winRate']}%", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // تب‌های فیلتر
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterTab("all", "All Trades", Icons.list_alt_rounded),
                  const SizedBox(width: 10),
                  _buildFilterTab("open", "Open", Icons.hourglass_top_rounded),
                  const SizedBox(width: 10),
                  _buildFilterTab("win", "Wins", Icons.emoji_events_rounded),
                  const SizedBox(width: 10),
                  _buildFilterTab("loss", "Losses", Icons.trending_down_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // لیست معاملات
            filteredEntries.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      bool isOpen = entry.profitLossUsd == null;
                      bool isWin = !isOpen && entry.profitLossUsd! > 0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOpen ? Colors.amber.withOpacity(0.3) : isWin ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: entry.positionType == 'LONG' ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(entry.positionType, style: TextStyle(color: entry.positionType == 'LONG' ? Colors.green.shade700 : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(entry.symbol, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                  ],
                                ),
                                isOpen
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                        child: const Text("OPEN", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                      )
                                    : Text(
                                        "${isWin ? '+' : ''}\$${entry.profitLossUsd?.toStringAsFixed(2)}",
                                        style: TextStyle(color: isWin ? Colors.green.shade700 : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Entry: ${entry.entryPrice} | Exit: ${entry.exitPrice ?? 'Running'}", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                if (entry.chartImageUrl != null)
                                  GestureDetector(
                                    onTap: () => _launchURL(entry.chartImageUrl!),
                                    child: const Text("View Chart ↗", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
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
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No trades found matching this filter.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 30),

            // ================= مودال ثبت معامله جدید =================
            if (isModalOpen)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Log Execution", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: textGrey, size: 20),
                          onPressed: () => setState(() => isModalOpen = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInput("Pair / Symbol *", _symbolController, hint: "e.g. XAUUSD"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => positionType = "LONG"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: positionType == "LONG" ? Colors.green.withOpacity(0.15) : cardBorder,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: positionType == "LONG" ? Colors.green : cardBorder, width: 1.5),
                              ),
                              child: Text("LONG", style: TextStyle(color: positionType == "LONG" ? Colors.green.shade700 : textGrey, fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => positionType = "SHORT"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: positionType == "SHORT" ? Colors.red.withOpacity(0.15) : cardBorder,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: positionType == "SHORT" ? Colors.redAccent : cardBorder, width: 1.5),
                              ),
                              child: Text("SHORT", style: TextStyle(color: positionType == "SHORT" ? Colors.redAccent : textGrey, fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInput("Strategy / Setup", _strategyController, hint: "e.g. SMC, Breakout"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput("Lot Size", _lotController, hint: "0.10")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput("Entry Price *", _entryController, hint: "0.00")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput("Stop Loss", _slController, hint: "0.00")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput("Take Profit", _tpController, hint: "0.00")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput("Exit Price", _exitController, hint: "0.00")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput("Net PnL (\$)", _pnlController, hint: "150 or -50")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickChartImage,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBorder.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image_rounded, color: textGrey, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                chartFile != null ? chartFile!.name : "Upload Chart Screenshot (Optional)",
                                style: TextStyle(color: chartFile != null ? textDark : textGrey, fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting ? null : _handleAddTrade,
                        child: Text(isSubmitting ? "Saving..." : "Save Trade to Journal 🚀", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, IconData icon) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryPink : lightPinkBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryPink : cardBorder, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: primaryPink.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : primaryPink),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : textDark, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
          ),
        ),
      ],
    );
  }
}