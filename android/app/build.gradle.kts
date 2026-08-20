import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.safiacademy.app"
    compileSdk = 36 // تغییر از flutter.compileSdkVersion به ۳۶
    ndkVersion = flutter.ndkVersion

    // ...

    defaultConfig {
        applicationId = "org.safiacademy.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // تغییر از flutter.targetSdkVersion به ۳۶
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    
    // ...
}

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable code shrinking and resource shrinking to reduce APK size
            isMinifyEnabled = true
            isShrinkResources = true
            // Use Android's default optimize proguard file and a project rules file
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}