import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central Ad Service managing non-intrusive Google AdMob ads for Feed & Reels
class AdService {
  AdService._privateConstructor();
  static final AdService instance = AdService._privateConstructor();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Non-intrusive frequency control
  static const int feedAdInterval = 5; // 1 ad every 5 user posts
  static const int reelsAdInterval = 7; // 1 ad every 7 reels

  /// Initialize Google Mobile Ads SDK safely
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[AdService] Mobile ads skipped: platform not Android or iOS');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Google Mobile Ads initialized successfully');
    } catch (e) {
      debugPrint('[AdService] Failed to initialize MobileAds: $e');
    }
  }

  /// Official Native Ad Unit ID with anti-ban protection (Google Test in Debug, Production in Release)
  String get nativeAdUnitId {
    if (kDebugMode) {
      // Official Google AdMob Native Test Unit to prevent "Invalid Traffic" account ban
      return 'ca-app-pub-3940256099942544/2247696110';
    }
    final envId = dotenv.env['ADMOB_FEED_AD_UNIT_ID'];
    if (envId != null && envId.isNotEmpty) return envId;
    return 'ca-app-pub-6551903544426492/4488573138';
  }

  /// Ad Unit ID for Feed Banner / Inline Ad
  String get feedBannerAdUnitId {
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Google Official Android Test Banner
      } else if (!kIsWeb && Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // Google Official iOS Test Banner
      }
    }
    final envId = dotenv.env['ADMOB_FEED_AD_UNIT_ID'];
    if (envId != null && envId.isNotEmpty) return envId;
    return 'ca-app-pub-6551903544426492/4488573138';
  }

  /// Ad Unit ID for Reels In-Stream / Sponsored Ad
  String get reelsAdUnitId {
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Google Official Android Test Ad Unit
      } else if (!kIsWeb && Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // Google Official iOS Test Ad Unit
      }
    }
    final envId = dotenv.env['ADMOB_REELS_AD_UNIT_ID'];
    if (envId != null && envId.isNotEmpty) return envId;
    return 'ca-app-pub-6551903544426492/4488573138';
  }

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
