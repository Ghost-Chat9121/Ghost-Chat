plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ghost_chat"
    compileSdk = 36                        // ✅ pinned to 36 instead of flutter default
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17   // ✅ already correct
        targetCompatibility = JavaVersion.VERSION_17   // ✅ already correct
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()  // ✅ already correct
    }

    defaultConfig {
        applicationId = "com.example.ghost_chat"
        minSdk = flutter.minSdkVersion              // ✅ CHANGED — flutter_webrtc requires minimum 21
        targetSdk = 36           // ✅ pinned to 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
