import 'package:flutter/material.dart';
import 'login_screen.dart';   // هدایت به صفحه لاگین
import 'register_screen.dart'; // هدایت به صفحه ثبت‌نام (نام فایل ثبت‌نام خود را در صورت نیاز اینجا تنظیم کنید)

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

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  // لیست مراحل ویلکم اسکرین
  final List<OnboardingItem> _pages = [
    OnboardingItem(
      title: "Welcome to Safi Academy",
      subtitle: "Your premier gateway to mastering financial markets, software engineering, and modern digital business.",
      iconData: Icons.school_rounded,
    ),
    OnboardingItem(
      title: "Live Campus & Interactive Hubs",
      subtitle: "Attend corporate Microsoft Teams lectures, sync with secure Signal operations, and check in to daily classes.",
      iconData: Icons.live_tv_rounded,
    ),
    OnboardingItem(
      title: "Professional Trading Journal",
      subtitle: "Log your forex and crypto executions, manage risk, track R/R multiples, and build your edge like a pro.",
      iconData: Icons.trending_up_rounded,
    ),
    OnboardingItem(
      title: "Examination Center & Quizzes",
      subtitle: "Test your knowledge through descriptive academic exams, complete homework, and track your official grades.",
      iconData: Icons.assignment_turned_in_rounded,
    ),
    OnboardingItem(
      title: "Earn & Grow Together",
      subtitle: "Invite friends using your unique referral code, earn instant cash bonuses, and unlock verified blockchain credentials.",
      iconData: Icons.verified_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentIndex < _pages.length) {
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

  @override
  Widget build(BuildContext context) {
    // تعداد کل صفحات شامل اسلایدرها + ۱ صفحه نهایی لوگو و دکمه‌ها
    final int totalPages = _pages.length + 1;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: Column(
          children: [
            // هدر بالای صفحه (برند و دکمه Skip)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.school_rounded, color: primaryPink, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text("SAFI ACADEMY", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                    ],
                  ),
                  if (_currentIndex < totalPages - 1)
                    TextButton(
                      onPressed: _navigateToLogin,
                      child: const Text("Skip", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            // بدنه اصلی (PageView شامل مراحل و صفحه نهایی)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  // بررسی اینکه آیا صفحه نهایی است یا خیر
                  if (index == _pages.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // لوگوی بزرگ اکادمی در وسط صفحه
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [lightPinkBg, surfaceWhite],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(38),
                              border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
                              boxShadow: [
                                BoxShadow(color: primaryPink.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 12)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.school_rounded, size: 70, color: primaryPink),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            "Ready to Begin?",
                            style: TextStyle(color: textDark, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Log in to your account or create a new one to access elite training and live campus tools.",
                            style: TextStyle(color: textGrey, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // صفحات مراحل اسلایدر
                  final item = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: cardBorder, width: 2),
                            boxShadow: [
                              BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(item.iconData, size: 56, color: primaryPink),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          item.title,
                          style: const TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item.subtitle,
                          style: const TextStyle(color: textGrey, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // فوتر پایین صفحه (نشانگرهای دات و باکس دکمه‌ها)
            Padding(
              padding: const EdgeInsets.all(24.0),
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
                        width: _currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? primaryPink : cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // اگر در صفحه آخر بودیم، دو باکس دکمه زیبا (Login & Register) نمایش داده شود
                  if (_currentIndex == totalPages - 1) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _navigateToLogin, // دکمه لاگین -> هدایت به صفحه لاگین
                        child: const Text("Login to Account 🚀", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryPink,
                          side: const BorderSide(color: primaryPink, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _navigateToRegister, // دکمه ثبت‌نام -> هدایت به صفحه ریجستر
                        child: const Text("Create New Account", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                  ] else ...[
                    // دکمه Continue معمولی برای مراحل قبل
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _onNext,
                        child: const Text("Continue", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}