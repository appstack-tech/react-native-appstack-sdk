package com.appstack.sample

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ProcessLifecycleOwner
import com.appstack.attribution.AppStackAttributionSdk
import com.appstack.attribution.EventType
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config as RobolectricConfig

/**
 * Verifies that the SDK flushes pending events automatically when the application moves to the
 * background ("user quits the app"). The test uses [MockWebServer] to capture outgoing network
 * requests, so no real backend is needed.
 */
@RunWith(RobolectricTestRunner::class)
@org.junit.Ignore("Flaky under merged test environment – investigation pending")
@RobolectricConfig(
    sdk = [34],
    manifest = RobolectricConfig.NONE,
)
class AppLifecycleFlushTest {

    private lateinit var backend: TestBackend

    @Before
    fun setUp() {
        backend = TestBackend().apply {
            start()
            enqueueDefaultSequence(eventFlushResponses = 1)
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
    fun `events are flushed automatically when app backgrounds`() = runBlocking {
        // 1) Wait for the /config request (SDK remote configuration fetch).
        AppStackAttributionSdk.refreshConfig()
        val configReq = backend.takeRequest()
        assertThat(configReq?.path.orEmpty()).contains("/config")

        // 2) Track an event which should remain queued until ON_STOP triggers an automatic flush.
        AppStackAttributionSdk.trackEvent(EventType.SIGN_UP)

        // 3) Simulate the host app moving to background.
        val lifecycle = ProcessLifecycleOwner.get().lifecycle as LifecycleRegistry
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_STOP)

        // Give the async flush coroutine a moment to run.
        delay(500)

        // 4) Verify that the SDK posted the queued event.
        var eventRequestSeen = false
        repeat(2) { // two potential /event requests (INSTALL first, then user event)
            val req = backend.takeRequest() ?: return@repeat
            if ("/event" == req.path) eventRequestSeen = true
        }

        assertThat(eventRequestSeen).isTrue()
    }
} 