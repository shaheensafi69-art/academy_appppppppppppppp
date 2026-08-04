import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const List<String> weekDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

class TeacherEditClassScreen extends StatefulWidget {
  final String classId;
  const TeacherEditClassScreen({super.key, required this.classId});

  @override
  State<TeacherEditClassScreen> createState() => _TeacherEditClassScreenState();
}

class _TeacherEditClassScreenState extends State<TeacherEditClassScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSubmitting = false;

  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _meetingLinkController = TextEditingController();
  final TextEditingController _signalLinkController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<String> selectedDays = [];
  bool isActive = true;

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
    _fetchData();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _scheduleController.dispose();
    _timeController.dispose();
    _meetingLinkController.dispose();
    _signalLinkController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from("class_groups")
          .select("class_name, schedule_info, start_date, end_date, meeting_link, signal_group_link, class_time, class_days, is_active")
          .eq("id", widget.classId)
          .single();

      _classNameController.text = data['class_name'] ?? '';
      _scheduleController.text = data['schedule_info'] ?? '';
      _timeController.text = data['class_time'] ?? '';
      _meetingLinkController.text = data['meeting_link'] ?? '';
      _signalLinkController.text = data['signal_group_link'] ?? '';
      _startDateController.text = data['start_date'] ?? '';
      _endDateController.text = data['end_date'] ?? '';
      isActive = data['is_active'] ?? true;

      if (data['class_days'] != null) {
        selectedDays = (data['class_days'] as String).split(", ").map((d) => d.trim()).toList();
      }
        } catch (e) {
      debugPrint("Error loading class config: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (selectedDays.contains(day)) {
        selectedDays.remove(day);
      } else {
        selectedDays.add(day);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_classNameController.text.trim().isEmpty) return;

    setState(() => isSubmitting = true);
    try {
      final daysString = selectedDays.join(", ");

      await supabase
          .from("class_groups")
          .update({
            'class_name': _classNameController.text.trim(),
            'schedule_info': _scheduleController.text.trim().isEmpty ? null : _scheduleController.text.trim(),
            'start_date': _startDateController.text.trim().isEmpty ? null : _startDateController.text.trim(),
            'end_date': _endDateController.text.trim().isEmpty ? null : _endDateController.text.trim(),
            'meeting_link': _meetingLinkController.text.trim().isEmpty ? null : _meetingLinkController.text.trim(),
            'signal_group_link': _signalLinkController.text.trim().isEmpty ? null : _signalLinkController.text.trim(),
            'class_time': _timeController.text.trim().isEmpty ? null : _timeController.text.trim(),
            'class_days': daysString,
            'is_active': isActive,
          })
          .eq("id", widget.classId);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Failed to update class: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: surfaceWhite,
        body: const Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: const Text("Class Settings", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // نام کلاس
            const Text("Classroom Name *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _classNameController,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: cardBorder.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // اطلاعات برنامه (Schedule Info)
            const Text("Schedule Information", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _scheduleController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "e.g. Evening Shift / Weekend Cohort",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // روزهای هفته
            const Text("Class Days *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weekDays.map((day) {
                bool isSelected = selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => _toggleDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? lightPinkBg : cardBorder.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? primaryPink : cardBorder, width: isSelected ? 1.5 : 1),
                    ),
                    child: Text(
                      day.substring(0, 3),
                      style: TextStyle(color: isSelected ? primaryPink : textDark, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ساعت کلاس
            const Text("Time *", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _timeController,
              style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g. 18:00 - 20:00",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // تاریخ شروع و پایان
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Start Date", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _startDateController,
                        style: const TextStyle(color: textDark, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          filled: true,
                          fillColor: cardBorder.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("End Date", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _endDateController,
                        style: const TextStyle(color: textDark, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
                          hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                          filled: true,
                          fillColor: cardBorder.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // لینک جلسه آنلاین
            const Text("Live Meeting Link", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _meetingLinkController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Zoom / Teams URL",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // لینک گروه پشتیبانی
            const Text("Support Group Link", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _signalLinkController,
              style: const TextStyle(color: textDark, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Signal / WhatsApp URL",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            // وضعیت فعال بودن کلاس
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.5),
              ),
              child: SwitchListTile(
                title: const Text("Cohort Broadcast Status", style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w900)),
                subtitle: const Text("Toggle whether students can see this stream active.", style: TextStyle(color: textGrey, fontSize: 10)),
                value: isActive,
                activeThumbColor: primaryPink,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => isActive = val),
              ),
            ),
            const SizedBox(height: 30),

            // دکمه ذخیره تنظیمات
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSubmitting ? null : _handleSubmit,
                child: Text(isSubmitting ? "Saving..." : "Save Configuration 🚀", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}