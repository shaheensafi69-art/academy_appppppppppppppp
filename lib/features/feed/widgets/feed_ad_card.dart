import 'dart:io';
import 'package:flutter/foundation.dart';
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
    _loadNativeAd();
  }

  void _loadNativeAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    final adUnitId = AdService.instance.nativeAdUnitId;
    if (adUnitId.isEmpty) return;

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 20.0,
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
          debugPrint('[FeedAdCard] Native ad failed to load: ${error.message}');
          ad.dispose();
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
    if (!_isAdLoaded || _nativeAd == null || _hasError) {
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

          // In-feed Native Template Ad widget
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
}
