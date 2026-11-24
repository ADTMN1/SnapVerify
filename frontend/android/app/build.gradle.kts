import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true) ||
        it.contains("signingReport", ignoreCase = true)
}

fun resolveReleaseKeystore(properties: Properties): File {
    val storeFileValue = properties.getProperty("storeFile")?.trim()
        ?: throw GradleException("android/key.properties is missing required property: storeFile")
    val keystoreFile = File(storeFileValue).let {
        if (it.isAbsolute) it else rootProject.file(storeFileValue)
    }
    if (!keystoreFile.isFile) {
        throw GradleException("Release keystore file does not exist: ${keystoreFile.absolutePath}")
    }
    return keystoreFile
}

val releaseSigning: Pair<Properties, File>? = if (releaseSigningRequested) {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (!keyPropertiesFile.isFile) {
        throw GradleException(
            "Release signing requires android/key.properties. " +
                "Add storeFile, storePassword, keyAlias, and keyPassword."
        )
    }
    val properties = Properties()
    keyPropertiesFile.inputStream().use { properties.load(it) }
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { properties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing required properties: " +
                missing.joinToString(", ")
        )
    }
    properties to resolveReleaseKeystore(properties)
} else null

android {
    namespace = "com.snapverify.snapverify"
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
        applicationId = "com.snapverify.snapverify"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            releaseSigning?.let { (properties, keystoreFile) ->
                keyAlias = properties.getProperty("keyAlias")!!.trim()
                keyPassword = properties.getProperty("keyPassword")
                storeFile = keystoreFile
                storePassword = properties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
