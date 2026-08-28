import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// PLAY STORE PREPARATION: the standard Flutter release-signing pattern
// (https://flutter.dev/to/reference-keystore). `android/key.properties`
// is ALREADY gitignored (see android/.gitignore) — it was never created
// with real values by this codebase, and never will be by an automated
// pass; only the app owner can generate a real release keystore. When
// that file doesn't exist (true today), `releaseSigningConfig` below is
// null and the release build type falls back to the debug keystore
// exactly as it always has — zero behavior change until the owner adds
// the real file. See android/key.properties.example for the exact
// format to supply REAL_RELEASE_KEYSTORE/REAL_KEYSTORE_PASSWORD/
// REAL_KEY_ALIAS/REAL_KEY_PASSWORD.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystoreConfig = keystorePropertiesFile.exists()
if (hasReleaseKeystoreConfig) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        if (hasReleaseKeystoreConfig) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Uses the real release keystore the instant android/key.properties
            // exists (see the file-level comment above) — until then, this
            // stays exactly what it always was: signed with the debug keys so
            // `flutter run --release`/local testing keeps working.
            signingConfig = if (hasReleaseKeystoreConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
