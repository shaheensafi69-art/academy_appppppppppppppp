import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityLockScreen extends StatefulWidget {
  const SecurityLockScreen({super.key});

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  // استفاده مستقیم از پکیج اصلی بدون تداخل
  final LocalAuthentication auth = LocalAuthentication();
  final supabase = Supabase.instance.client;
  
  bool _isAuthenticating = false;
  String _pinInput = "";

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color surfaceWhite = Colors.white;
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    try {
      setState(() => _isAuthenticating = true);
      
      bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access your portal securely',
        biometricOnly: false,
      );

      if (authenticated && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_pinInput.length < 4) {
        _pinInput += number;
        if (_pinInput.length == 4) {
          _verifyPin(_pinInput);
        }
      }
    });
  }

  Future<void> _verifyPin(String pin) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final res = await supabase
          .from('student_security_settings')
          .select('pin_code')
          .eq('student_id', user.id)
          .maybeSingle();

      if (res != null && res['pin_code'] == pin) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incorrect PIN Code ❌"), backgroundColor: Colors.red),
          );
          setState(() => _pinInput = "");
        }
      }
    } catch (e) {
      debugPrint("PIN verification error: $e");
      setState(() => _pinInput = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lightPinkBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.lock_rounded, size: 36, color: primaryPink),
              ),
              const SizedBox(height: 16),
              const Text("Security Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
              const SizedBox(height: 4),
              const Text("Enter your 4-digit PIN to continue", style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),

              // پین‌کد دات‌ها
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  bool filled = index < _pinInput.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: filled ? 18 : 14,
                    height: filled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? primaryPink : cardBorder,
                      border: Border.all(
                        color: filled ? primaryPink : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              // کیپد شماره‌گیر
              for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', 'del']])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: row.map((val) {
                      if (val.isEmpty) return const SizedBox(width: 70, height: 70);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: SizedBox(
                          width: 65,
                          height: 65,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: cardBorder,
                              foregroundColor: textDark,
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (val == 'del') {
                                if (_pinInput.isNotEmpty) {
                                  setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
                                }
                              } else {
                                _onNumberPressed(val);
                              }
                            },
                            child: val == 'del'
                                ? const Icon(Icons.backspace_rounded, color: textDark, size: 20)
                                : Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),

              TextButton.icon(
                onPressed: _authenticateWithBiometrics,
                icon: const Icon(Icons.fingerprint_rounded, color: primaryPink),
                label: const Text("Use Fingerprint / FaceID", style: TextStyle(color: primaryPink, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}