import 'dart:ui';
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

      if (data != null) {
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
        backgroundColor: const Color(0xFF030305),
        body: const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Class Settings", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Classroom Name *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _classNameController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Class Days *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: weekDays.map((day) {
                bool isSelected = selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => _toggleDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple.withOpacity(0.2) : Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(day.substring(0, 3), style: TextStyle(color: isSelected ? Colors.purpleAccent : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            const Text("Time *", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _timeController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Live Meeting Link", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _meetingLinkController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 12),

            const Text("Support Group Link", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _signalLinkController,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text("Cohort Broadcast Status", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              subtitle: Text("Toggle whether students can see this stream active.", style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
              value: isActive,
              activeColor: Colors.purple,
              onChanged: (val) => setState(() => isActive = val),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting ? null : _handleSubmit,
                child: Text(isSubmitting ? "Saving..." : "Save Configuration 🚀", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}