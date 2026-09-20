# Keep Flutter embedding and plugin registrant
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# Keep application class
-keep class * extends android.app.Application { *; }

# Keep classes referenced from native (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator CREATOR;
}

# Allow optimization but keep reflection-used members
-keepattributes Signature, *Annotation*

# Add plugin-specific rules below if you see runtime issues
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class miguelruivo.flutter.plugins.filepicker.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.activity.result.** { *; }
-keep class androidx.activity.result.contract.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Suppress warnings for Play Core classes referenced by Flutter deferred components
# (generated from build outputs/mapping/release/missing_rules.txt)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Additional plugin keep rules for safe R8 release optimization
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class androidx.media3.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.endigo.plugins.pdfviewflutter.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }
-keep class com.llfbandit.app_links.** { *; }
-keep class studio.midoridesign.gal.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keepclassmembers enum * { *; }
