import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
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
  
  // متغیرهای مخصوص نمایش PDF در داخل اپ
  bool isLoadingPdf = true;
  String? localPdfPath;

  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
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

  // دانلود موقت فایل PDF در حافظه داخلی برای نمایش درون‌برنامه‌ای (In-App PDF Viewer)
  Future<void> _preparePdfForViewing(String urlString) async {
    try {
      setState(() => isLoadingPdf = true);
      var dir = await getTemporaryDirectory();
      File file = File("${dir.path}/temp_cert_${widget.certificate.id}.pdf");
      
      // اگر قبلاً دانلود نشده بود، دانلودش کن
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

  // دانلود دائمی در پوشه Downloads گوشی بدون خروج کاربر
  Future<void> _downloadInBackground(String urlString) async {
    try {
      setState(() {
        isDownloading = true;
        downloadProgress = 0.0;
      });

      var status = await Permission.storage.request();
      if (!status.isGranted && Platform.isAndroid) {
        await Permission.manageExternalStorage.request();
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName = "Certificate_${widget.certificate.certificateCode}.${_isImage(urlString) ? 'jpg' : 'pdf'}";
      String savePath = "${directory?.path}/$fileName";

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
            content: const Text("File downloaded successfully to Downloads folder! 📁"),
            backgroundColor: Colors.green.shade700,
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

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.certificate.courseTitle, style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          if (hasUrl)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: primaryPink),
              onPressed: isDownloading ? null : () => _downloadInBackground(widget.certificate.certificateUrl!),
              tooltip: "Download File",
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // کادر پیش‌نمایش مدرن داخل برنامه‌ای (برای عکس و PDF)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cardBorder, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: hasUrl
                        ? (isImg
                            // حالت نمایش عکس با قابلیت زوم
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
                            // حالت نمایش PDF در داخل برنامه (In-App PDF Viewer)
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

              // بخش دکمه دانلود اختصاصی و اطلاعات پایین صفحه
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lightPinkBg.withOpacity(0.5), surfaceWhite],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryPink.withOpacity(0.2), width: 1.5),
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
                      isDownloading
                          ? Column(
                              children: [
                                LinearProgressIndicator(value: downloadProgress, color: primaryPink, backgroundColor: lightPinkBg),
                                const SizedBox(height: 6),
                                Text("Downloading to device... ${(downloadProgress * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryPink)),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryPink,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text("Download File to Device 📥", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                onPressed: () => _downloadInBackground(widget.certificate.certificateUrl!),
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
    );
  }
}