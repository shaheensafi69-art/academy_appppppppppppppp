import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentClassDetailScreen extends StatelessWidget {
  final Map<String, dynamic> classData;
  final bool isPaid;

  const StudentClassDetailScreen({
    super.key,
    required this.classData,
    required this.isPaid,
  });

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);
  
  Object? get model => null;

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = classData['class_name'] ?? 'Class Details';
    final scheduleInfo = classData['schedule_info'] ?? 'No schedule info';
    final startDate = classData['start_date'] ?? 'TBD';
    final endDate = classData['end_date'] ?? 'TBD';
    final classTime = classData['class_time'] ?? '';
    final classDays = classData['class_days'] ?? '';
    final meetingLink = classData['meeting_link'];
    final signalLink = classData['signal_group_link'];
    
    final teacherObj = classData['teacher'];
    final teacherName = teacherObj is Map ? "${teacherObj['first_name'] ?? ''} ${teacherObj['last_name'] ?? ''}" : 'Faculty Instructor';

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: const Text("Class Hub & Details", style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بنر لوکس کلاس با افکت‌های مدرن
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -15,
                    bottom: -15,
                    child: Icon(Icons.school_rounded, size: 110, color: Colors.white.withOpacity(0.12)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPaid ? "ENROLLED & ACTIVE ✓" : "PAYMENT PENDING",
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        className,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "Instructor: $teacherName",
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // مشخصات کامل کلاس
            const Text("Class Specifications", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.schedule_rounded, "Schedule Info", scheduleInfo),
                  const Divider(height: 20, color: cardBorder),
                  _buildInfoRow(Icons.date_range_rounded, "Duration", "$startDate to $endDate"),
                  if (classTime.isNotEmpty) ...[
                    const Divider(height: 20, color: cardBorder),
                    _buildInfoRow(Icons.access_time_rounded, "Class Time", classTime),
                  ],
                  if (classDays.isNotEmpty) ...[
                    const Divider(height: 20, color: cardBorder),
                    _buildInfoRow(Icons.calendar_view_week_rounded, "Class Days", classDays),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // دکمه‌های دسترسی بی‌نظیر و مدرن
            const Text("Access Channels", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 12),
            isPaid
                ? Column(
                    children: [
                      if (meetingLink != model && meetingLink != null)
                        _buildActionCard(
                          title: "Join Teams Lecture Room",
                          subtitle: "Connect instantly to live corporate session",
                          icon: Icons.video_call_rounded,
                          color: const Color(0xFFD32F2F),
                          isElevated: true,
                          onTap: () => _launchURL(meetingLink),
                        ),
                      if (meetingLink != null && signalLink != null) const SizedBox(height: 12),
                      if (signalLink != null)
                        _buildActionCard(
                          title: "Open Signal Encrypted Group",
                          subtitle: "Secure messaging & operational updates",
                          icon: Icons.message_rounded,
                          color: primaryPink,
                          isElevated: false,
                          onTap: () => _launchURL(signalLink),
                        ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lightPinkBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.lock_rounded, color: primaryPink, size: 24),
                        SizedBox(height: 8),
                        Text(
                          "Class rooms and links are locked until tuition payment is verified by the administration.",
                          style: TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.w900, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: primaryPink, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  // ویجت دکمه اکشن فوق‌العاده شیک و زیبا
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isElevated,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isElevated ? color : surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isElevated ? color : cardBorder, width: 1.5),
            boxShadow: isElevated
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isElevated ? Colors.white.withOpacity(0.2) : lightPinkBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: isElevated ? Colors.white : primaryPink, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isElevated ? Colors.white : textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isElevated ? Colors.white70 : textGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isElevated ? Colors.white70 : textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}