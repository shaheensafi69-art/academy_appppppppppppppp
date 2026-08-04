import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/auth_gate.dart';
import 'features/auth/screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isInitialized = false;
  try {
    await Supabase.initialize(
      url: 'https://enpuoypqpklndnnhndax.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucHVveXBxcGtsbmRubmhuZGF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzg1MjgsImV4cCI6MjA5ODY1NDUyOH0.slU2vYIzM0BXG_3ksR5pcfvP-cpFH7IkwIyuzF1pNCo',
    );
    isInitialized = true;
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(SafiAcademyApp(supabaseReady: isInitialized));
}

class SafiAcademyApp extends StatelessWidget {
  final bool supabaseReady;

  const SafiAcademyApp({super.key, required this.supabaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safi Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF020202),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: supabaseReady ? const AuthGate() : const WelcomeScreen(),
    );
  }
}