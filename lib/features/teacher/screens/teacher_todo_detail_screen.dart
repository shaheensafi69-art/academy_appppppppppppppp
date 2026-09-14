import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n_extensions.dart';

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
      if (!mounted) return;
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
          SnackBar(content: Text(context.l10n.savedSuccessfully), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error updating task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedToSave), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _deleteTask() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.l10n.deleteTask, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
        content: Text(context.l10n.deleteTaskConfirm, style: const TextStyle(fontSize: 12, color: textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(context.l10n.cancel, style: const TextStyle(color: textGrey))),
          TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: Text(context.l10n.delete, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('teacher_todos').delete().eq('id', widget.todoItem['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.taskDeleted), backgroundColor: Colors.redAccent),
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
        title: Text(context.l10n.taskDetailsAndAlert, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16)),
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
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAlert)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade700, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.taskOverdueAlert,
                                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(context.l10n.taskInformation, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _taskController,
                      maxLines: 4,
                      style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBorder.withValues(alpha: 0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // انتخابگر تاریخ و زمان سررسید
                    Text(context.l10n.dueDateAndTime, style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBorder.withValues(alpha: 0.5),
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
                                      : context.l10n.noDueDateSet,
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
                        Text(context.l10n.markAsCompleted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text("${context.l10n.createdAtLabel}: $createdAt", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
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
                            : Text(context.l10n.updateTaskBtn, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
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