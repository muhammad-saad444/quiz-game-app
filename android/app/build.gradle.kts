plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.realtime_answer_detector"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.realtime_answer_detector"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.

        // 👇 FIXED: Explicitly upgraded minSdk to 30 to support local audio processing
        minSdk = 30
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

// FIXED GRADLE STRIPPER HOOK:
// Targets the exact legacy package signature 'org.vosk.vosk_flutter' to cleanly satisfy AGP criteria
rootProject.subprojects {
    afterEvaluate {
        // --- Vosk Configuration Block ---
        if (name == "vosk_flutter_2") {
            extensions.findByName("android")?.let { androidExtension ->
                @Suppress("UNCHECKED_CAST")
                (androidExtension as? com.android.build.api.dsl.CommonExtension<*, *, *, *, *, *>)?.apply {
                    namespace = "org.vosk.vosk_flutter_2"
                }
            }

            tasks.matching { it.name.contains("process") && it.name.contains("Manifest") }.configureEach {
                doFirst {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        var content = manifestFile.readText()
                        if (content.contains("package=\"org.vosk.vosk_flutter\"")) {
                            content = content.replace("package=\"org.vosk.vosk_flutter\"", "")
                            manifestFile.writeText(content)
                        }
                    }
                }
            }
        }

        // --- LiveSpeechToText Configuration Block (Maintained for safety) ---
        if (name == "livespeechtotext") {
            extensions.findByName("android")?.let { androidExtension ->
                @Suppress("UNCHECKED_CAST")
                (androidExtension as? com.android.build.api.dsl.CommonExtension<*, *, *, *, *, *>)?.apply {
                    namespace = "com.overmycloud.livespeechtotext"
                }
            }

            tasks.matching { it.name.contains("process") && it.name.contains("Manifest") }.configureEach {
                doFirst {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        var content = manifestFile.readText()
                        if (content.contains("package=\"com.overmycloud.livespeechtotext\"")) {
                            content = content.replace("package=\"com.overmycloud.livespeechtotext\"", "")
                            manifestFile.writeText(content)
                        }
                    }
                }
            }
        }
    }
}