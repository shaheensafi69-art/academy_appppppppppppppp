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

      if (journalData != null) {
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
      }
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
        final fileExt = chartFile!.name.split('.').pop();
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
      return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
    }

    // ==========================================
    // UI 1: اگر کاربر دسترسی نداشت
    // ==========================================
    if (!hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.lock, color: Colors.redAccent, size: 36),
              ),
              const SizedBox(height: 16),
              const Text("Access Restricted", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                "The Professional Trading Journal is an exclusive tool reserved strictly for students enrolled in the Financial Markets & Forex Trading masterclass.",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ==========================================
    // UI 2: اگر کاربر دسترسی داشت
    // ==========================================
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر صفحه
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a0f),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Text("📈", style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Trading Journal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text("Log your executions and track your edge.", style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Log Trade", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  onPressed: () => setState(() => isModalOpen = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // آمار کلی
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: stats['totalProfitLoss'] >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: stats['totalProfitLoss'] >= 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NET PNL (USD)", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        "${stats['totalProfitLoss'] >= 0 ? '+' : ''}\$${stats['totalProfitLoss'].toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: stats['totalProfitLoss'] >= 0 ? Colors.greenAccent : Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("WIN RATE", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                      const SizedBox(height: 2),
                      Text("${stats['winRate']}%", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // تب‌های فیلتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterTab("all", "All", "📋"),
                const SizedBox(width: 8),
                _buildFilterTab("open", "Open", "⏳"),
                const SizedBox(width: 8),
                _buildFilterTab("win", "Wins", "🏆"),
                const SizedBox(width: 8),
                _buildFilterTab("loss", "Losses", "📉"),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    bool isOpen = entry.profitLossUsd == null;
                    bool isWin = !isOpen && entry.profitLossUsd! > 0;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0a0f).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isOpen ? Colors.amber.withOpacity(0.2) : isWin ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: entry.positionType == 'LONG' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(entry.positionType, style: TextStyle(color: entry.positionType == 'LONG' ? Colors.greenAccent : Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(entry.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                              isOpen
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                      child: const Text("OPEN", style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                    )
                                  : Text(
                                      "${isWin ? '+' : ''}\$${entry.profitLossUsd?.toStringAsFixed(2)}",
                                      style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Entry: ${entry.entryPrice} | Exit: ${entry.exitPrice ?? 'Running'}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                              if (entry.chartImageUrl != null)
                                GestureDetector(
                                  onTap: () => _launchURL(entry.chartImageUrl!),
                                  child: const Text("🖼️ View Chart", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
                  child: const Text("No trades found matching this filter.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
          const SizedBox(height: 30),

          // ================= مودال ثبت معامله جدید =================
          if (isModalOpen)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0d0d14),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Log Execution", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: () => setState(() => isModalOpen = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInput("Pair / Symbol *", _symbolController, hint: "e.g. XAUUSD"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => positionType = "LONG"),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: positionType == "LONG" ? Colors.green : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text("LONG", style: TextStyle(color: positionType == "LONG" ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => positionType = "SHORT"),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: positionType == "SHORT" ? Colors.red : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text("SHORT", style: TextStyle(color: positionType == "SHORT" ? Colors.white : Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInput("Strategy / Setup", _strategyController, hint: "e.g. SMC, Breakout"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInput("Lot Size", _lotController, hint: "0.10")),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput("Entry Price *", _entryController, hint: "0.00")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInput("Stop Loss", _slController, hint: "0.00")),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput("Take Profit", _tpController, hint: "0.00")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInput("Exit Price", _exitController, hint: "0.00")),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput("Net PnL (\$)", _pnlController, hint: "150 or -50")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickChartImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image, color: Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chartFile != null ? chartFile!.name : "Upload Chart Screenshot (Optional)",
                              style: TextStyle(color: chartFile != null ? Colors.white : Colors.grey, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting ? null : _handleAddTrade,
                      child: Text(isSubmitting ? "Saving..." : "Save Trade to Journal 🚀", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, String emoji) {
    bool isSelected = filter == id;
    return GestureDetector(
      onTap: () => setState(() => filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 10),
            filled: true,
            fillColor: Colors.black.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
        ),
      ],
    );
  }
}

extension on List<String> {
  Object? pop() {}
}