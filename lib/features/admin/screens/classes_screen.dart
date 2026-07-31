import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'class_detail_screen.dart'; // در ادامه این صفحه را می‌سازیم

class ClassItemModel {
  final String id;
  final String className;
  final bool isActive;
  final String createdAt;
  final String courseTitle;
  final String? teacherFirstName;
  final String? teacherLastName;
  final String? teacherAvatar;
  final int studentsCount;

  ClassItemModel({
    required this.id,
    required this.className,
    required this.isActive,
    required this.createdAt,
    required this.courseTitle,
    this.teacherFirstName,
    this.teacherLastName,
    this.teacherAvatar,
    required this.studentsCount,
  });
}

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<ClassItemModel> classes = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from("class_groups")
          .select("id, class_name, is_active, created_at, course:courses(title), teacher:profiles!teacher_id(first_name, last_name, avatar_url), class_students(student_id)")
          .order("created_at", ascending: false);

      List<ClassItemModel> loadedClasses = [];
      for (var cls in (response as List)) {
        final courseObj = cls['course'];
        String courseTitle = "Uncategorized Cohorts";
        if (courseObj != null) {
          courseTitle = courseObj is List ? (courseObj.isNotEmpty ? courseObj[0]['title'] ?? "Uncategorized Cohorts" : "Uncategorized Cohorts") : courseObj['title'] ?? "Uncategorized Cohorts";
        }

        final teacherObj = cls['teacher'];
        Map<String, dynamic>? teacherMap;
        if (teacherObj != null) {
          teacherMap = teacherObj is List ? (teacherObj.isNotEmpty ? teacherObj[0] : null) : teacherObj;
        }

        int studentsCount = (cls['class_students'] as List?)?.length ?? 0;

        loadedClasses.add(ClassItemModel(
          id: cls['id'] ?? '',
          className: cls['class_name'] ?? '',
          isActive: cls['is_active'] ?? false,
          createdAt: cls['created_at'] ?? '',
          courseTitle: courseTitle,
          teacherFirstName: teacherMap?['first_name'],
          teacherLastName: teacherMap?['last_name'],
          teacherAvatar: teacherMap?['avatar_url'],
          studentsCount: studentsCount,
        ));
      }

      if (mounted) {
        setState(() {
          classes = loadedClasses;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool _isClassNew(String dateString) {
    final classDate = DateTime.parse(dateString).millisecondsSinceEpoch;
    final today = DateTime.now().millisecondsSinceEpoch;
    final diffDays = (today - classDate) / (1000 * 60 * 60 * 24);
    return diffDays <= 10;
  }

  List<ClassItemModel> get filteredClasses {
    if (searchQuery.isEmpty) return classes;
    final query = searchQuery.toLowerCase();
    return classes.where((c) =>
      c.className.toLowerCase().contains(query) ||
      c.courseTitle.toLowerCase().contains(query) ||
      (c.teacherFirstName?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  Map<String, List<ClassItemModel>> get groupedClasses {
    Map<String, List<ClassItemModel>> groups = {};
    for (var cls in filteredClasses) {
      if (!groups.containsKey(cls.courseTitle)) {
        groups[cls.courseTitle] = [];
      }
      groups[cls.courseTitle]!.add(cls);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030305),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("ORGANIZING CLASS COHORTS...", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final groups = groupedClasses;

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.08), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "COHORTS DIRECTORY",
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 1.2),
                              ),
                            ),
                            const Icon(Icons.class_rounded, color: Colors.cyanAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Class Cohorts",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Monitor active groups and track newly formed cohorts.",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => setState(() => searchQuery = val),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: "Search classes, courses...",
                                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= GROUPED CLASSES =================
                  groups.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Text("No classes found.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groups.keys.length,
                          itemBuilder: (context, groupIndex) {
                            String courseName = groups.keys.elementAt(groupIndex);
                            List<ClassItemModel> courseClasses = groups[courseName]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.book_rounded, color: Colors.cyanAccent, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(courseName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                      ),
                                      Text("${courseClasses.length} Classes", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: courseClasses.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, classIndex) {
                                    final cls = courseClasses[classIndex];
                                    final isNew = _isClassNew(cls.createdAt);

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: cls.id)),
                                        );
                                      },
                                      child: _buildGlassCard(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: cls.isActive ? Colors.cyan.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(cls.isActive ? "IN PROGRESS" : "COMPLETED", style: TextStyle(color: cls.isActive ? Colors.cyanAccent : Colors.grey, fontSize: 7, fontWeight: FontWeight.w900)),
                                                ),
                                                if (isNew)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                                    child: const Text("NEW", style: TextStyle(color: Colors.amberAccent, fontSize: 7, fontWeight: FontWeight.w900)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(cls.className, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 10,
                                                      backgroundColor: Colors.black,
                                                      backgroundImage: cls.teacherAvatar != null ? NetworkImage(cls.teacherAvatar!) : null,
                                                      child: cls.teacherAvatar == null ? const Text("T", style: TextStyle(color: Colors.cyanAccent, fontSize: 8)) : null,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text("${cls.teacherFirstName ?? ''} ${cls.teacherLastName ?? ''}", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                                  ],
                                                ),
                                                Text("${cls.studentsCount} Students", style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                            );
                          },
                        ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0f).withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }
}