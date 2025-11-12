// android/settings.gradle.kts
pluginManagement {
    // Locate Flutter SDK from local.properties
    val flutterSdkPath = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        val p = props.getProperty("flutter.sdk")
        require(p != null) { "flutter.sdk not set in local.properties" }
        p
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Required so Gradle can download Flutter engine artifacts (io.flutter:*).
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }

    // Versions for AGP/Kotlin/GMS/Flutter loader
    plugins {
        id("com.android.application") version "8.9.1"
        id("org.jetbrains.kotlin.android") version "2.1.0"
        id("com.google.gms.google-services") version "4.4.2"
        id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // Again here for runtime dependency resolution
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

include(":app")