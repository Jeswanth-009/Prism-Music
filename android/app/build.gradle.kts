import java.util.Properties


plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.prismmusic.prism_music"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    lint {
        disable.add("EasterEgg")
        disable.add("StopShip")
        abortOnError = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }



    defaultConfig {
        // Prism Music - Privacy-first music streaming app
        applicationId = "com.prismmusic.app"
        // Minimum SDK 24 for proper audio/permission handling
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode ?: 1
        versionName = flutter.versionName
        
        // Enable multidex for large app
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    val allowDebugSigning = project.hasProperty("debugSigning") && project.property("debugSigning") == "true"

    buildTypes {
        release {
            // Require production key.properties for signed release builds.
            // Debug key signing is never used implicitly for release builds;
            // it requires explicit -PdebugSigning=true for local/CI test builds.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (allowDebugSigning) {
                signingConfigs.getByName("debug")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}
