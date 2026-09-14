import 'package:flutter/material.dart';
import '../../../core/services/language_service.dart';
import '../../../core/widgets/language_selector_sheet.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../feed/screens/guest_feed_layout.dart';

class OnboardingItem {
  final String title;
  final String subtitle;
  final IconData iconData;

  OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.iconData,
  });
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // پالت رنگی پرمیوم و هماهنگ با دیزاین جدید
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  List<OnboardingItem> _getPages(BuildContext context) => [
    OnboardingItem(
      title: context.l10n.welcomeOnboarding1Title,
      subtitle: context.l10n.welcomeOnboarding1Desc,
      iconData: Icons.school_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding2Title,
      subtitle: context.l10n.welcomeOnboarding2Desc,
      iconData: Icons.dynamic_feed_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding3Title,
      subtitle: context.l10n.welcomeOnboarding3Desc,
      iconData: Icons.play_circle_fill_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding4Title,
      subtitle: context.l10n.welcomeOnboarding4Desc,
      iconData: Icons.forum_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding5Title,
      subtitle: context.l10n.welcomeOnboarding5Desc,
      iconData: Icons.live_tv_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding6Title,
      subtitle: context.l10n.welcomeOnboarding6Desc,
      iconData: Icons.trending_up_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding7Title,
      subtitle: context.l10n.welcomeOnboarding7Desc,
      iconData: Icons.assignment_turned_in_rounded,
    ),
    OnboardingItem(
      title: context.l10n.welcomeOnboarding8Title,
      subtitle: context.l10n.welcomeOnboarding8Desc,
      iconData: Icons.verified_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext(int totalPages) {
    if (_currentIndex < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _navigateToGuestFeed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuestFeedLayout()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages(context);
    final int totalPages = pages.length + 1;

    return Scaffold(
      body: Container(
        // پس‌زمینه گرادینت ملایم مشابه دیزاین مرجع
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFF0F5),
              surfaceWhite,
              lightPinkBg.withOpacity(0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // هدر بالای صفحه (برند، انتخاب زبان و دکمه Skip)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryPink.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: primaryPink,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "SAFI ACADEMY",
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // دکمه انتخاب زبان
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: primaryPink.withOpacity(0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryPink.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.language_rounded,
                              color: primaryPink,
                              size: 18,
                            ),
                          ),
                          onPressed: () => LanguageSelectorSheet.show(context),
                        ),
                        if (_currentIndex < totalPages - 1)
                          TextButton(
                            onPressed: _navigateToGuestFeed,
                            style: TextButton.styleFrom(foregroundColor: textGrey),
                            child: Text(
                              context.l10n.skipToFeed,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // بدنه اصلی (PageView)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    if (index == pages.length) {
                      // صفحه نهایی (Welcome / Login / Register)
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: primaryPink.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryPink.withOpacity(0.15),
                                    blurRadius: 35,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.school_rounded,
                                size: 64,
                                color: primaryPink,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              context.l10n.readyToBegin,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.readyToBeginDesc,
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 13,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // صفحات اسلایدر میانی
                    final item = pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(38),
                              border: Border.all(color: cardBorder, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryPink.withOpacity(0.08),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              item.iconData,
                              size: 60,
                              color: primaryPink,
                            ),
                          ),
                          const SizedBox(height: 44),
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 13,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // فوتر پایین صفحه (نشانگرها و دکمه‌ها)
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  children: [
                    // نشانگرهای صفحات (Dots Indicator)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalPages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentIndex == index ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? primaryPink
                                : cardBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // دکمه‌های صفحه آخر یا دکمه Continue مراحل
                    if (_currentIndex == totalPages - 1) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadowColor: primaryPink.withOpacity(0.4),
                          ),
                          onPressed: _navigateToLogin,
                          child: Text(
                            context.l10n.loginToAccount,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryPink,
                            side: const BorderSide(
                              color: primaryPink,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _navigateToRegister,
                          child: Text(
                            context.l10n.createNewAccount,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            color: lightPinkBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryPink.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _navigateToGuestFeed,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.explore_rounded,
                                      color: primaryPink,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.l10n.exploreFeedAsGuest,
                                      style: const TextStyle(
                                        color: textDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => _onNext(totalPages),
                          child: Text(
                            context.l10n.continueText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
