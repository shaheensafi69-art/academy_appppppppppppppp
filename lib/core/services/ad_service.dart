import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central Ad Service managing background preloading and non-intrusive Google AdMob ads for Feed & Reels
class AdService {
  AdService._privateConstructor();
  static final AdService instance = AdService._privateConstructor();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Non-intrusive frequency control
  static const int feedAdInterval = 3; // 1 ad every 3 user posts
  static const int reelsAdInterval = 5; // 1 ad every 5 reels

  // استخر کش تبلیغات برای نمایش فوری بدون معطلی و بدون لودینگ
  final List<NativeAd> _feedAdPool = [];
  final List<NativeAd> _reelsAdPool = [];
  bool _isLoadingFeedAd = false;
  bool _isLoadingReelsAd = false;

  static const int maxPoolSize = 2;

  /// Check if the platform supports mobile ads
  bool get isPlatformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initialize Google Mobile Ads SDK safely and start preloading immediately
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!isPlatformSupported) {
      debugPrint('[AdService] Mobile ads skipped: platform not Android or iOS');
      return;
    }

    try {
      await MobileAds.instance.initialize();

      // ثبت شناسه دستگاه تستی توسعه‌دهنده جهت نمایش امن تبلیغات تستی روی دستگاه شما
      // گوگل ادموب روی این دستگاه تبلیغ تستی می‌دهد و در پروداکشن برای بقیه کاربران تبلیغات واقعی و درآمدزا پخش می‌کند
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['6a39eaef-a912-4bd9-af60-926f848b5573'],
        ),
      );

      _isInitialized = true;
      debugPrint(
        '[AdService] Google Mobile Ads initialized successfully (Test Device ID registered)',
      );

      // 🔥 به محض بالا آمدن برنامه، ادز را در بکگراند لود کن تا کاربر بدون لودینگ آن را ببیند
      preloadAds();
    } catch (e) {
      debugPrint('[AdService] Failed to initialize MobileAds: $e');
    }
  }

  /// Start background preloading for both Feed and Reels
  void preloadAds() {
    preloadFeedAd();
    preloadReelsAd();
  }

  /// Preload a Native Ad for Feed into memory ahead of time
  void preloadFeedAd() {
    if (!isPlatformSupported) return;
    if (_feedAdPool.length >= maxPoolSize || _isLoadingFeedAd) return;

    final unitId = nativeAdUnitId;
    if (unitId.isEmpty) return;

    _isLoadingFeedAd = true;
    debugPrint('[AdService] ⏳ Preloading Feed Native Ad in background...');

    final ad = NativeAd(
      adUnitId: unitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 24.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFF494AC),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1E293B),
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF64748B),
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
      ),
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(
          startMuted: true,
          clickToExpandRequested: true,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (loadedAd) {
          debugPrint(
            '[AdService] ✅ Feed Native Ad preloaded & ready in memory!',
          );
          _feedAdPool.add(loadedAd as NativeAd);
          _isLoadingFeedAd = false;
          if (_feedAdPool.length < maxPoolSize) {
            preloadFeedAd();
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint(
            '[AdService] ❌ Failed to preload Feed Native Ad: ${error.message} (Code: ${error.code})',
          );
          try {
            failedAd.dispose();
          } catch (_) {}
          _isLoadingFeedAd = false;
        },
      ),
    );

    ad.load();
  }

  /// Get a preloaded Feed ad immediately (0ms delay) and replenish the pool
  NativeAd? getPreloadedFeedAd() {
    if (_feedAdPool.isNotEmpty) {
      final ad = _feedAdPool.removeAt(0);
      debugPrint(
        '[AdService] ⚡ Consumed preloaded Feed ad from memory. Remaining: ${_feedAdPool.length}',
      );
      // بلافاصله ادز بعدی را در پس‌زمینه بارگذاری کن تا استخر پر بماند
      preloadFeedAd();
      return ad;
    }
    // اگر خالی بود، فوراً درخواست لود بفرست
    preloadFeedAd();
    return null;
  }

  /// Preload a Native Ad for Reels into memory ahead of time
  void preloadReelsAd() {
    if (!isPlatformSupported) return;
    if (_reelsAdPool.length >= maxPoolSize || _isLoadingReelsAd) return;

    final unitId = nativeAdUnitId;
    if (unitId.isEmpty) return;

    _isLoadingReelsAd = true;
    debugPrint('[AdService] ⏳ Preloading Reels Native Ad in background...');

    final ad = NativeAd(
      adUnitId: unitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: const Color(0xFF1E293B),
        cornerRadius: 24.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFF494AC),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF94A3B8),
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
      ),
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(
          startMuted: false,
          clickToExpandRequested: true,
        ),
        mediaAspectRatio: MediaAspectRatio.any,
      ),
      listener: NativeAdListener(
        onAdLoaded: (loadedAd) {
          debugPrint(
            '[AdService] ✅ Reels Native Ad preloaded & ready in memory!',
          );
          _reelsAdPool.add(loadedAd as NativeAd);
          _isLoadingReelsAd = false;
          if (_reelsAdPool.length < maxPoolSize) {
            preloadReelsAd();
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint(
            '[AdService] ❌ Failed to preload Reels Native Ad: ${error.message} (Code: ${error.code})',
          );
          try {
            failedAd.dispose();
          } catch (_) {}
          _isLoadingReelsAd = false;
        },
      ),
    );

    ad.load();
  }

  /// Get a preloaded Reels ad immediately (0ms delay) and replenish the pool
  NativeAd? getPreloadedReelsAd() {
    if (_reelsAdPool.isNotEmpty) {
      final ad = _reelsAdPool.removeAt(0);
      debugPrint(
        '[AdService] ⚡ Consumed preloaded Reels ad from memory. Remaining: ${_reelsAdPool.length}',
      );
      preloadReelsAd();
      return ad;
    }
    preloadReelsAd();
    return null;
  }

  // آیدی‌های رسمی و تضمینی تست Google AdMob (همیشه با ۱۰۰٪ Fill Rate بدون معطلی لود می‌شوند)
  static const String testNativeAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const String testNativeAdUnitIdIOS =
      'ca-app-pub-3940256099942544/3986624511';

  // آیدی اصلی و اختصاصی درآمدزایی حساب شما
  static const String prodNativeAdUnitId =
      'ca-app-pub-6551903544426492/4488573138';

  /// متغیر کنترل حالت تست یا اصلی
  static bool? _overrideUseTestAdUnits;
  static bool get useTestAdUnits {
    if (_overrideUseTestAdUnits != null) {
      return _overrideUseTestAdUnits!;
    }
    final envVal = dotenv.env['ADMOB_USE_TEST_ADS'];
    if (envVal != null) {
      return envVal.trim().toLowerCase() == 'true';
    }
    // به صورت پیش‌فرض فعال است تا تست‌ها بدون خطای No fill اجرا شوند
    return true;
  }

  static set useTestAdUnits(bool value) {
    _overrideUseTestAdUnits = value;
  }

  /// Official Native Ad Unit ID for Feed & Reels
  /// در صورت فعال بودن useTestAdUnits، از کلید تضمینی تست گوگل با لود ۱۰۰٪ استفاده می‌شود
  /// در غیر این صورت از کلید اصلی جهت کسب درآمد دلاری استفاده می‌شود
  String get nativeAdUnitId {
    if (useTestAdUnits) {
      if (!kIsWeb && Platform.isIOS) {
        return testNativeAdUnitIdIOS;
      }
      return testNativeAdUnitIdAndroid;
    }
    final envId = dotenv.env['ADMOB_FEED_AD_UNIT_ID'];
    if (envId != null && envId.isNotEmpty) return envId;
    return prodNativeAdUnitId;
  }

  /// Ad Unit ID for Feed Banner / Inline Ad
  String get feedBannerAdUnitId => nativeAdUnitId;

  /// Ad Unit ID for Reels In-Stream / Sponsored Ad
  String get reelsAdUnitId => nativeAdUnitId;

  /// Helper to calculate total count with ads interleaved every [interval] items
  int calculateTotalCount(int rawItemCount, int interval) {
    if (rawItemCount == 0 || interval <= 0) return 0;
    final adCount = rawItemCount ~/ interval;
    return rawItemCount + adCount;
  }

  /// Check if the index is an Ad slot
  bool isAdPosition(int index, int interval) {
    if (interval <= 0 || index < interval) return false;
    return (index + 1) % (interval + 1) == 0;
  }

  /// Map raw index (ignoring ad slots) from a combined index
  int getRawItemIndex(int index, int interval) {
    if (interval <= 0) return index;
    final adCountBefore = (index + 1) ~/ (interval + 1);
    return index - adCountBefore;
  }
}
