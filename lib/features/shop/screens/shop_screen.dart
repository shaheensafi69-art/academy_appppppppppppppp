import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/language_service.dart';
import '../../../core/theme/app_theme_service.dart';
import '../widgets/shop_ad_banner.dart';
import 'product_checkout_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late String _activeCurrency;

  @override
  void initState() {
    super.initState();
    final langCode = LanguageService.instance.currentLanguage.code;
    _activeCurrency = CurrencyService.instance.getCurrencyForLanguage(langCode);
    CurrencyService.instance.fetchLiveRates().then((_) {
      if (mounted) setState(() {});
    });
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('reseller_products')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(res);
      if (loaded.isEmpty) {
        loaded = _getDemoProducts();
      }
      if (mounted) {
        setState(() {
          _products = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reseller_products: $e');
      if (mounted) {
        setState(() {
          _products = _getDemoProducts();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getDemoProducts() {
    final lang = LanguageService.instance.currentLanguage.code;
    final isEn = lang == 'en';
    return [
      {
        'id': 'demo-prod-1',
        'name': isEn
            ? 'Algorithmic Smart Trading Bot VIP Pro'
            : 'پکیج ربات معامله‌گر هوشمند الگوریتمی Pro VIP',
        'category': 'Trading Bots',
        'description': isEn
            ? 'Official AI trading algorithm with automatic risk management, 78%+ win-rate, compatible with MetaTrader 4/5 and TradingView.'
            : 'ربات هوشمند اختصاصی معاملاتی با سیستم مدیریت سرمایه خودکار، وین ریت بالای ۷۸٪ و اتصال به متاتریدر و تریدینگ‌ویو.',
        'selling_price': 149.0,
        'cost_price': 100.0,
        'in_stock': true,
        'currency': 'USD',
      },
      {
        'id': 'demo-prod-2',
        'name': isEn
            ? 'Golden Signals & Technical Analysis (6-Month)'
            : 'اشتراک سیگنال و تحلیل تکنیکال طلایی ۶ ماهه',
        'category': 'Signals',
        'description': isEn
            ? 'Exclusive access to VIP signals for Gold, Forex, and Crypto with precision entry/exit targets and direct mentor consultations.'
            : 'دسترسی اختصاصی به کانال تحلیلی طلا، فارکس و کریپتو با گزارش مدیریت ریسک و نقاط ورود دقیق با اساتید اکادمی.',
        'selling_price': 89.0,
        'cost_price': 60.0,
        'in_stock': true,
        'currency': 'USD',
      },
      {
        'id': 'demo-prod-3',
        'name': isEn
            ? 'Ultra Low-Latency Dedicated Forex VPS'
            : 'سرور مجازی پرسرعت اختصاصی تریدینگ (VPS Forex)',
        'category': 'VPS & Servers',
        'description': isEn
            ? 'Dedicated German & UK servers with sub-1ms ping to major brokers, 16GB RAM, 100% uptime guarantee for Expert Advisors.'
            : 'سرور اختصاصی آلمان و بریتانیا با پینگ زیر ۱ میلی‌ثانیه، رم ۱۶ گیگابایت و آی‌پی ثابت تضمینی جهت اجرای ربات‌های اکسپرت.',
        'selling_price': 35.0,
        'cost_price': 25.0,
        'in_stock': true,
        'currency': 'USD',
      },
      {
        'id': 'demo-prod-4',
        'name': isEn
            ? 'TradingView Premium Annual License Key'
            : 'لایسنس سالانه رسمی TradingView پرمیوم',
        'category': 'Accounts',
        'description': isEn
            ? 'Verified annual activation for TradingView Premium with unlimited indicators, 8-chart layouts, and second-based intervals.'
            : 'فعالسازی رسمی و قانونی اکانت یکساله تریدینگ ویو پریمیوم با اندیکاتورهای نامحدود، چیدمان ۸ نمودار همزمان و بدون تبلیغات.',
        'selling_price': 199.0,
        'cost_price': 140.0,
        'in_stock': true,
        'currency': 'USD',
      },
      {
        'id': 'demo-prod-5',
        'name': isEn
            ? 'Master Trader Financial Hardware Key'
            : 'کیف پول سخت‌افزاری تریدر فوق‌حرفه‌ای',
        'category': 'Educational Gear',
        'description': isEn
            ? 'Certified hardware security token with biometric protection for crypto assets, cold-storage backup, and official manufacturer warranty.'
            : 'کیف پول سخت‌افزاری با استانداردهای نظامی امنیت، حفاظت بایومتریک و بکاپ سرد مخصوص دارایی‌های دیجیتال با ضمانت اصالت.',
        'selling_price': 129.0,
        'cost_price': 90.0,
        'in_stock': false,
        'currency': 'USD',
      },
    ];
  }

  List<String> get _categories {
    final Set<String> cats = {'All'};
    for (final p in _products) {
      final cat = p['category']?.toString();
      if (cat != null && cat.isNotEmpty) {
        cats.add(cat);
      }
    }
    return cats.toList();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final matchesCat =
          _selectedCategory == 'All' || p['category'] == _selectedCategory;
      final q = _searchQuery.toLowerCase().trim();
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q) || desc.contains(q);
      return matchesCat && matchesQuery;
    }).toList();
  }

  // Multilingual labels for Shop
  String _t(String key) {
    final lang = LanguageService.instance.currentLanguage.code;
    final isEn = lang == 'en';
    final isAr = lang == 'ar' || lang == 'ur';

    switch (key) {
      case 'title':
        if (isEn) return 'Reseller Shop';
        if (isAr) return 'متجر المنتجات';
        return 'فروشگاه ریسیلر';
      case 'subtitle':
        if (isEn) return 'Verified Educational Gear & Official Licenses';
        if (isAr) return 'منتجات تعليمية وتراخيص رسمية موثقة';
        return 'تجهیزات، لایسنس‌ها و ابزارهای تاییدشده';
      case 'search_hint':
        if (isEn) return 'Search products, tools & licenses...';
        if (isAr) return 'البحث عن المنتجات والتراخيص...';
        return 'جستجوی محصولات، ابزارها و لایسنس‌ها...';
      case 'all':
        if (isEn) return 'All';
        if (isAr) return 'الكل';
        return 'همه';
      case 'in_stock':
        if (isEn) return 'In Stock';
        if (isAr) return 'متوفر';
        return 'موجود در انبار';
      case 'out_of_stock':
        if (isEn) return 'Out of Stock';
        if (isAr) return 'غير متوفر';
        return 'ناموجود';
      case 'details_order':
        if (isEn) return 'View & Order';
        if (isAr) return 'تفاصيل وشراء';
        return 'مشاهده و سفارش';
      case 'verified_badge':
        if (isEn) return 'Verified Official Partner';
        if (isAr) return 'شريك رسمي معتمد';
        return 'تامین‌کننده رسمی آکادمی صافی';
      case 'no_products':
        if (isEn) return 'No products found';
        if (isAr) return 'لم يتم العثور على منتجات';
        return 'محصولی یافت نشد';
      case 'currency_title':
        if (isEn) return 'Select Display Currency';
        if (isAr) return 'اختر عملة العرض';
        return 'انتخاب ارز نمایش قیمت‌ها';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.instance.current;
    final isDark = palette.isDark;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
            color: textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: palette.gradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              _t('title'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Currency Selector Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: InkWell(
              onTap: _showCurrencyPickerSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _activeCurrency,
                      style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: palette.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: palette.primary,
        onRefresh: _fetchProducts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Search Bar & Subtitle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment:
                      isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('subtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Search box
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _t('search_hint'),
                          hintStyle: TextStyle(
                            color: textSecondary.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: palette.primary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Categories List
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final isSelected = cat == _selectedCategory;
                          final label = cat == 'All' ? _t('all') : cat;

                          return InkWell(
                            onTap: () => setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.primary
                                    : palette.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? palette.primary
                                      : palette.cardBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Google AdMob Shop Banner
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ShopAdBanner(),
              ),
            ),

            // Products Grid / List
            if (_isLoading)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.primary),
                  ),
                ),
              )
            else if (_filteredProducts.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 60,
                        color: textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('no_products'),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product, palette, isRtl);
                    },
                    childCount: _filteredProducts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    LuxuryPalette palette,
    bool isRtl,
  ) {
    final name = product['name']?.toString() ?? 'Product';
    final desc = product['description']?.toString() ?? '';
    final cat = product['category']?.toString() ?? 'Gear';
    final sellingPrice = (product['selling_price'] as num?)?.toDouble() ?? 0.0;
    final inStock = product['in_stock'] == true;
    final isDark = palette.isDark;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    final localPriceFormatted =
        CurrencyService.instance.format(sellingPrice, _activeCurrency);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openProductCheckout(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    // Category Pill
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // In Stock Indicator
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: inStock
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3.5,
                            backgroundColor: inStock ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            inStock ? _t('in_stock') : _t('out_of_stock'),
                            style: TextStyle(
                              color: inStock ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Title & Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment:
                      isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Price & Order Button Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(
                    top: BorderSide(color: palette.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    // Price Column (USD + Converted Local Currency)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isRtl
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${sellingPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'USD',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '≈ $localPriceFormatted',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Order / View Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        elevation: 3,
                        shadowColor: palette.primary.withValues(alpha: 0.3),
                      ),
                      onPressed: () => _openProductCheckout(product),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        _t('details_order'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProductCheckout(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCheckoutScreen(
          product: product,
          initialCurrency: _activeCurrency,
        ),
      ),
    );
  }

  void _showCurrencyPickerSheet() {
    final palette = AppThemeService.instance.current;
    const currencies = CurrencyService.supportedCurrencies;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: palette.cardBorder),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.textSecondary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('currency_title'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: currencies.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: palette.cardBorder, height: 1),
                        itemBuilder: (c, idx) {
                          final curInfo = currencies[idx];
                          final cur = curInfo.code;
                          final isSelected = cur == _activeCurrency;
                          final curName = curInfo.nameEn;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(
                              '$cur - $curName (${curInfo.symbol})',
                              style: TextStyle(
                                color: isSelected
                                    ? palette.primary
                                    : palette.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: palette.primary)
                                : null,
                            onTap: () {
                              setState(() => _activeCurrency = cur);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
