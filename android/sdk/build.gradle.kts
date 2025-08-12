plugins {
    id("com.android.library")
    kotlin("android")
    id("com.google.devtools.ksp")
    id("com.vanniktech.maven.publish") version "0.33.0"
}

android {
    namespace = "com.appstack.attribution"
    version = "0.0.1-SNAPSHOT"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Bundle the keep-rules defined in `consumer-rules.pro` inside the AAR so that
        // every application consuming the SDK automatically inherits the necessary
        // ProGuard/R8 configuration and avoids `ClassNotFoundException` at runtime.
        consumerProguardFiles("consumer-rules.pro")
        // Inject SDK version constant for runtime access
        buildConfigField("String", "SDK_VERSION", "\"$version\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    // Specify targetSdk for lint instead of defaultConfig (library module)
    lint {
        targetSdk = 34
    }

    // Allow Robolectric tests to access merged Android resources (strings, manifests, etc.)
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }

    // Expose the library version at runtime via BuildConfig so we avoid manual duplication
    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    // Note: React Native dependencies will be provided by the host app at runtime
    compileOnly("com.facebook.react:react-native:+") // React Native bridge dependencies

    // Kotlin Coroutines – keep versions aligned via BOM
    implementation(platform("org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.7.3"))
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android")

    // Moshi JSON
    implementation("com.squareup.moshi:moshi:1.15.0")
    implementation("com.squareup.moshi:moshi-kotlin:1.15.0")
    ksp("com.squareup.moshi:moshi-kotlin-codegen:1.15.0")

    // Retrofit & OkHttp
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-moshi:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // AndroidX WorkManager & Install Referrer
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("com.android.installreferrer:installreferrer:2.2")
    implementation("androidx.annotation:annotation:1.7.1")

    // AndroidX Lifecycle
    implementation("androidx.lifecycle:lifecycle-process:2.7.0")

    // Test Dependencies
    testImplementation("junit:junit:4.13.2")
    testImplementation("com.google.truth:truth:1.4.2")
    testImplementation("androidx.test:core:1.5.0")
    testImplementation("org.robolectric:robolectric:4.14")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test")
    testImplementation("org.mockito:mockito-core:5.11.0")
    testImplementation("androidx.work:work-testing:2.9.0")
    // Additional dependencies for integration (Robolectric) tests
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    testImplementation("androidx.lifecycle:lifecycle-process:2.7.0")
}

// ---------------------------------------------------------------------------
// Maven Central publishing configuration handled by Vanniktech plugin
// ---------------------------------------------------------------------------

mavenPublishing {
    // Publish & automatically release via Central Portal
    // Will publish to   https://central.sonatype.com/repository/maven-snapshots/tech/app-stack/sdk/appstack-android-sdk/0.0.1-SNAPSHOT/maven-metadata.xml
    publishToMavenCentral(automaticRelease = true)

    // Sign all artifacts (required for Maven Central). The key is provided via
    // the ORG_GRADLE_PROJECT_signingInMemoryKey(_Password/Id) environment vars
    signAllPublications()

    // Coordinates of the published library
    coordinates("tech.app-stack.sdk", "appstack-android-sdk", "0.0.1-SNAPSHOT")

    // Optional but recommended – enrich the generated POM
    pom {
        name.set("Appstack Android SDK")
        description.set("Lightweight Android attribution & analytics SDK")
        inceptionYear.set("2025")
        url.set("https://github.com/appstack-tech/appstack-android-sdk")
        licenses {
            license {
                name.set("The Apache License, Version 2.0")
                url.set("https://www.apache.org/licenses/LICENSE-2.0.txt")
                distribution.set("repo")
            }
        }
        developers {
            developer {
                id.set("tomdarmon-appstack")
                name.set("Tom Darmon")
                url.set("https://github.com/tomdarmon-appstack")
            }
        }
        scm {
            url.set("https://github.com/appstack-tech/appstack-android-sdk")
            connection.set("scm:git:git://github.com/appstack-tech/appstack-android-sdk.git")
            developerConnection.set("scm:git:ssh://git@github.com/appstack-tech/appstack-android-sdk.git")
        }
    }
} 