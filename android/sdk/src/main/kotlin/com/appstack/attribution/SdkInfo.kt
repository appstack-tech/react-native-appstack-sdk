package com.appstack.attribution

/**
 * Central place to expose SDK metadata that can be accessed from anywhere in the
 * codebase without repeating hard-coded literals.
 */
internal object SdkInfo {
    /** Runtime SDK version injected from Gradle BuildConfig */
    val VERSION: String = BuildConfig.SDK_VERSION
} 