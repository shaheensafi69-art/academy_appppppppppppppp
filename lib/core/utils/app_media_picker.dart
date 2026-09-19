import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
export 'package:image_picker/image_picker.dart' show ImageSource;

/// 📱 سرویس جامع، مجهز به اعتبارسنجی مجوزها و فوق‌پایدار برای انتخاب فایل و رسانه در اندروید و iOS
/// این سرویس دارای لایه‌های محافظتی متوالی (Permissions -> ImagePicker -> FilePicker -> Bytes Fallback) است
/// تا در هیچ دیوایسی (سامسونگ، شیائومی، هواوی، اندروید ۱۳، ۱۴ و ۱۵) باز شدن فایل‌ها مسدود نشود.
class AppMediaPicker {
  AppMediaPicker._();
  static final AppMediaPicker instance = AppMediaPicker._();

  final ImagePicker _imagePicker = ImagePicker();

  /// اعتبارسنجی و درخواست مجوز متناسب با نوع عملیات و نسخه سیستم‌عامل
  Future<void> _ensurePermissions({
    bool isCamera = false,
    bool isVideo = false,
  }) async {
    try {
      if (kIsWeb) return;

      if (isCamera) {
        final status = await Permission.camera.status;
        if (!status.isGranted && !status.isPermanentlyDenied) {
          await Permission.camera.request();
        }
        return;
      }

      if (Platform.isAndroid) {
        // برای اندروید ۱۳ و بالاتر
        try {
          if (isVideo) {
            final videoStatus = await Permission.videos.status;
            if (!videoStatus.isGranted && !videoStatus.isPermanentlyDenied) {
              await Permission.videos.request();
            }
          } else {
            final photosStatus = await Permission.photos.status;
            if (!photosStatus.isGranted && !photosStatus.isPermanentlyDenied) {
              await Permission.photos.request();
            }
          }
        } catch (_) {}

        // برای اندروید ۱۲ و پایین‌تر
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted && !storageStatus.isPermanentlyDenied) {
          await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.status;
        if (!status.isGranted && !status.isPermanentlyDenied) {
          await Permission.photos.request();
        }
      }
    } catch (e) {
      debugPrint("Permission check note: $e");
    }
  }

