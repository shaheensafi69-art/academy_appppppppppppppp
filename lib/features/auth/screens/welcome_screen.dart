import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // هدایت به صفحه لاگین پس از اتمام مراحل

class OnboardingItem {
  final String title;
  final String subtitle;
  final String imageAsset;
  final String emoji;

  OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.emoji,
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

  // لیست ۵ مرحله ویلکم اسکرین
  final List<OnboardingItem> _pages = [
    OnboardingItem(
      title: "Welcome to Safi Academy",
      subtitle: "Your premier gateway to mastering financial markets, software engineering, and modern digital business.",
      imageAsset: "assets/logo-without-b.png", // از لوگو یا عکس دلخواه استفاده کنید
      emoji: "🚀",
    ),
    OnboardingItem(
      title: "Live Campus & Interactive Hubs",
      subtitle: "Attend corporate Microsoft Teams lectures, sync with secure Signal operations, and check in to daily classes.",
      imageAsset: "assets/logo-without-b.png",
      emoji: "🔴",
    ),
    OnboardingItem(
      title: "Professional Trading Journal",
      subtitle: "Log your forex and crypto executions, manage risk, track R/R multiples, and build your edge like a pro.",
      imageAsset: "assets/logo-without-b.png",
      emoji: "📈",
    ),
    OnboardingItem(
      title: "Examination Center & Quizzes",
      subtitle: "Test your knowledge through descriptive academic exams, complete homework, and track your official grades.",
      imageAsset: "assets/logo-without-b.png",
      emoji: "🎯",
    ),
    OnboardingItem(
      title: "Earn & Grow Together",
      subtitle: "Invite friends using your unique referral code, earn instant cash bonuses, and unlock verified blockchain credentials.",
      imageAsset: "assets/logo-without-b.png",
      emoji: "💎",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // اتمام مراحل و رفتن به صفحه لاگین
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020202),
      body: Stack(
        children: [
          // هاله‌های نوری پس‌زمینه
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.amber.withOpacity(0.12), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // هدر بالای صفحه (دکمه Skip)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text("🎓", style: TextStyle(fontSize: 14)),
                          ),
                          const SizedBox(width: 8),
                          const Text("SAFI ACADEMY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                        ],
                      ),
                      if (_currentIndex < _pages.length - 1)
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text("Skip", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),

                // صفحات اسلایدر (PageView)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // قاب عکس یا آیکون بزرگ با استایل شیشه‌ای
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0a0a0f),
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(item.emoji, style: const TextStyle(fontSize: 64)),
                            ),
                            const SizedBox(height: 40),

                            // عنوان مرحله
                            Text(
                              item.title,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),

                            // توضیحات مرحله
                            Text(
                              item.subtitle,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // فوتر پایین صفحه (نشانگرهای دات و دکمه Next / Get Started)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // نشانگرهای صفحات (Dots Indicator)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentIndex == index ? Colors.amberAccent : Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // دکمه ادامه / ورود
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _onNext,
                          child: Text(
                            _currentIndex == _pages.length - 1 ? "Get Started 🚀" : "Continue",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}