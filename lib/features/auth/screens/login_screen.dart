import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/auth_gate.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool isSearching = false;
  bool showPassword = false;
  bool rememberMe = false;
  String? errorMsg;

  Map<String, dynamic>? userData;
  Timer? _debounce;

  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  // پالت رنگی پرمیوم و لایت آکادمی
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.04),
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatController.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // جستجوی هوشمند پروفایل کاربر به محض وارد کردن ایمیل
  void _onEmailChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (!query.contains("@") || !query.contains(".")) {
      setState(() => userData = null);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => isSearching = true);
      try {
        final data = await supabase
            .from('profiles')
            .select('first_name, last_name, avatar_url, role')
            .eq('email', query.toLowerCase().trim())
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            userData = data;
          });
        } else {
          setState(() => userData = null);
        }
      } catch (_) {
        setState(() => userData = null);
      } finally {
        if (mounted) setState(() => isSearching = false);
      }
    });
  }

  // ==========================================
  // 🔒 بررسی تایید ایمیل قبل از اجازه ورود
  // ==========================================
  Future<void> _handleLogin() async {
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => errorMsg = "Please enter both email and password.");
      return;
    }

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );

      final user = authResponse.user;

      if (user != null) {
        // بررسی اینکه آیا ایمیل کاربر توسط سوپابیس تایید شده است یا خیر
        // (حساب‌هایی که تازه ثبت‌نام کرده‌اند اما روی لینک ایمیل کلیک نکرده‌اند emailConfirmedAtشان null است)
        final bool isEmailVerified = user.emailConfirmedAt != null;

        if (!isEmailVerified) {
          // اگر تایید نشده بود، از حساب خارجش می‌کنیم تا نتواند وارد شود
          await supabase.auth.signOut();
          
          setState(() {
            errorMsg = "Please verify your email address before signing in.\nلطفاً قبل از ورود، ایمیل خود را تایید کنید.";
            isLoading = false;
          });
          return;
        }

        // اگر ایمیل تایید شده بود، اجازه ورود به داشبورد را می‌دهیم
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthGate()),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() {
        errorMsg = e.message;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = "Network connection failed. Please check your internet connection.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 850;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  surfaceWhite,
                  lightPinkBg.withOpacity(0.35),
                  surfaceWhite,
                ],
              ),
            ),
            child: Row(
              children: [
                // Form Container
                Expanded(
                  flex: 1,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Header Logo
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: lightPinkBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: primaryPink.withOpacity(0.18), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryPink.withOpacity(0.12),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo-without-b.png',
                                height: 56,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.school_rounded,
                                  size: 56,
                                  color: primaryPink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Welcome Title
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Welcome Back",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.auto_awesome_rounded, color: primaryPink, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Step into your digital campus.",
                              style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 24),

                            // Main Login Card
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: surfaceWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorder, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryPink.withOpacity(0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Error Message Banner
                                  if (errorMsg != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.2),
                                      ),
                                      child: Text(
                                        errorMsg!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, height: 1.4, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],

                                  // User Avatar Preview & Detected Role Badge when Email Matched
                                  if (userData != null) ...[
                                    Center(
                                      child: Column(
                                        children: [
                                          Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 28,
                                                backgroundColor: lightPinkBg,
                                                backgroundImage: (userData!['avatar_url'] != null &&
                                                        userData!['avatar_url'].toString().isNotEmpty)
                                                    ? NetworkImage(userData!['avatar_url'])
                                                    : null,
                                                child: (userData!['avatar_url'] == null ||
                                                        userData!['avatar_url'].toString().isEmpty)
                                                    ? Text(
                                                        userData!['first_name']?[0] ?? 'U',
                                                        style: const TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 18),
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "${userData!['first_name'] ?? ''} ${userData!['last_name'] ?? ''}",
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: lightPinkBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: primaryPink.withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  (userData!['role'] ?? 'student').toString().toUpperCase(),
                                                  style: const TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Email Field
                                  _buildTextField(
                                    controller: emailCtrl,
                                    label: "EMAIL ADDRESS",
                                    hint: "Enter your email",
                                    onChanged: _onEmailChanged,
                                    suffixIcon: isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Password Field
                                  _buildTextField(
                                    controller: passwordCtrl,
                                    label: "PASSWORD",
                                    hint: "••••••••",
                                    isPassword: true,
                                    showPassword: showPassword,
                                    onTogglePassword: () => setState(() => showPassword = !showPassword),
                                    extraLabel: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                        );
                                      },
                                      child: const Text("Forgot?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryPink)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Remember Me Checkbox Row
                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: primaryPink, width: 1.5),
                                          ),
                                          child: Theme(
                                            data: ThemeData(
                                              checkboxTheme: CheckboxThemeData(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                                side: BorderSide.none,
                                              ),
                                            ),
                                            child: Checkbox(
                                              value: rememberMe,
                                              activeColor: primaryPink,
                                              checkColor: Colors.white,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              onChanged: (val) {
                                                setState(() => rememberMe = val ?? false);
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Remember me',
                                        style: TextStyle(fontSize: 12, color: textGrey, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Sign In Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryPink,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      onPressed: isLoading ? null : _handleLogin,
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                            )
                                          : const Text(
                                              "SIGN IN",
                                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                                            ),
                                    ),
                                  ),

                                  // Register Link
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("New here? ", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500)),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                        ),
                                        child: const Text("Create account", style: TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Column (Desktop Banner & Typewriter Text)
                if (isDesktop)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [lightPinkBg.withOpacity(0.5), surfaceWhite],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: SlideTransition(
                              position: _floatAnimation,
                              child: Image.network(
                                'https://i.ibb.co/HTZ6DPsS/original-33b8479c324a5448d6145b3cad7c51e7-removebg-preview.png',
                                width: 420,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.school_outlined,
                                  size: 140,
                                  color: primaryPink,
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            bottom: 60,
                            left: 40,
                            right: 40,
                            child: TypewriterText(
                              text: "“Welcome back. Enter your credentials to access your global learning ecosystem.”",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    Function(String)? onChanged,
    Widget? suffixIcon,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onTogglePassword,
    Widget? extraLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
            ?extraLabel,
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          obscureText: isPassword && !showPassword,
          cursorColor: primaryPink,
          style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withOpacity(0.4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: textGrey,
                      size: 18,
                    ),
                    onPressed: onTogglePassword,
                  )
                : suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// Typewriter Text Effect Widget
// ==========================================
class TypewriterText extends StatefulWidget {
  final String text;
  const TypewriterText({super.key, required this.text});

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String displayedText = "";
  int charIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (charIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            displayedText += widget.text[charIndex];
            charIndex++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          displayedText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111827), fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        const Text("— Safi Ecosystem Core", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFC2185B), letterSpacing: 2)),
      ],
    );
  }
}