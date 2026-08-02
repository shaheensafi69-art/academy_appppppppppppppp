import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityLockScreen extends StatefulWidget {
  const SecurityLockScreen({super.key});

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final supabase = Supabase.instance.client;
  
  bool _isAuthenticating = false;
  String _pinInput = "";

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color textDark = Color(0xFF111827);
  static const Color surfaceWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      setState(() => _isAuthenticating = true);
      bool authenticated = await auth.authenticate(
        localizedAuthenticate: 'Please authenticate to access your portal',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        Navigator.pop(context, true); // تایید هویت موفق
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
          const SnackBar(content: Text("Incorrect PIN Code")),
        );
        setState(() => _pinInput = "");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 50, color: primaryPink),
            const SizedBox(height: 16),
            const Text("Enter Security PIN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool filled = index < _pinInput.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? primaryPink : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            // کیبورد عددی ساده
            for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', 'del']])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((val) {
                  if (val.isEmpty) return const SizedBox(width: 70, height: 70);
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.grey.shade100,
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
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _authenticateWithBiometrics,
              icon: const Icon(Icons.fingerprint, color: primaryPink),
              label: const Text("Use Fingerprint / FaceID", style: TextStyle(color: primaryPink, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}