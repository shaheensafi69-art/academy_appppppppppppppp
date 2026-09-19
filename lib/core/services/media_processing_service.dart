import 'dart:async';
import 'dart:io';
import 'package:easy_compressor/easy_compressor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_watermark_plus/video_watermark_plus.dart';

/// Central media processing service dedicated to Media Optimization and Watermarking:
/// 1. High-efficiency hardware-accelerated video compression via [EasyCompressor] before upload to Cloudflare R2.
/// 2. Universal photo compression (resizing + JPEG 80%) for all app uploads (feed, story, profile, cover, etc.).
/// 3. TikTok-style "Safi Academy" watermark applied exclusively when users DOWNLOAD videos to gallery.
class MediaProcessingService {
  MediaProcessingService._();
  static final MediaProcessingService instance = MediaProcessingService._();

  String? _cachedWatermarkLocalPath;

  /// Prepares and copies the stylized "Safi Academy" watermark PNG from assets to local disk
  Future<String> getWatermarkPath() async {
    if (_cachedWatermarkLocalPath != null &&
        File(_cachedWatermarkLocalPath!).existsSync()) {
      return _cachedWatermarkLocalPath!;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final watermarkFile =
          File('${tempDir.path}/safi_academy_watermark_v1.png');

      final byteData =
          await rootBundle.load('assets/watermark_safi_academy.png');
      final bytes = byteData.buffer.asUint8List();
      await watermarkFile.writeAsBytes(bytes, flush: true);

      _cachedWatermarkLocalPath = watermarkFile.path;
      return watermarkFile.path;
    } catch (e) {
      debugPrint('[MediaProcessingService] Error loading watermark asset: $e');
      rethrow;
    }
  }

  /// Compresses raw image bytes across the entire application:
  /// - Resizes large images so max(width, height) <= [maxDimension] (default 1280px).
  /// - Encodes to optimized JPEG with [quality] (default 80%).
  /// - Reduces 5MB-15MB camera photos to ~120-250KB with zero noticeable quality loss.
  Future<Uint8List> compressImageBytes(
    Uint8List rawBytes, {
    int maxDimension = 1280,
    int quality = 80,
  }) async {
    if (rawBytes.isEmpty) return rawBytes;

    try {
      final decodedImage = img.decodeImage(rawBytes);
      if (decodedImage == null) return rawBytes;

      img.Image processedImage = decodedImage;
      if (decodedImage.width > maxDimension ||
          decodedImage.height > maxDimension) {
        if (decodedImage.width >= decodedImage.height) {
          processedImage = img.copyResize(decodedImage, width: maxDimension);
        } else {
          processedImage = img.copyResize(decodedImage, height: maxDimension);
        }
      }

      final compressed = img.encodeJpg(processedImage, quality: quality);
      final compressedBytes = Uint8List.fromList(compressed);

      if (compressedBytes.length < rawBytes.length) {
        return compressedBytes;
      }
      return rawBytes;
    } catch (e) {
      debugPrint('[MediaProcessingService] Error compressing image bytes: $e');
      return rawBytes;
    }
  }

