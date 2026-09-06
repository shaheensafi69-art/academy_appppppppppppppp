import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'certificates_screen.dart';

class CertificateDetailScreen extends StatefulWidget {
  final CertificateItem certificate;

  const CertificateDetailScreen({super.key, required this.certificate});

  @override
  State<CertificateDetailScreen> createState() => _CertificateDetailScreenState();
}

class _CertificateDetailScreenState extends State<CertificateDetailScreen> {
  bool isDownloading = false;
  double downloadProgress = 0.0;
  
  bool isLoadingPdf = true;
  String? localPdfPath;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    if (widget.certificate.certificateUrl != null && !_isImage(widget.certificate.certificateUrl)) {
      _preparePdfForViewing(widget.certificate.certificateUrl!);
    }
  }

  bool _isImage(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');
  }

  Future<void> _preparePdfForViewing(String urlString) async {
    try {
      setState(() => isLoadingPdf = true);
      var dir = await getTemporaryDirectory();
      File file = File("${dir.path}/temp_cert_${widget.certificate.id}.pdf");
      
      if (!await file.exists()) {
        Dio dio = Dio();
        await dio.download(urlString, file.path);
      }

      if (mounted) {
        setState(() {
          localPdfPath = file.path;
          isLoadingPdf = false;
        });
      }
    } catch (e) {
      debugPrint("Error preparing PDF for view: $e");
      if (mounted) {
        setState(() => isLoadingPdf = false);
      }
    }
  }

  Future<void> _downloadInBackground(String urlString) async {
    try {
      setState(() {
        isDownloading = true;
        downloadProgress = 0.0;
      });

      Directory? directory;
      if (Platform.isAndroid) {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        try {
          if (await publicDownloadDir.exists()) {
            final testFile = File('${publicDownloadDir.path}/.perm_test_${DateTime.now().millisecondsSinceEpoch}');
            await testFile.writeAsString('test');
            await testFile.delete();
            directory = publicDownloadDir;
          }
        } catch (_) {}
        directory ??= await getExternalStorageDirectory();
        directory ??= await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName = "Certificate_${widget.certificate.certificateCode}.${_isImage(urlString) ? 'jpg' : 'pdf'}";
      String savePath = "${directory.path}/$fileName";

      Dio dio = Dio();
      await dio.download(
        urlString,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("File downloaded successfully to Downloads folder! 📁", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Download error: $e");
      try {
        final Uri url = Uri.parse(urlString);
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isImg = _isImage(widget.certificate.certificateUrl);
    final bool hasUrl = widget.certificate.certificateUrl != null && widget.certificate.certificateUrl!.isNotEmpty;

    return AcademyLoadingOverlay(
      isLoading: isDownloading,
      message: "DOWNLOADING FILE... ${(downloadProgress * 100).toStringAsFixed(0)}%",
      child: Scaffold(
        backgroundColor: surfaceWhite,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5), surfaceWhite, lightPinkBg.withOpacity(0.2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ================= هدر صفحه =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: surfaceWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder, width: 1.5)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_rounded, color: textDark, size: 16),
                              SizedBox(width: 6),
                              Text("Back", style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            widget.certificate.courseTitle,
                            style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (hasUrl)
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: lightPinkBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          icon: const Icon(Icons.download_rounded, color: primaryPink, size: 18),
                          onPressed: isDownloading ? null : () => _downloadInBackground(widget.certificate.certificateUrl!),
                          tooltip: "Download File",
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= کادر پیش‌نمایش مدرن داخل برنامه‌ای =================
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: hasUrl
                            ? (isImg
                                ? InteractiveViewer(
                                    child: Image.network(
                                      widget.certificate.certificateUrl!,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                            color: primaryPink,
                                            strokeWidth: 2.5,
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Text("Failed to load certificate image.", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  )
                                : (isLoadingPdf
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5),
                                            SizedBox(height: 12),
                                            Text("Loading PDF Viewer...", style: TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      )
                                    : (localPdfPath != null
                                        ? PDFView(
                                            filePath: localPdfPath!,
                                            enableSwipe: true,
                                            swipeHorizontal: false,
                                            autoSpacing: false,
                                            pageFling: true,
                                            onError: (error) => debugPrint("PDF Error: $error"),
                                            onPageError: (page, error) => debugPrint("PDF Page Error $page: $error"),
                                          )
                                        : const Center(
                                            child: Text("Could not load PDF document.", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
                                          ))))
                            : const Center(
                                child: Text("No document attached.", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= اطلاعات و دکمه دانلود پایین صفحه =================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("CERTIFICATE CODE", style: TextStyle(fontSize: 8, color: primaryPink, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                const SizedBox(height: 3),
                                Text(widget.certificate.certificateCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark, fontFamily: 'monospace')),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("ISSUE DATE", style: TextStyle(fontSize: 8, color: textGrey, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                const SizedBox(height: 3),
                                Text(widget.certificate.issueDate.split('T')[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textDark)),
                              ],
                            ),
                          ],
                        ),
                        if (hasUrl) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text("Download File to Device 📥", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                              onPressed: isDownloading ? null : () => _downloadInBackground(widget.certificate.certificateUrl!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ویجت کاستوم لودینگ آکادمی
// ============================================================================

class AcademyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AcademyLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = "LOADING...",
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withOpacity(0.95),
            alignment: Alignment.center,
            child: _AcademyThinkingLoadingAnimation(message: message),
          ),
      ],
    );
  }
}

class _AcademyThinkingLoadingAnimation extends StatefulWidget {
  final String message;
  const _AcademyThinkingLoadingAnimation({required this.message});

  @override
  State<_AcademyThinkingLoadingAnimation> createState() => _AcademyThinkingLoadingAnimationState();
}

class _AcademyThinkingLoadingAnimationState extends State<_AcademyThinkingLoadingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      const Color(0xFFF494AC).withOpacity(0.0),
                      const Color(0xFFF494AC).withOpacity(0.8),
                      const Color(0xFFF494AC),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF4F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF494AC).withOpacity(0.25), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.girl_rounded,
                    size: 54,
                    color: Color(0xFFF494AC),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: Color(0xFFF494AC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          widget.message,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}