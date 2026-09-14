import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/services/ad_service.dart';

/// A non-intrusive in-feed Native Ad Card that matches Safi Academy post styling
class FeedAdCard extends StatefulWidget {
  const FeedAdCard({super.key});

  @override
  State<FeedAdCard> createState() => _FeedAdCardState();
}

class _FeedAdCardState extends State<FeedAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _hasError = false;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color surfaceWhite = Colors.white;
  static const Color cardBorder = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _initAd();
  }

  void _initAd() {
    // ۱. بررسی فوری استخر کش: آیا ادز از قبل در رم بارگذاری شده است؟
    final preloadedAd = AdService.instance.getPreloadedFeedAd();
    if (preloadedAd != null) {
      _nativeAd = preloadedAd;
      _isAdLoaded = true;
      return; // ⚡ بدون ۱ میلی‌ثانیه لودینگ رندر می‌شود!
    }

    // ۲. در صورتی که پلتفرم اندروید یا iOS باشد و هنوز در کش نباشد، تازه لود کن
    if (AdService.instance.isPlatformSupported) {
      _loadFreshNativeAd();
    }
  }

  void _loadFreshNativeAd() {
    final adUnitId = AdService.instance.nativeAdUnitId;
    if (adUnitId.isEmpty) return;

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 24.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: primaryPink,
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
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _hasError = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[FeedAdCard] Fresh ad failed to load: ${error.message} (Code: ${error.code})',
          );
          try {
            ad.dispose();
          } catch (_) {}
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _hasError = true;
            });
          }
        },
      ),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // اگر در پلتفرم دسکتاپ (مانند مک فعلی) یا وب هستیم، کارت پیش‌نمایش تمیز را نشان بده
    if (!AdService.instance.isPlatformSupported) {
      return _buildDesktopPreviewCard();
    }

    if (!_isAdLoaded || _nativeAd == null || _hasError) {
      // در صورت بروز خطا در حالت تست، پیش‌نمایش را نشان بده تا ساختار فید به‌هم نریزد
      if (AdService.useTestAdUnits) {
        return _buildDesktopPreviewCard();
      }
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Sponsor Badge + Google Ads tag
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryPink.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.campaign_rounded,
                        size: 14,
                        color: primaryPink,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Sponsored / آگهی",
                        style: TextStyle(
                          color: primaryPink,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  "Google Ads",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // In-feed Native Template Ad widget (rendered instantly with zero wait)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 320,
                minHeight: 320,
                maxWidth: 400,
                maxHeight: 360,
              ),
              child: AdWidget(ad: _nativeAd!),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// کارت پیش‌نمایش زیبا برای حالت تست روی دسکتاپ مک
  Widget _buildDesktopPreviewCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryPink.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.campaign_rounded, size: 14, color: primaryPink),
                    SizedBox(width: 4),
                    Text(
                      "Sponsored / آگهی حامی",
                      style: TextStyle(
                        color: primaryPink,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                "AdMob Native Preview",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    color: primaryPink,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Safi Academy Pro Trading",
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "safiacademy.org",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Access professional fintech courses, algorithmic trading, and certified educational resources.",
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {},
              child: const Text(
                "Learn More / مشاهده جزئیات",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