  /// Compresses Feed & Story Photos from a File:
  Future<File> compressFeedImage(
    File inputImageFile, {
    int maxDimension = 1280,
    int quality = 80,
  }) async {
    if (!inputImageFile.existsSync()) return inputImageFile;

    final originalSizeKb = inputImageFile.lengthSync() / 1024;
    debugPrint(
        '[MediaProcessingService] 🖼️ Compressing photo (${originalSizeKb.toStringAsFixed(1)} KB)...');

    try {
      final bytes = await inputImageFile.readAsBytes();
      final compressedBytes = await compressImageBytes(
        bytes,
        maxDimension: maxDimension,
        quality: quality,
      );

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/img_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedBytes, flush: true);

      final newSizeKb = outputFile.lengthSync() / 1024;
      debugPrint(
          '[MediaProcessingService] ✅ Photo compressed: ${originalSizeKb.toStringAsFixed(1)} KB -> ${newSizeKb.toStringAsFixed(1)} KB');
      return outputFile;
    } catch (e) {
      debugPrint('[MediaProcessingService] ❌ Photo compression error: $e');
      return inputImageFile;
    }
  }

  /// Compresses video using hardware-accelerated native Media3 / AVFoundation:
  /// - High quality 70 / 1080p preset for social media and reels.
  /// - Drastically reduces video size before Cloudflare R2 upload.
  Future<File> compressVideo(
    String inputVideoPath, {
    void Function(double progress)? onProgress,
  }) async {
    final inputFile = File(inputVideoPath);
    if (!inputFile.existsSync()) return inputFile;

    final originalSizeMb = inputFile.lengthSync() / (1024 * 1024);
    debugPrint(
        '[MediaProcessingService] 🎬 Compressing video (${originalSizeMb.toStringAsFixed(2)} MB)...');

    try {
      final compressor = EasyCompressor();
      final result = await compressor.compressVideo(
        inputVideoPath,
        config: const CompressionConfig.social(),
        onProgress: onProgress,
      );

      final compressedFile = File(result.outputPath);
      if (compressedFile.existsSync()) {
        final newSizeMb = compressedFile.lengthSync() / (1024 * 1024);
        debugPrint(
            '[MediaProcessingService] ✅ Video compressed: ${originalSizeMb.toStringAsFixed(2)} MB -> ${newSizeMb.toStringAsFixed(2)} MB (${result.spaceSavedPercent.toStringAsFixed(1)}% space saved)');
        return compressedFile;
      }
    } catch (e) {
      debugPrint(
          '[MediaProcessingService] ⚠️ Video compression failed ($e), falling back to original.');
    }

    return inputFile;
  }

  /// Legacy wrapper for backwards compatibility:
  Future<File> processVideoWithWatermark({
    required String inputVideoPath,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Compressing video for Safi Academy...');
    return compressVideo(inputVideoPath);
  }

  /// Adds TikTok-style "Safi Academy" watermark onto video when user DOWNLOADS it to gallery:
  /// - Applied exclusively upon export/download (not displayed in in-app player).
  /// - Uses [video_watermark_plus] to overlay the stylized watermark image.
  Future<File> addWatermarkToVideoForDownload({
    required String inputVideoPath,
    void Function(double progress)? onProgress,
  }) async {
    final inputFile = File(inputVideoPath);
    if (!inputFile.existsSync()) return inputFile;

    debugPrint(
        '[MediaProcessingService] 🎨 Applying TikTok-style watermark for download on: $inputVideoPath');

    try {
      final watermarkPath = await getWatermarkPath();
      final tempDir = await getTemporaryDirectory();
      final outputFileName =
          'Safi_Academy_Reel_${DateTime.now().millisecondsSinceEpoch}';

      String? savedOutputPath;
      final completer = Completer<String?>();

      final videoWatermark = VideoWatermark(
        sourceVideoPath: inputVideoPath,
        videoFileName: outputFileName,
        savePath: tempDir.path,
        watermark: Watermark(
          image: WatermarkSource.file(watermarkPath),
          watermarkAlignment: WatermarkAlignment.topRight,
          watermarkSize: WatermarkSize(160, 48),
          opacity: 0.92,
        ),
        onSave: (outputPath) {
          savedOutputPath = outputPath;
          if (!completer.isCompleted) completer.complete(outputPath);
        },
        progress: (prog) {
          onProgress?.call(prog);
        },
      );

      await videoWatermark.generateVideo();

      final finalPath = await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => savedOutputPath,
      );

      if (finalPath != null && File(finalPath).existsSync()) {
        debugPrint(
            '[MediaProcessingService] ✅ Watermarked video ready: $finalPath');
        return File(finalPath);
      }
    } catch (e) {
      debugPrint(
          '[MediaProcessingService] ⚠️ Watermark application error: $e. Falling back to original.');
    }

    return inputFile;
  }
}
