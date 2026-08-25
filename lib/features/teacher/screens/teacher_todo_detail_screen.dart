import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherTodoDetailScreen extends StatefulWidget {
  final Map<String, dynamic> todoItem;

  const TeacherTodoDetailScreen({super.key, required this.todoItem});

  @override
  State<TeacherTodoDetailScreen> createState() => _TeacherTodoDetailScreenState();
}

class _TeacherTodoDetailScreenState extends State<TeacherTodoDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isUpdating = false;

  late final TextEditingController _taskController;
  bool _isCompleted = false;
  DateTime? _selectedDueDate;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.todoItem['task_text'] ?? '');
    _isCompleted = widget.todoItem['is_completed'] ?? false;
    
    if (widget.todoItem['due_time'] != null) {
      _selectedDueDate = DateTime.tryParse(widget.todoItem['due_time']);
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _updateTask() async {
    setState(() => isUpdating = true);
    try {
      await supabase.from('teacher_todos').update({
        'task_text': _taskController.text.trim(),
        'is_completed': _isCompleted,
        'due_time': _selectedDueDate?.toIso8601String(),
      }).eq('id', widget.todoItem['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task updated successfully! ✅"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error updating task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update task."), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _deleteTask() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Are you sure you want to delete this task?", style: TextStyle(fontSize: 12, color: textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('teacher_todos').delete().eq('id', widget.todoItem['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task deleted."), backgroundColor: Colors.redAccent),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error deleting task: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.todoItem['created_at'] ?? 'N/A';
    
    // تشخیص وضعیت هشدار زمان
    bool isAlert = false;
    if (!_isCompleted && _selectedDueDate != null) {
      if (DateTime.now().isAfter(_selectedDueDate!.subtract(const Duration(hours: 2)))) {
        isAlert = true;
      }
    }

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        title: const Text("Task Details & Alert", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
        iconTheme: const IconThemeData(color: primaryPink),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isAlert ? Colors.amber.shade700 : cardBorder, width: isAlert ? 2 : 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAlert)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade700, width: 1),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "ALERT: This task is approaching its deadline or is overdue!",
                                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Text("Task Information", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _taskController,
                      maxLines: 4,
                      style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBorder.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // انتخابگر تاریخ و زمان سررسید
                    const Text("Due Date & Time", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBorder.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, color: primaryPink, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedDueDate != null
                                      ? _selectedDueDate.toString().split('.')[0]
                                      : "No due date set (Click to set)",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _selectedDueDate != null ? textDark : textGrey),
                                ),
                              ],
                            ),
                            if (_selectedDueDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _selectedDueDate = null),
                                child: const Icon(Icons.clear_rounded, size: 16, color: textGrey),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: _isCompleted,
                          activeColor: primaryPink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => setState(() => _isCompleted = val ?? false),
                        ),
                        const Text("Mark as Completed", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text("Created At: $createdAt", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isUpdating ? null : _updateTask,
                        child: isUpdating
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("UPDATE TASK 💾", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}