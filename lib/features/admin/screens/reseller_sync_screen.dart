import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme_service.dart';

class ResellerSyncScreen extends StatefulWidget {
  const ResellerSyncScreen({super.key});

  @override
  State<ResellerSyncScreen> createState() => _ResellerSyncScreenState();
}

class _ResellerSyncScreenState extends State<ResellerSyncScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSyncing = false;
  int _totalProducts = 0;
  int _activeProducts = 0;
  int _inStockProducts = 0;
  String? _lastSyncTime;

  List<Map<String, dynamic>> _syncLogs = [];
  final TextEditingController _functionNameController =
      TextEditingController(text: 'sync-reseller-products');

  @override
  void initState() {
    super.initState();
    _loadStatsAndLogs();
  }

  @override
  void dispose() {
    _functionNameController.dispose();
    super.dispose();
  }

  Future<void> _loadStatsAndLogs() async {
    setState(() => _isLoading = true);
    try {
      // 1. آمار محصولات
      final productsRes = await supabase
          .from('reseller_products')
          .select('id, in_stock, is_active, last_synced_at');

      final List<Map<String, dynamic>> products =
          List<Map<String, dynamic>>.from(productsRes);
      _totalProducts = products.length;
      _activeProducts = products.where((p) => p['is_active'] == true).length;
      _inStockProducts = products.where((p) => p['in_stock'] == true).length;

      if (products.isNotEmpty) {
        final latest = products
            .map((p) => p['last_synced_at']?.toString())
            .where((d) => d != null && d.isNotEmpty)
            .toList();
        if (latest.isNotEmpty) {
          latest.sort();
          _lastSyncTime = latest.last;
        }
      }

      // 2. لاگ‌های سینک
      try {
        final logsRes = await supabase
            .from('reseller_sync_logs')
            .select('*')
            .order('synced_at', ascending: false)
            .limit(20);
        _syncLogs = List<Map<String, dynamic>>.from(logsRes);
      } catch (logErr) {
        debugPrint('Warning fetching sync logs: $logErr');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerEdgeFunctionSync() async {
    setState(() => _isSyncing = true);
    final functionName = _functionNameController.text.trim();

    try {
      debugPrint('Calling Supabase Edge Function: $functionName');
      FunctionResponse response;

      try {
        response = await supabase.functions.invoke(
          functionName,
          body: {'triggered_by': 'admin_mobile_app', 'timestamp': DateTime.now().toIso8601String()},
        );
      } catch (invokeErr) {
        // Fallback check if user named it 'reseller-sync' or 'sync_products'
        debugPrint('Primary function invocation failed: $invokeErr. Trying fallback...');
        response = await supabase.functions.invoke(
          'reseller-sync',
          body: {'triggered_by': 'admin_mobile_app'},
        );
      }

      debugPrint('Edge Function response: status=${response.status}, data=${response.data}');

      // لاگ در جدول لاگ‌ها در صورت نیاز
      try {
        await supabase.from('reseller_sync_logs').insert({
          'items_updated': (response.data is Map && response.data['items_updated'] != null)
              ? response.data['items_updated']
              : 0,
          'status': response.status == 200 ? 'success' : 'failed',
          'log_details': response.data ?? {'status': response.status},
          'synced_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.status == 200
                ? 'همگام‌سازی محصولات با موفقیت انجام شد! 🔄✅'
                : 'پاسخ سرور: وضعیت ${response.status}',
          ),
          backgroundColor: response.status == 200 ? Colors.green : Colors.orange,
        ),
      );

      await _loadStatsAndLogs();
    } catch (e) {
      debugPrint('Edge Function error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در فراخوانی ایج‌فانکشن: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.instance.current;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'همگام‌سازی محصولات (Edge Function)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _isLoading || _isSyncing ? null : _loadStatsAndLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: palette.primary,
              onRefresh: _loadStatsAndLogs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards Row
                    _buildStatsRow(palette),

                    const SizedBox(height: 20),

                    // Edge Function Trigger Box
                    _buildSyncTriggerCard(palette, isRtl),

                    const SizedBox(height: 24),

                    // Sync Logs Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تاریخچه لاگ‌های همگام‌سازی (Sync Logs)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_syncLogs.length} لاگ',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Logs List
                    if (_syncLogs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.history_rounded,
                                size: 40, color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            const Text(
                              'هنوز لاگی ثبت نشده است. دکمه همگام‌سازی را بزنید.',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _syncLogs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final log = _syncLogs[i];
                          return _buildLogCard(log, palette);
                        },
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow(LuxuryPalette palette) {
    return Row(
      children: [
        Expanded(
          child: _statItem(
            'کل محصولات',
            '$_totalProducts',
            Icons.inventory_2_rounded,
            palette.primary,
            palette,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statItem(
            'فعال در فروشگاه',
            '$_activeProducts',
            Icons.check_circle_rounded,
            Colors.green,
            palette,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statItem(
            'موجود در انبار',
            '$_inStockProducts',
            Icons.storefront_rounded,
            palette.secondary,
            palette,
          ),
        ),
      ],
    );
  }

  Widget _statItem(
    String title,
    String value,
    IconData icon,
    Color color,
    LuxuryPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTriggerCard(LuxuryPalette palette, bool isRtl) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: palette.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'همگام‌سازی با Supabase Edge Function',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'اجرای مستقیم ایج‌فانکشن جهت به‌روزرسانی قیمت‌ها و موجودی',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Function name input
          TextField(
            controller: _functionNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'نام Edge Function در سوپابیس',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              prefixIcon: Icon(Icons.code_rounded, color: palette.primary, size: 20),
              hintText: 'sync-reseller-products',
            ),
          ),
          const SizedBox(height: 16),
          if (_lastSyncTime != null) ...[
            Text(
              'آخرین سینک: $_lastSyncTime',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: palette.primary.withValues(alpha: 0.4),
              ),
              onPressed: _isSyncing ? null : _triggerEdgeFunctionSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _isSyncing ? 'در حال همگام‌سازی با سرور...' : 'شروع همگام‌سازی فوری (Run Sync)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, LuxuryPalette palette) {
    final status = log['status']?.toString() ?? 'unknown';
    final isSuccess = status == 'success';
    final itemsCount = log['items_updated'] ?? 0;
    final dateStr = log['synced_at']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSuccess
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check : Icons.error_outline,
              color: isSuccess ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضعیت: ${isSuccess ? "موفقیت‌آمیز" : "ناموفق"} ($itemsCount محصول به‌روز شد)',
                  style: TextStyle(
                    color: isSuccess ? Colors.green : Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
