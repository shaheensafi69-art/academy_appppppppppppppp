import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../../features/feed/screens/reels_viewer_screen.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    // 1. دریافت لینک اولیه (در صورتی که برنامه با کلیک روی لینک باز شده باشد)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, navKey);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Initial link error: $e');
    }

    // 2. گوش دادن به لینک‌های دریافتی هنگام باز بودن یا در پس‌زمینه بودن برنامه
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri, navKey);
      },
      onError: (err) {
        debugPrint('[DeepLinkService] Stream error: $err');
      },
    );
  }

  void _handleUri(Uri uri, GlobalKey<NavigatorState> navKey) {
    debugPrint('[DeepLinkService] Handling incoming link: $uri');

    // الگوهای پشتیبانی‌شده:
    // https://www.safiacademy.org/en/feed/reels?id=<id>
    // https://safiacademy.org/en/feed/reels?id=<id>
    // https://www.safiacademy.org/en/feed/reels/<id>
    // https://safiacademy.org/reel/<id>
    // safiacademy://reels?id=<id>
    // safiacademy://reel/<id>

    String? reelId;

    // ۱. بررسی کوئری پارامتر id یا reel_id
    if (uri.queryParameters.containsKey('id') &&
        uri.queryParameters['id']!.trim().isNotEmpty) {
      reelId = uri.queryParameters['id']!.trim();
    } else if (uri.queryParameters.containsKey('reel_id') &&
        uri.queryParameters['reel_id']!.trim().isNotEmpty) {
      reelId = uri.queryParameters['reel_id']!.trim();
    }

    // ۲. بررسی بخش‌های آدرس (path segments)
    if (reelId == null || reelId.isEmpty) {
      if (uri.pathSegments.contains('reels')) {
        final index = uri.pathSegments.indexOf('reels');
        if (index + 1 < uri.pathSegments.length) {
          reelId = uri.pathSegments[index + 1];
        }
      } else if (uri.pathSegments.contains('reel')) {
        final index = uri.pathSegments.indexOf('reel');
        if (index + 1 < uri.pathSegments.length) {
          reelId = uri.pathSegments[index + 1];
        }
      } else if (uri.host == 'reel' || uri.host == 'reels') {
        if (uri.pathSegments.isNotEmpty) {
          reelId = uri.pathSegments.first;
        }
      }
    }

    final isReelsTarget = uri.pathSegments.contains('reels') ||
        uri.pathSegments.contains('reel') ||
        uri.host == 'reel' ||
        uri.host == 'reels';

    if (reelId != null && reelId.isNotEmpty) {
      debugPrint('[DeepLinkService] Navigating to target Reel: $reelId');
      navKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => StudentReelsScreen(targetReelId: reelId),
        ),
      );
    } else if (isReelsTarget) {
      debugPrint('[DeepLinkService] Navigating to general Reels Feed');
      navKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const StudentReelsScreen(),
        ),
      );
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
