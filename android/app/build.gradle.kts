import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Load keystore props (safe) ---
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// Helper to expand '~' & ensure non-null strings
fun prop(name: String): String? = (keystoreProperties[name] as String?)?.let {
    if (it.startsWith("~/")) it.replace("~", System.getProperty("user.home")) else it
}

// Only use release signing if *all* fields are present
val hasReleaseKeystore =
    keystorePropertiesFile.exists() &&
    !prop("storeFile").isNullOrBlank() &&
    !prop("storePassword").isNullOrBlank() &&
    !prop("keyAlias").isNullOrBlank() &&
    !prop("keyPassword").isNullOrBlank()

android {
    // ✅ matches your package & folders
    namespace = "com.funkin.karaoke"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.funkin.karaoke"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(prop("storeFile")!!)
                storePassword = prop("storePassword")
                keyAlias = prop("keyAlias")
                keyPassword = prop("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // ✅ Only use real release key if we have it; otherwise fall back to debug to avoid NPE
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}