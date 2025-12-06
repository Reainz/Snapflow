import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Apply Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.snapflow.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Pin a stable Build Tools to avoid RC versions (e.g., 36.1.0-rc1) that can
    // cause packaging failures on Windows (invalid APK / missing AndroidManifest.xml).
    // Requires that this build tools version is installed in your Android SDK.
    buildToolsVersion = "35.0.0"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.snapflow.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties["storeFile"] as? String
                if (!storeFilePath.isNullOrBlank()) {
                    storeFile = file(storeFilePath)
                    storePassword = keystoreProperties["storePassword"] as String?
                    keyAlias = keystoreProperties["keyAlias"] as String?
                    keyPassword = keystoreProperties["keyPassword"] as String?
                } else {
                    initWith(getByName("debug"))
                    println("WARNING: key.properties missing required fields; using debug signing for release.")
                }
            } else {
                initWith(getByName("debug"))
                println("WARNING: key.properties not found; using debug signing for release.")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
