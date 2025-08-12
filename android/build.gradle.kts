plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    kotlin("android") apply false
    id("com.google.devtools.ksp") apply false
    id("com.vanniktech.maven.publish") apply false
    // Only used for version catalogs & build logic; individual modules apply Android/Kotlin plugins.
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://www.jitpack.io")
        }
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent { snapshotsOnly() }
        }
    }
}

