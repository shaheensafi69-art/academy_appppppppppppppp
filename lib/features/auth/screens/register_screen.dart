import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/auth_gate.dart';
final supabase = Supabase.instance.client;
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  
  // State Management
  int step = 1;
  bool isLoading = false;
  String? errorMsg;
  String? successMsg;
  bool showPassword = false;
  bool showConfirmPassword = false;
  
  File? _photoFile;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final fatherNameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  final refCodeCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

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
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    fatherNameCtrl.dispose();
    dobCtrl.dispose();
    countryCtrl.dispose();
    phoneCtrl.dispose();
    bioCtrl.dispose();
    refCodeCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _photoFile = File(pickedFile.path);
      });
    }
  }

  void _nextStep() {
    setState(() => errorMsg = null);
    if (step == 1) {
      if (_photoFile == null) {
        setState(() => errorMsg = "ID profile photo is required.");
        return;
      }
      if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty || fatherNameCtrl.text.isEmpty || dobCtrl.text.isEmpty) {
        setState(() => errorMsg = "Please fill in all personal details.");
        return;
      }
    } else if (step == 2) {
      if (countryCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
        setState(() => errorMsg = "Location and phone are required.");
        return;
      }
    }
    setState(() => step = (step < 3) ? step + 1 : 3);
  }

  void _prevStep() {
    setState(() {
      errorMsg = null;
      step = (step > 1) ? step - 1 : 1;
    });
  }

  Future<void> _handleRegister() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    if (passwordCtrl.text != confirmPasswordCtrl.text) {
      setState(() {
        errorMsg = "Passwords do not match.";
        isLoading = false;
      });
      return;
    }

    try {
      String? validReferrerId;

      if (refCodeCtrl.text.isNotEmpty) {
        final refData = await supabase
            .from('profiles')
            .select('id')
            .eq('referral_code', refCodeCtrl.text.trim().toUpperCase())
            .maybeSingle();
            
        if (refData == null) {
          throw "Invalid Referral Code. Check it or leave blank.";
        }
        validReferrerId = refData['id'];
      }

      final authResponse = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw "Failed to create secure user ID.";

      String avatarUrl = "";
      if (_photoFile != null) {
        final fileExt = _photoFile!.path.split('.').last;
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await supabase.storage.from('avatars').upload(fileName, _photoFile!);
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      await supabase.from('profiles').upsert({
        'id': userId,
        'first_name': firstNameCtrl.text.trim(),
        'last_name': lastNameCtrl.text.trim(),
        'father_name': fatherNameCtrl.text.trim(),
        'date_of_birth': dobCtrl.text.trim(),
        'country': countryCtrl.text.trim(),
        'phone_number': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'avatar_url': avatarUrl,
        'bio': bioCtrl.text.trim(),
        'role': 'student',
        'referred_by': validReferrerId,
      });

      if (validReferrerId != null) {
        await supabase.from('referrals').insert({
          'referrer_id': validReferrerId,
          'referred_student_id': userId,
          'reward_amount': 5,
          'is_paid': false,
        });
      }

      setState(() {
        successMsg = "Identity Verified! 🚀 Redirecting...";
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      });

    } catch (e) {
      setState(() => errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Pure Flutter Galaxy Background (بدون نیاز به عکس اینترنتی)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.6),
                radius: 1.5,
                colors: [
                  Color(0xFF2A0845), // Deep Purple
                  Color(0xFF100B29), // Dark Blue
                  Color(0xFF020202), // Pitch Black
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
              // Left Column (Form)
              Expanded(
                flex: 1,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Header (فشرده و شیک)
                          Image.asset('assets/logo-without-b.png', height: 45),
                          const SizedBox(height: 12),
                          const Text("Create Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          const Text("Join Safi Academy digital ecosystem.", style: TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 20),

                          // Step Indicators (نوار پیشرفت)
                          if (successMsg == null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStepDot(1),
                                _buildStepDot(2),
                                _buildStepDot(3),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Glassmorphism Form (کارت شیشه‌ای جمع‌وجور)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0a0a0f).withOpacity(0.5),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: -5,
                                    )
                                  ]
                                ),
                                child: successMsg != null
                                    ? _buildSuccessView()
                                    : _buildFormSteps(),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account? ", style: TextStyle(color: Colors.white60, fontSize: 11)),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text("Sign In", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Right Column (3D Astronaut - Desktop Only)
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
                            width: 500,
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 60,
                        left: 0,
                        right: 0,
                        child: TypewriterText(
                          text: "“Create an account. A new chapter awaits in global digital architecture.”",
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

  Widget _buildStepDot(int stepIndex) {
    bool isActive = step == stepIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 4,
      width: isActive ? 30 : 15,
      decoration: BoxDecoration(
        color: isActive ? Colors.amber : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
        const SizedBox(height: 12),
        const Text("Registration Complete!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        Text(successMsg!, style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: Colors.amber),
      ],
    );
  }

  Widget _buildFormSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errorMsg != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
            child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          )
        ],

        if (step == 1) ...[
          // Step 1: Avatar & Personal Info
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                    child: _photoFile == null ? const Icon(Icons.camera_alt, color: Colors.amber, size: 24) : null,
                  ),
                  if (_photoFile == null)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.black, size: 12),
                    )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField("FIRST NAME *", firstNameCtrl, "John")),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField("LAST NAME *", lastNameCtrl, "Doe")),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField("FATHER'S NAME *", fatherNameCtrl, "Michael")),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.amber,
                              onPrimary: Colors.black,
                              surface: Color(0xFF100B29),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => dobCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}");
                    }
                  },
                  child: AbsorbPointer(child: _buildTextField("DATE OF BIRTH *", dobCtrl, "YYYY-MM-DD")),
                ),
              ),
            ],
          ),
        ] else if (step == 2) ...[
          // Step 2: Location & Bio
          Row(
            children: [
              Expanded(child: _buildTextField("COUNTRY *", countryCtrl, "UK")),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField("PHONE *", phoneCtrl, "+44...", isPhone: true)),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField("BIOGRAPHY", bioCtrl, "Brief background...", maxLines: 2),
          const SizedBox(height: 10),
          _buildTextField("REFERRAL CODE (OPTIONAL)", refCodeCtrl, "e.g. SAFI-X"),
        ] else if (step == 3) ...[
          // Step 3: Account Security
          _buildTextField("EMAIL ADDRESS *", emailCtrl, "name@example.com"),
          const SizedBox(height: 10),
          _buildTextField("PASSWORD *", passwordCtrl, "••••••••", isPassword: true, showObscure: showPassword, onToggleObscure: () => setState(() => showPassword = !showPassword)),
          const SizedBox(height: 10),
          _buildTextField("CONFIRM PASSWORD *", confirmPasswordCtrl, "••••••••", isPassword: true, showObscure: showConfirmPassword, onToggleObscure: () => setState(() => showConfirmPassword = !showConfirmPassword)),
        ],

        const SizedBox(height: 24),
        Row(
          children: [
            if (step > 1)
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05), 
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.white.withOpacity(0.1))
                    ),
                    onPressed: _prevStep, // Corrected: Removed duplicate onPressed
                    child: const Text("BACK", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ),
            if (step > 1) const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, 
                    foregroundColor: Colors.black,
                    elevation: 8,
                    shadowColor: Colors.amber.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                  ),
                  onPressed: isLoading ? null : (step < 3 ? _nextStep : _handleRegister),
                  child: isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : Text(step < 3 ? "NEXT STEP" : "COMPLETE 🚀", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {bool isPassword = false, bool? showObscure, VoidCallback? onToggleObscure, int maxLines = 1, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        SizedBox(
          // فقط در صورتی که تک خطی است، ارتفاع را فیکس می‌کنیم تا فشرده بماند
          height: maxLines == 1 ? 48 : null, 
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && !(showObscure ?? false),
            maxLines: maxLines,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines == 1 ? 0 : 12),
              suffixIcon: isPassword
                  ? IconButton(icon: Icon((showObscure ?? false) ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18), onPressed: onToggleObscure)
                  : null,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.amber, width: 1.5)),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)
            ),
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
        setState(() {
          displayedText += widget.text[charIndex];
          charIndex++;
        });
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 6),
        const Text("— Safi Ecosystem Core", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 2)),
      ],
    );
  }
}

// ==========================================
// نقاش سفارشی برای کشیدن ستاره‌های پس‌زمینه
// ==========================================
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