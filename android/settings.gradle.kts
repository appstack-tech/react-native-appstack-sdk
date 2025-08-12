// ------------------------------------------------------------------------------
// Centralised plugin versions – keeps individual module build files minimal
// and allows the project to be built with a plain `gradle` installation.
// ------------------------------------------------------------------------------

pluginManagement {
    repositories {
        // Required for Android Gradle Plugin
        google()
        // Required for Kotlin Gradle Plugin and other community plugins
        mavenCentral()
        gradlePluginPortal()
    }

    plugins {
        // Android Gradle Plugin (application & library variants)
        id("com.android.application") version "8.12.0"
        id("com.android.library") version "8.12.0"

        // Kotlin plugins (jvm/android/kapt etc.)
        kotlin("android") version "1.9.24"
        kotlin("kapt") version "1.9.24"
        id("com.google.devtools.ksp") version "1.9.24-1.0.20"
        // Vanniktech plugin for publishing to Maven Central
        id("com.vanniktech.maven.publish") version "0.33.0"
    }
}

include(
    ":sdk",
    ":sample-app",
)