import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

fun requiredSigningProperty(name: String): String {
    return keystoreProperties.getProperty(name)
        ?: throw GradleException(
            "Android release signing requires '$name' in android/key.properties. " +
                "Debug signing is not an acceptable fallback for published APKs."
        )
}

android {
    namespace = "mx.buap.loboapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Updated to match url_launcher_android requirements

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "mx.buap.loboapp"
        minSdk = 24 // Play Store exige 24+ desde 2025
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// A published release without key.properties would otherwise fail late with a
// vague signing error. Stop before compilation and say exactly what is missing.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release", ignoreCase = true) } &&
        !keystorePropertiesFile.exists()
    ) {
        throw GradleException(
            "Cannot build an Android release without android/key.properties. " +
                "Restore the permanent LoboApp signing key; never substitute a debug key."
        )
    }
}

flutter {
    source = "../.."
}
