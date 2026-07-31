import 'package:flutter/material.dart';

// --- صفحه لاگین ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Login Screen 🔐', style: TextStyle(color: Colors.white))));
  }
}

// --- پنل ادمین ---
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Admin Portal 👑', style: TextStyle(color: Colors.white))));
  }
}

// --- پنل استاد ---
class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Teacher Portal 👨‍🏫', style: TextStyle(color: Colors.white))));
  }
}

// --- پنل دانش‌آموز ---
class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Student Dashboard 🎓', style: TextStyle(color: Colors.white))));
  }
}