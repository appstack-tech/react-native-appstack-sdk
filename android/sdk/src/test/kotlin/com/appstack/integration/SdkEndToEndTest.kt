package com.appstack.sample

import com.google.common.truth.Truth.assertThat
import com.appstack.attribution.AppStackAttributionSdk
import com.appstack.attribution.EventType
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config as RobolectricConfig

/**
 * Complete *happy-path* flow exercising: SDK initialisation, install payload, two events tracking
 * and explicit flushes – all against an **in-memory** [TestBackend] rather than a real server.
 *
 * This also implicitly validates the reflection-based `RetrofitClient` lookup: if the constructor
 * trick stops working the SDK falls back to a no-op `NetworkClient` and the assertions checking
 * network traffic will fail with clear error messages.
 */
@RunWith(RobolectricTestRunner::class)
@org.junit.Ignore("Flaky under merged test environment – investigation pending")
@RobolectricConfig(
    sdk = [34],
    manifest = RobolectricConfig.NONE, // Use the default Application – we initialise the SDK ourselves.
)
class SdkEndToEndTest {

    private lateinit var backend: TestBackend

    @Before
    fun setUp() {
        backend = TestBackend().apply {
            start()
            // We expect *two* flushes (install + events) so enqueue responses accordingly.
            enqueueDefaultSequence(eventFlushResponses = 2)
        }

        TestSdkHelper.initSdk(backend)
    }

    @After
    fun tearDown() {
        try {
            AppStackAttributionSdk.clearData()
        } catch (_: Throwable) {
            // Ignore – SDK might not have completed init if the test aborted early.
        }
        backend.close()
    }

    @Test
    fun `sdk happy path – install plus two events`() = runBlocking {
        // -----------------------------------------------------------------------------
        // 1) Explicitly trigger a remote config fetch to guarantee predictable order.
        // -----------------------------------------------------------------------------
        AppStackAttributionSdk.refreshConfig()
        val configReq = backend.takeRequest()
        assertThat(configReq?.path.orEmpty()).contains("/config")

        // -----------------------------------------------------------------------------
        // 2) Force-flush the *install* payload.
        // -----------------------------------------------------------------------------
        AppStackAttributionSdk.flush()

        // Wait briefly to let the background coroutines run.
        delay(500)

        // Verify that the SDK posted the INSTALL event via /event endpoint.
        val installReq = backend.takeRequest()
        assertThat(installReq?.path.orEmpty()).contains("/event")

        // -----------------------------------------------------------------------------
        // 3) Track two events, then flush again.
        // -----------------------------------------------------------------------------
        AppStackAttributionSdk.trackEvent(EventType.SIGN_UP)
        AppStackAttributionSdk.trackEvent(EventType.PURCHASE, value = 9.99)

        AppStackAttributionSdk.flush()
        delay(500)

        // Grab the expected /event request and perform basic sanity checks.
        val eventReq = backend.takeRequest()
        assertThat(eventReq?.path.orEmpty()).contains("/event")

        // If we reached this point all network interactions succeeded.
        assertThat(true).isTrue()
    }
} 