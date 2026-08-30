import 'package:flutter/material.dart';
import '../../dashboard/screens/student_support_screen.dart';

/// صفحه پشتیبانی لایو مخصوص استاد - دقیقاً مشابه سیستم دانشجو
/// (درخواست لایو → اطلاع‌رسانی تلگرام → تحویل به ادمین)
class TeacherSupportScreen extends StatelessWidget {
  const TeacherSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentSupportScreen(requesterRole: 'teacher');
  }
}
