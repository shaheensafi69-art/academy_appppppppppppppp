import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'teacher_todo_detail_screen.dart';

class ClassGroupItem {
  final String id;
  final String className;
  final String scheduleInfo;
  final bool isActive;
  final String startDate;
  final int enrolledCount;
  final String? meetingLink;
  final String? signalGroupLink;

  ClassGroupItem({
    required this.id,
    required this.className,
    required this.scheduleInfo,
    required this.isActive,
    required this.startDate,
    required this.enrolledCount,
    this.meetingLink,
    this.signalGroupLink,
  });

  factory ClassGroupItem.fromJson(Map<String, dynamic> json) {
    final students = json['class_students'] as List?;
    return ClassGroupItem(
      id: json['id'] ?? '',
      className: json['class_name'] ?? 'Untitled Class',
      scheduleInfo: json['schedule_info'] ?? '',
      isActive: json['is_active'] ?? false,
      startDate: json['start_date'] ?? '',
      enrolledCount: students != null ? students.length : 0,
      meetingLink: json['meeting_link'],
      signalGroupLink: json['signal_group_link'],
    );
  }
}

class TeacherOverviewScreen extends StatefulWidget {
  const TeacherOverviewScreen({super.key});

  @override
  State<TeacherOverviewScreen> createState() => _TeacherOverviewScreenState();
}

