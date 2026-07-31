import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/auth_gate.dart';
import 'register_screen.dart';

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
  String? errorMsg;
  String selectedRoleTab = 'student';

  Map<String, dynamic>? userData;
  Timer? _debounce;

  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.05),
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
            final role = data['role'] as String?;
            if (role != null) {
              if (role == 'admin' || role == 'super_admin') {
                selectedRoleTab = 'super_admin';
              } else if (role == 'teacher' || role == 'mentor') {
                selectedRoleTab = 'teacher';
              } else {
                selectedRoleTab = 'student';
              }
            }
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

  Future<void> _handleLogin() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );

      if (authResponse.session != null) {
        final profileResponse = await supabase
            .from('profiles')
            .select('role')
            .eq('id', authResponse.session!.user.id)
            .maybeSingle();

        final finalRole = profileResponse?['role'] ?? 'student';

        bool isMatched = false;
        if (selectedRoleTab == 'super_admin' && (finalRole == 'admin' || finalRole == 'super_admin')) {
          isMatched = true;
        } else if (selectedRoleTab == 'teacher' && (finalRole == 'teacher' || finalRole == 'mentor')) {
          isMatched = true;
        } else if (selectedRoleTab == 'student' && finalRole == 'student') {
          isMatched = true;
        }

        if (!isMatched && finalRole != 'super_admin') {
          await supabase.auth.signOut();
          setState(() {
            errorMsg = "Access Denied: Role mismatch ($finalRole).";
            isLoading = false;
          });
          return;
        }

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
        errorMsg = "Connection failed. Check network permissions.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: surfaceWhite,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // پس‌زمینه لایت مدرن با گرادیان ملایم صورتی
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  surfaceWhite,
                  lightPinkBg.withOpacity(0.3),
                  surfaceWhite,
                ],
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // لوگوی بزرگ‌شده با طراحی شیک و مدرن
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Image.asset('assets/logo-without-b.png', height: 64),
                          ),
                          const SizedBox(height: 18),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Welcome Back", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                              SizedBox(width: 8),
                              Icon(Icons.auto_awesome_rounded, color: primaryPink, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text("Step into your digital campus.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 20),

                          // Role Tabs
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cardBorder,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                _buildRoleTab("Student", "student", primaryPink),
                                _buildRoleTab("Instructor", "teacher", primaryPink),
                                _buildRoleTab("Admin", "super_admin", primaryPink),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // فرم شیشه‌ای و لایت کاملاً فیکس
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryPink.withOpacity(0.06),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (errorMsg != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                                    ),
                                    child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                                  ),

                                if (userData != null) ...[
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: lightPinkBg,
                                    backgroundImage: userData!['avatar_url'] != null && userData!['avatar_url'].toString().isNotEmpty 
                                        ? NetworkImage(userData!['avatar_url']) 
                                        : null,
                                    child: (userData!['avatar_url'] == null || userData!['avatar_url'].toString().isEmpty)
                                        ? Text(userData!['first_name']?[0] ?? 'U', style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 14)) 
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text("Welcome, ${userData!['first_name'] ?? ''}!", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark)),
                                  const SizedBox(height: 12),
                                ],

                                _buildTextField(
                                  controller: emailCtrl,
                                  label: "EMAIL ADDRESS",
                                  hint: "Enter your email",
                                  onChanged: _onEmailChanged,
                                  suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2)) : null,
                                ),
                                const SizedBox(height: 14),

                                _buildTextField(
                                  controller: passwordCtrl,
                                  label: "PASSWORD",
                                  hint: "••••••••",
                                  isPassword: true,
                                  showPassword: showPassword,
                                  onTogglePassword: () => setState(() => showPassword = !showPassword),
                                  extraLabel: GestureDetector(
                                    onTap: () {},
                                    child: const Text("Forgot?", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryPink)),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryPink,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: isLoading ? null : _handleLogin,
                                    child: isLoading
                                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                        : const Text("SIGN IN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                                  ),
                                ),

                                if (selectedRoleTab == 'student') ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("New here? ", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                        child: const Text("Create account", style: TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 11)),
                                      ),
                                    ],
                                  )
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

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
                    child: Center(
                      child: SlideTransition(
                        position: _floatAnimation,
                        child: Image.network(
                          'https://i.ibb.co/HTZ6DPsS/original-33b8479c324a5448d6145b3cad7c51e7-removebg-preview.png',
                          width: 420,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
            if (extraLabel != null) extraLabel,
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          obscureText: isPassword && !showPassword,
          style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textGrey, size: 16),
                    onPressed: onTogglePassword,
                  )
                : suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTab(String title, String role, Color activeColor) {
    bool isActive = selectedRoleTab == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRoleTab = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? surfaceWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isActive ? primaryPink : textGrey,
            ),
          ),
        ),
      ),
    );
  }
}