import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'class_detail_screen.dart';

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
        backgroundColor: surfaceWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text("ORGANIZING CLASS COHORTS...", style: TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    final groups = groupedClasses;

    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceWhite, lightPinkBg.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primaryPink.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "COHORTS DIRECTORY",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 1.2),
                        ),
                      ),
                      const Icon(Icons.class_rounded, color: primaryPink, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Class Cohorts",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Monitor active groups and track newly formed cohorts.",
                    style: TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: textGrey, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => searchQuery = val),
                            style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: "Search classes, courses...",
                              hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= GROUPED CLASSES =================
            groups.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: const Text("No classes found.", style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
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
                            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded, color: primaryPink, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(courseName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(8)),
                                  child: Text("${courseClasses.length} Classes", style: const TextStyle(color: textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: courseClasses.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: surfaceWhite,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: cardBorder, width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: cls.isActive ? Colors.green.withOpacity(0.12) : cardBorder,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              cls.isActive ? "● IN PROGRESS" : "○ COMPLETED",
                                              style: TextStyle(color: cls.isActive ? Colors.green.shade700 : textGrey, fontSize: 9, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                          if (isNew)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                              child: const Text("NEW", style: TextStyle(color: primaryPink, fontSize: 9, fontWeight: FontWeight.w900)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(cls.className, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15)),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: lightPinkBg,
                                                backgroundImage: cls.teacherAvatar != null ? NetworkImage(cls.teacherAvatar!) : null,
                                                child: cls.teacherAvatar == null ? const Text("T", style: TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text("${cls.teacherFirstName ?? ''} ${cls.teacherLastName ?? ''}", style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(8)),
                                            child: Text("${cls.studentsCount} Students", style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}