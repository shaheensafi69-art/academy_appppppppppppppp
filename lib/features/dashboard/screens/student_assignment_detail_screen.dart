import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudflare_storage_service.dart';
import '../../../core/localization/l10n_extensions.dart';
import 'student_assignments_screen.dart';

class StudentAssignmentDetailScreen extends StatefulWidget {
  final AssignmentItem assignment;
  const StudentAssignmentDetailScreen({super.key, required this.assignment});

  @override
  State<StudentAssignmentDetailScreen> createState() =>
      _StudentAssignmentDetailScreenState();
}

class _StudentAssignmentDetailScreenState
    extends State<StudentAssignmentDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isUploading = false;
  XFile? selectedFile;
  final ImagePicker _picker = ImagePicker();

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  Future<void> _pickFile() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (image != null) {
      setState(() {
        selectedFile = image;
      });
    }
  }

  Future<void> _submitAssignment() async {
    if (selectedFile == null) return;

    setState(() => isUploading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = selectedFile!.name.split('.').last;
      final fileName =
          '${user.id}-${widget.assignment.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final bytes = await selectedFile!.readAsBytes();

      final publicUrl = await CloudflareStorageService.instance.upload(
        bucket: 'safiacademy-media',
        path: 'assignments/$fileName',
        bytes: bytes,
      );

      await supabase.from('assignment_submissions').insert({
        'assignment_id': widget.assignment.id,
        'student_id': user.id,
        'file_url': publicUrl,
      });

      setState(() {
        widget.assignment.status = "submitted";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.submitAssignment),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: textDark,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    context.l10n.assignmentsAttendance,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cardBorder,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.assignment.courseName,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: lightPinkBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.assignment.status.toUpperCase(),
                            style: const TextStyle(
                              color: primaryPink,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.assignment.title,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${context.l10n.overview}:",
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.assignment.description,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: textGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${context.l10n.deadline}: ${widget.assignment.deadline.split('T')[0]}",
                          style: const TextStyle(
                            color: textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.assignment.status == "pending" ||
                  widget.assignment.status == "overdue") ...[
                Text(
                  context.l10n.submitAssignment,
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBorder.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_upload_rounded,
                          color: primaryPink,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFile != null
                                ? selectedFile!.name
                                : context.l10n.uploadSolution,
                            style: TextStyle(
                              color: selectedFile != null ? textDark : textGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: selectedFile == null || isUploading
                        ? null
                        : _submitAssignment,
                    child: isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "${context.l10n.submitAssignment.toUpperCase()} 🚀",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ] else if (widget.assignment.status == "submitted") ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.l10n.awaitingGrading,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else if (widget.assignment.status == "graded") ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${context.l10n.graded}: ${widget.assignment.grade} / 100",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${context.l10n.feedback}:",
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.assignment.feedback ?? 'No feedback provided.',
                        style: const TextStyle(
                          color: textGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
