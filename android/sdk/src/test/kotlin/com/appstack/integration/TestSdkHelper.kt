package com.appstack.sample

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.testing.WorkManagerTestInitHelper
import com.appstack.attribution.AppStackAttributionSdk
import com.appstack.attribution.Config
import com.appstack.attribution.LogLevel

/** Convenience helper that wires up WorkManager **and** the SDK for unit / Robolectric tests. */
object TestSdkHelper {

    /**
     * Initialises WorkManager in test mode and boots the Attribution SDK with the provided [backend].
     * If the SDK is already initialised this call is a no-op.
     */
    fun initSdk(backend: TestBackend, logLevel: LogLevel = LogLevel.DEBUG) {
        val context: Context = ApplicationProvider.getApplicationContext()

        // WorkManager must be initialised exactly once – catch and ignore the second init.
        try {
            WorkManagerTestInitHelper.initializeTestWorkManager(context)
        } catch (t: Throwable) {
            // Swallow repeated initialisation or Robolectric oddities but log for debugging.
            t.printStackTrace()
        }

        println("[TestSdkHelper] backend base URL: ${backend.baseUrl}")

        // Force initialisation of ProcessLifecycleOwner to avoid NPE when the SDK registers
        // its lifecycle observer in Robolectric where the owner might be lazy.
        try {
            androidx.lifecycle.ProcessLifecycleOwner.get()
        } catch (_: Throwable) {
            // Ignore – not critical for unit tests.
        }

        val config = Config(
            apiKey = "sample-api-key",
            endpointBaseUrl = backend.baseUrl,
            logLevel = logLevel,
        )

        // If the SDK has already been initialised in this JVM we cannot call init() again because it
        // bails out early. Instead, we *surgically* swap the underlying NetworkClient instance so
        // that each test can use its own [TestBackend] without interference. This is admittedly a
        // hack, but it avoids having to expose a public reset() API solely for tests.

        val sdkClass = AppStackAttributionSdk::class.java
        val componentsField = sdkClass.getDeclaredField("components").apply { isAccessible = true }
        val alreadyInit = try {
            componentsField.get(AppStackAttributionSdk::class.java)
            true
        } catch (_: UninitializedPropertyAccessException) {
            false
        }

        if (!alreadyInit) {
            try {
                AppStackAttributionSdk.init(context, config)
            } catch (t: Throwable) {
                t.printStackTrace()
                throw t
            }
        } else {
            // Replace the network client base URL so outbound calls hit our MockWebServer.
            val comps = componentsField.get(AppStackAttributionSdk::class.java)
            val networkField = comps.javaClass.getDeclaredField("network").apply { isAccessible = true }
            networkField.set(comps, com.appstack.attribution.RetrofitClient(backend.baseUrl, config.apiKey))
        }
    }
} 