plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.paysense"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // Required for the productFlavors' resValue("string", "app_name", ...)
    // below (per-flavor app display name) — this AGP version has it off by
    // default.
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.paysense"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Lets a "PaySense Test" build (applicationId com.example.paysense.dev)
    // install side-by-side with the production app on the same device,
    // without touching the production applicationId/name above. `namespace`
    // (the Kotlin/Java package MainActivity.kt and SmsReceiver.kt compile
    // into) is intentionally NOT flavor-specific — Android resolves the
    // manifest's `.SmsReceiver`/`.MainActivity` against `namespace`, not
    // `applicationId`, so the native SMS receiver keeps working unchanged
    // in both flavors.
    flavorDimensions += "environment"
    productFlavors {
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "paysense")
        }
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "PaySense Test")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
