import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val releaseSigningProperties = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val releaseSigningConfigured = releaseSigningProperties.all {
    !keystoreProperties.getProperty(it).isNullOrBlank()
}

android {
    namespace = "ucuzgetir.com"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ucuzgetir.com"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

val validateReleaseSigning by tasks.registering {
    doLast {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Release signing is not configured. Create android/key.properties with " +
                    "keyAlias, keyPassword, storeFile, and storePassword.",
            )
        }
        val keystoreFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
        if (!keystoreFile.isFile) {
            throw GradleException("Release keystore does not exist: $keystoreFile")
        }
    }
}

tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }
    .configureEach {
        dependsOn(validateReleaseSigning)
    }

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