class _TeacherOverviewScreenState extends State<TeacherOverviewScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  Map<String, dynamic> instructor = {
    'first_name': 'Instructor',
    'last_name': '',
    'avatar': '',
    'email': '',
    'wallet': 0.0,
  };

  Map<String, int> stats = {
    'totalStudents': 0,
    'totalClasses': 0,
    'pendingGrading': 0,
    'todayAttendance': 0,
  };

  List<ClassGroupItem> classes = [];
  List<Map<String, dynamic>> todoList = [];
  final TextEditingController _todoController = TextEditingController();
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final profile = await supabase
          .from("profiles")
          .select("first_name, last_name, avatar_url, email, wallet_balance")
          .eq("id", userId)
          .maybeSingle();

      if (profile != null) {
        instructor = {
          'first_name': profile['first_name'] ?? 'Instructor',
          'last_name': profile['last_name'] ?? '',
          'avatar': profile['avatar_url'] ?? '',
          'email': profile['email'] ?? user.email ?? '',
          'wallet': (profile['wallet_balance'] ?? 0).toDouble(),
        };
      }

      final classData = await supabase
          .from("class_groups")
          .select("id, class_name, schedule_info, is_active, start_date, meeting_link, signal_group_link, class_students(student_id)")
          .eq("teacher_id", userId)
          .order("is_active", ascending: false)
          .order("start_date", ascending: true)
          .limit(4);

      int totalStudentsCount = 0;
      List<String> classIds = [];

      classIds = (classData as List).map((c) => c['id'].toString()).toList();
      classes = (classData as List).map((cls) {
        final item = ClassGroupItem.fromJson(cls);
        totalStudentsCount += item.enrolledCount;
        return item;
      }).toList();
    
      int pendingCount = 0;
      final myCourses = await supabase.from("courses").select("id").eq("teacher_id", userId);

      if ((myCourses as List).isNotEmpty) {
        final courseIds = myCourses.map((c) => c['id']).toList();
        final myAssignments = await supabase.from("assignments").select("id").inFilter("course_id", courseIds);

        if ((myAssignments as List).isNotEmpty) {
          final assignmentIds = myAssignments.map((a) => a['id']).toList();
          final countRes = await supabase
              .from("assignment_submissions")
              .select("id")
              .inFilter("assignment_id", assignmentIds)
              .isFilter("grade", null);

          pendingCount = (countRes as List?)?.length ?? 0;
        }
      }

      int todayAttCount = 0;
      if (classIds.isNotEmpty) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final attRes = await supabase
            .from("attendance_logs")
            .select("id")
            .inFilter("class_group_id", classIds)
            .eq("session_date", today)
            .eq("status", "present");

        todayAttCount = (attRes as List?)?.length ?? 0;
      }

      // واکشی لیست تو-دوها و مرتب‌سازی هوشمند بر اساس زمان سررسید و وضعیت تکمیل
      final todosRes = await supabase
          .from("teacher_todos")
          .select("*")
          .eq("teacher_id", userId)
          .order("is_completed", ascending: true)
          .order("due_time", ascending: true);

      setState(() {
        stats = {
          'totalStudents': totalStudentsCount,
          'totalClasses': classes.length,
          'pendingGrading': pendingCount,
          'todayAttendance': todayAttCount,
        };
        todoList = List<Map<String, dynamic>>.from(todosRes);
      });
    } catch (e) {
      debugPrint("Error loading teacher dashboard: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickDueDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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

  Future<void> _addTodoItem() async {
    final text = _todoController.text.trim();
    if (text.isEmpty) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from("teacher_todos").insert({
        'teacher_id': user.id,
        'task_text': text,
        'is_completed': false,
        'due_time': _selectedDueDate?.toIso8601String(),
      });

      _todoController.clear();
      _selectedDueDate = null;
      _fetchDashboardData();
    } catch (e) {
      debugPrint("Error adding todo: $e");
    }
  }

  Future<void> _toggleTodoStatus(String id, bool currentStatus) async {
    try {
      await supabase.from("teacher_todos").update({
        'is_completed': !currentStatus,
      }).eq('id', id);

      _fetchDashboardData();
    } catch (e) {
      debugPrint("Error updating todo: $e");
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryPink),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= ۱. هدر پروفایل لوکس و مدرن استاد =================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [surfaceWhite, lightPinkBg.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryPink, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: lightPinkBg,
                    backgroundImage: instructor['avatar'].isNotEmpty ? NetworkImage(instructor['avatar']) : null,
                    child: instructor['avatar'].isEmpty
                        ? Text(instructor['first_name'][0], style: const TextStyle(color: primaryPink, fontSize: 22, fontWeight: FontWeight.w900))
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("INSTRUCTOR PORTAL", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${instructor['first_name']} ${instructor['last_name']}",
                        style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        instructor['email'],
                        style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("BALANCE", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: textGrey)),
                      const SizedBox(height: 2),
                      Text("\$${instructor['wallet'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ================= ۲. آمار زنده =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("PERFORMANCE OVERVIEW", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(color: primaryPink, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _buildGorgeousStatCard("Total Students", "${stats['totalStudents']}", Icons.group_rounded, primaryPink),
              _buildGorgeousStatCard("Live Sessions", "${stats['totalClasses']}", Icons.live_tv_rounded, Colors.redAccent),
              _buildGorgeousStatCard("Pending Grades", "${stats['pendingGrading']}", Icons.assignment_turned_in_rounded, Colors.orange),
              _buildGorgeousStatCard("Today Attendance", "${stats['todayAttendance']}", Icons.how_to_reg_rounded, Colors.green),
            ],
          ),
          const SizedBox(height: 32),

          // ================= ۳. لیست کارهای روزانه همراه با انتخاب تایم و هشدار رنگی =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("FACULTY TO-DO LIST & ALERTS", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              Text("${todoList.where((t) => t['is_completed'] == true).length}/${todoList.length} Done", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorder),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _todoController,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                        decoration: InputDecoration(
                          hintText: "Add urgent task...",
                          hintStyle: const TextStyle(fontSize: 11, color: textGrey),
                          filled: true,
                          fillColor: cardBorder.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.access_time_rounded, color: _selectedDueDate != null ? primaryPink : textGrey),
                      onPressed: _pickDueDate,
                      tooltip: "Set Due Time",
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _addTodoItem,
                      child: const Icon(Icons.add_rounded, size: 20),
                    ),
                  ],
                ),
                if (_selectedDueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_rounded, size: 14, color: primaryPink),
                      const SizedBox(width: 6),
                      Text("Due: ${_selectedDueDate.toString().split('.')[0]}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryPink)),
                    ],
                  ),
                ],
                if (todoList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todoList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = todoList[index];
                      final isCompleted = task['is_completed'] ?? false;
                      final dueTimeString = task['due_time'];

                      bool isAlert = false;
                      if (!isCompleted && dueTimeString != null) {
                        final dueDate = DateTime.parse(dueTimeString);
                        if (DateTime.now().isAfter(dueDate.subtract(const Duration(hours: 2)))) {
                          isAlert = true; // اگر کمتر از ۲ ساعت مانده باشد یا وقتش گذشته باشد
                        }
                      }

                      return GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TeacherTodoDetailScreen(todoItem: task)),
                          );
                          if (result == true) {
                            _fetchDashboardData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCompleted 
                                ? Colors.green.withOpacity(0.05) 
                                : (isAlert ? Colors.amber.withOpacity(0.2) : cardBorder.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompleted 
                                  ? Colors.green.withOpacity(0.2) 
                                  : (isAlert ? Colors.amber.shade700 : cardBorder),
                              width: isAlert ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isCompleted,
                                activeColor: primaryPink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => _toggleTodoStatus(task['id'], isCompleted),
                              ),
                              if (isAlert) ...[
                                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task['task_text'] ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCompleted ? textGrey : textDark,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (dueTimeString != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Due: ${dueTimeString.split('T')[0]} ${dueTimeString.split('T')[1].substring(0, 5)}",
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isAlert ? Colors.amber.shade900 : textGrey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textGrey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ================= ۴. فرماندهی کلاس‌ها (Command Center) =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("COMMAND CENTER", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lightPinkBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("${classes.length} Active Rooms", style: const TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          classes.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: classes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final room = classes[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: room.isActive ? primaryPink : cardBorder,
                          width: room.isActive ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: room.isActive ? primaryPink.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: room.isActive ? primaryPink : lightPinkBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  room.isActive ? "● LIVE NOW" : "○ STANDBY",
                                  style: TextStyle(
                                    color: room.isActive ? Colors.white : primaryPink,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.people_alt_rounded, size: 14, color: textGrey),
                                  const SizedBox(width: 5),
                                  Text("${room.enrolledCount} Students", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(room.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 17)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: textGrey),
                              const SizedBox(width: 6),
                              Text(room.scheduleInfo.isNotEmpty ? room.scheduleInfo : "Schedule not set", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              if (room.meetingLink != null)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: room.isActive ? primaryPink : textDark,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    icon: const Icon(Icons.video_call_rounded, size: 18),
                                    label: const Text("Launch Teams", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _launchURL(room.meetingLink!),
                                  ),
                                ),
                              if (room.meetingLink != null && room.signalGroupLink != null) const SizedBox(width: 10),
                              if (room.signalGroupLink != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textDark,
                                      side: const BorderSide(color: cardBorder, width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_rounded, color: primaryPink, size: 16),
                                    label: const Text("Open Signal", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _launchURL(room.signalGroupLink!),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cardBorder),
                  ),
                  child: const Text("No active classrooms assigned yet.", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGorgeousStatCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accentColor)),
            ],
          ),
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: textGrey, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}