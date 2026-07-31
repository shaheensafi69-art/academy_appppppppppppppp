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
      backgroundColor: surfaceWhite,
      resizeToAvoidBottomInset: false, // جلوگیری از به هم ریختن صفحه هنگام باز شدن کیبورد
      body: Stack(
        children: [
          // پس‌زمینه لایت مدرن با افکت گرادیان ملایم صورتی
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
              // Left Column (Form - Fixed Layout بدون نیاز به اسکرول)
              Expanded(
                flex: 1,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: lightPinkBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.asset('assets/logo-without-b.png', height: 34),
                          ),
                          const SizedBox(height: 12),
                          const Text("Create Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          const Text("Join Safi Academy digital ecosystem.", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 18),

                          // Step Indicators
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

                          // Clean Light Card Form
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryPink.withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: successMsg != null
                                ? _buildSuccessView()
                                : _buildFormSteps(),
                          ),
                          
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account? ", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text("Sign In", style: TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 11)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Right Column (Visual / Desktop Only)
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
                              width: 450,
                            ),
                          ),
                        ),
                        const Positioned(
                          bottom: 60,
                          left: 40,
                          right: 40,
                          child: TypewriterText(
                            text: "“Create an account. A new chapter awaits in global digital architecture.”",
                          ),
                        ),
                      ],
                    ),
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
      height: 5,
      width: isActive ? 28 : 14,
      decoration: BoxDecoration(
        color: isActive ? primaryPink : cardBorder,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 52),
        const SizedBox(height: 12),
        const Text("Registration Complete!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
        const SizedBox(height: 6),
        Text(successMsg!, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 18),
        const CircularProgressIndicator(color: primaryPink),
      ],
    );
  }

  Widget _buildFormSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errorMsg != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
            ),
            child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
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
                    radius: 34,
                    backgroundColor: lightPinkBg,
                    backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                    child: _photoFile == null ? const Icon(Icons.camera_alt_rounded, color: primaryPink, size: 24) : null,
                  ),
                  if (_photoFile == null)
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 12),
                    )
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                            colorScheme: const ColorScheme.light(
                              primary: primaryPink,
                              onPrimary: Colors.white,
                              surface: surfaceWhite,
                              onSurface: textDark,
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

        const SizedBox(height: 18),
        Row(
          children: [
            if (step > 1)
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardBorder,
                      foregroundColor: textDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: cardBorder, width: 1.5),
                    ),
                    onPressed: _prevStep,
                    child: const Text("BACK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ),
            if (step > 1) const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isLoading ? null : (step < 3 ? _nextStep : _handleRegister),
                  child: isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(step < 3 ? "NEXT STEP" : "COMPLETE 🚀", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !(showObscure ?? false),
          maxLines: maxLines,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBorder.withOpacity(0.5),
            contentPadding: maxLines > 1 ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: isPassword
                ? IconButton(icon: Icon((showObscure ?? false) ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textGrey, size: 16), onPressed: onToggleObscure)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
            hintText: hint,
            hintStyle: const TextStyle(color: textGrey, fontSize: 10),
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827), fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        const Text("— Safi Ecosystem Core", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFC2185B), letterSpacing: 2)),
      ],
    );
  }
}