import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

val hkdAppLinkHost =
    (project.findProperty("HKD_APP_LINK_HOST") as String?)?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?: "example.pages.dev"

android {
    namespace = "org.hataykuryeler.hkd"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.hataykuryeler.hkd"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["hkdAppLinkHost"] = hkdAppLinkHost
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties.getProperty("storeFile", "").trim()
                val storePasswordValue = keystoreProperties.getProperty("storePassword", "").trim()
                val keyAliasValue = keystoreProperties.getProperty("keyAlias", "").trim()
                val keyPasswordValue = keystoreProperties.getProperty("keyPassword", "").trim()

                if (storeFilePath.isNotEmpty()) {
                    storeFile = file(storeFilePath)
                }
                if (storePasswordValue.isNotEmpty()) {
                    storePassword = storePasswordValue
                }
                if (keyAliasValue.isNotEmpty()) {
                    keyAlias = keyAliasValue
                }
                if (keyPasswordValue.isNotEmpty()) {
                    keyPassword = keyPasswordValue
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
