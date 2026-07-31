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
      resizeToAvoidBottomInset: false, // جلوگیری از به هم ریختن صفحه و اسکرول ناخواسته
      body: Stack(
        children: [
          // پس‌زمینه کهکشانی پویا
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.6),
                radius: 1.5,
                colors: [
                  Color(0xFF2A0845),
                  Color(0xFF100B29),
                  Color(0xFF020202),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: StarryBackgroundPainter(),
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
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/logo-without-b.png', height: 40),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Welcome Back", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                              SizedBox(width: 6),
                              Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text("Step into your digital campus.", style: TextStyle(color: Colors.white60, fontSize: 10)),
                          const SizedBox(height: 14),

                          // Role Tabs
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                _buildRoleTab("Student", "student", Colors.amber),
                                _buildRoleTab("Instructor", "teacher", Colors.blueAccent),
                                _buildRoleTab("Admin", "super_admin", Colors.purpleAccent),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // فرم شیشه‌ای کاملاً فیکس و بدون اسکرول
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0a0a0f).withOpacity(0.6),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (errorMsg != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.15), 
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                                        ),
                                        child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                      ),

                                    if (userData != null) ...[
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.black,
                                        backgroundImage: userData!['avatar_url'] != null && userData!['avatar_url'].toString().isNotEmpty 
                                            ? NetworkImage(userData!['avatar_url']) 
                                            : null,
                                        child: (userData!['avatar_url'] == null || userData!['avatar_url'].toString().isEmpty)
                                            ? Text(userData!['first_name']?[0] ?? 'U', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)) 
                                            : null,
                                      ),
                                      const SizedBox(height: 4),
                                      Text("Welcome, ${userData!['first_name'] ?? ''}!", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                      const SizedBox(height: 10),
                                    ],

                                    _buildTextField(
                                      controller: emailCtrl,
                                      label: "EMAIL ADDRESS",
                                      hint: "Enter your email",
                                      onChanged: _onEmailChanged,
                                      suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)) : null,
                                    ),
                                    const SizedBox(height: 10),

                                    _buildTextField(
                                      controller: passwordCtrl,
                                      label: "PASSWORD",
                                      hint: "••••••••",
                                      isPassword: true,
                                      showPassword: showPassword,
                                      onTogglePassword: () => setState(() => showPassword = !showPassword),
                                      extraLabel: GestureDetector(
                                        onTap: () {},
                                        child: const Text("Forgot?", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                                      )
                                    ),
                                    const SizedBox(height: 16),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _getRoleColor(selectedRoleTab),
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: isLoading ? null : _handleLogin,
                                        child: isLoading
                                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                                            : const Text("SIGN IN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                                      ),
                                    ),

                                    if (selectedRoleTab == 'student') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text("New here? ", style: TextStyle(color: Colors.white60, fontSize: 10)),
                                          GestureDetector(
                                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                            child: const Text("Create account", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
                                          ),
                                        ],
                                      )
                                    ]
                                  ],
                                ),
                              ),
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
                  child: Stack(
                    children: [
                      Center(
                        child: SlideTransition(
                          position: _floatAnimation,
                          child: Image.network(
                            'https://i.ibb.co/HTZ6DPsS/original-33b8479c324a5448d6145b3cad7c51e7-removebg-preview.png',
                            width: 380,
                          ),
                        ),
                      ),
                    ],
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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1.2)),
            ?extraLabel,
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            onChanged: onChanged,
            obscureText: isPassword && !showPassword,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 16),
                      onPressed: onTogglePassword,
                    )
                  : suffixIcon,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Colors.amber, width: 1.5)),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)
            ),
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
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: isActive ? Colors.black : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    if (role == 'super_admin') return Colors.purpleAccent;
    if (role == 'teacher') return Colors.lightBlueAccent;
    return Colors.amber;
  }
}

class StarryBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.1), 1.5, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 2.0, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.6), 1.0, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.8), 2.5, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 1.5, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.9), 1.0, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}