import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release keystore if android/key.properties or key.properties exists
val keystorePropertiesFile = file("../key.properties").takeIf { it.exists() }
    ?: file("key.properties").takeIf { it.exists() }
    ?: rootProject.file("key.properties").takeIf { it.exists() }

val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile != null
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile!!))
}

android {
    namespace = "com.atex.atex_music"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.atex.atex_music"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                val storePath = keystoreProperties.getProperty("storeFile")
                storeFile = if (storePath != null) {
                    val candidate = file(storePath)
                    if (candidate.exists()) candidate else rootProject.file(storePath)
                } else {
                    null
                }
                storePassword = keystoreProperties.getProperty("storePassword")
            } else {
                // Safe fallback to debug keys so local & CI builds without secrets never fail
                val debugConfig = signingConfigs.getByName("debug")
                keyAlias = debugConfig.keyAlias
                keyPassword = debugConfig.keyPassword
                storeFile = debugConfig.storeFile
                storePassword = debugConfig.storePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