  /// ذخیره بایت‌ها در فایل موقت در صورتی که فایل‌پیکر به جای مسیر، بایت‌ها را برگرداند (مخصوص درایو و دانلودها)
  Future<File?> _saveBytesToTempFile(Uint8List bytes, String fileName) async {
    try {
      final tempDir = Directory.systemTemp;
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final file = File('${tempDir.path}/$uniqueName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint("Error writing temp bytes: $e");
      return null;
    }
  }

  /// انتخاب تصویر (پروفایل، کاور دوره‌ها، پست‌های فید، استوری و ...)
  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
  }) async {
    await _ensurePermissions(isCamera: source == ImageSource.camera);

    String? finalPath;

    // ۱. تلاش با استفاده از ImagePicker
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      if (picked != null && picked.path.isNotEmpty) {
        finalPath = picked.path;
      }
    } on PlatformException catch (pe) {
      debugPrint("⚠️ ImagePicker PlatformException: ${pe.code} - ${pe.message}");
    } catch (e) {
      debugPrint("⚠️ ImagePicker failed: $e");
    }

    // ۲. لایه پشتیبان خودکار گالری با FilePicker (فقط در حالت گالری)
    if (finalPath == null && source == ImageSource.gallery) {
      try {
        final FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final platformFile = result.files.single;
          if (platformFile.path != null && platformFile.path!.isNotEmpty) {
            finalPath = platformFile.path;
          } else if (platformFile.bytes != null) {
            return await _saveBytesToTempFile(
              platformFile.bytes!,
              platformFile.name,
            );
          }
        }
      } catch (fpErr) {
        debugPrint("⚠️ FilePicker image fallback notice: $fpErr");
        // ۳. تلاش با فرمت‌های صریح پسوند
        try {
          final FilePickerResult? customResult =
              await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
            allowMultiple: false,
            withData: true,
          );
          if (customResult != null && customResult.files.isNotEmpty) {
            final platformFile = customResult.files.single;
            if (platformFile.path != null) {
              finalPath = platformFile.path;
            } else if (platformFile.bytes != null) {
              return await _saveBytesToTempFile(
                platformFile.bytes!,
                platformFile.name,
              );
            }
          }
        } catch (_) {}
      }
    }

    if (finalPath != null && finalPath.isNotEmpty) {
      final file = File(finalPath);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  /// انتخاب ویدیو (ریلز، تکالیف ویدیویی، ویدیوهای درسی و ...)
  Future<File?> pickVideo({
    ImageSource source = ImageSource.gallery,
  }) async {
    await _ensurePermissions(
      isCamera: source == ImageSource.camera,
      isVideo: true,
    );

    String? finalPath;

    // ۱. تلاش با ImagePicker
    try {
      final XFile? picked = await _imagePicker.pickVideo(source: source);
      if (picked != null && picked.path.isNotEmpty) {
        finalPath = picked.path;
      }
    } on PlatformException catch (pe) {
      debugPrint("⚠️ ImagePicker pickVideo PlatformException: ${pe.code} - ${pe.message}");
    } catch (e) {
      debugPrint("⚠️ ImagePicker pickVideo failed: $e");
    }

    // ۲. لایه پشتیبان ویدیو با FilePicker
    if (finalPath == null && source == ImageSource.gallery) {
      try {
        final FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.video,
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final platformFile = result.files.single;
          if (platformFile.path != null && platformFile.path!.isNotEmpty) {
            finalPath = platformFile.path;
          } else if (platformFile.bytes != null) {
            return await _saveBytesToTempFile(
              platformFile.bytes!,
              platformFile.name,
            );
          }
        }
      } catch (fpErr) {
        debugPrint("⚠️ FilePicker video fallback notice: $fpErr");
      }
    }

    if (finalPath != null && finalPath.isNotEmpty) {
      final file = File(finalPath);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  /// انتخاب اسناد، فایل‌های تمرین، PDF، سرتیفیکت و انواع فایل‌های گوشی
  Future<File?> pickDocumentOrMedia({
    List<String> allowedExtensions = const [
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'doc',
      'docx',
      'zip',
      'rar',
    ],
  }) async {
    await _ensurePermissions();

    String? finalPath;

    // ۱. تلاش اول با FileType.any تا کاربر بتواند هر فایلی را از مدیریت فایل انتخاب کند
    try {
      final FilePickerResult? anyResult = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (anyResult != null && anyResult.files.isNotEmpty) {
        final platformFile = anyResult.files.single;
        if (platformFile.path != null && platformFile.path!.isNotEmpty) {
          finalPath = platformFile.path;
        } else if (platformFile.bytes != null) {
          return await _saveBytesToTempFile(
            platformFile.bytes!,
            platformFile.name,
          );
        }
      }
    } catch (anyErr) {
      debugPrint("⚠️ FilePicker any notice: $anyErr");
    }

    // ۲. تلاش دوم با پسوندهای سفارشی در صورت تمایل سیستم‌عامل به فیلتر
    if (finalPath == null) {
      try {
        final FilePickerResult? customResult =
            await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: allowedExtensions,
          allowMultiple: false,
          withData: true,
        );
        if (customResult != null && customResult.files.isNotEmpty) {
          final platformFile = customResult.files.single;
          if (platformFile.path != null && platformFile.path!.isNotEmpty) {
            finalPath = platformFile.path;
          } else if (platformFile.bytes != null) {
            return await _saveBytesToTempFile(
              platformFile.bytes!,
              platformFile.name,
            );
          }
        }
      } catch (customErr) {
        debugPrint("⚠️ FilePicker custom notice: $customErr");
      }
    }

    // ۳. تلاش سوم با ImagePicker در صورتی که کاربر قصد انتخاب تصویر یا مدرک تصویری داشته باشد
    if (finalPath == null) {
      try {
        final XFile? img = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (img != null && img.path.isNotEmpty) {
          finalPath = img.path;
        }
      } catch (_) {}
    }

    if (finalPath != null && finalPath.isNotEmpty) {
      final file = File(finalPath);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }
}
