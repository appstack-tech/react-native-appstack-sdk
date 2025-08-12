package com.appstack.sample

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import java.io.Closeable
import java.util.concurrent.TimeUnit

/**
 * Minimal wrapper around [MockWebServer] that provides the canned endpoints expected by the
 * Attribution SDK ( /config, /install, /event ). The goal is to hide *all* MockWebServer-specific
 * API behind a simple, intention-revealing façade so that tests themselves remain completely
 * agnostic of the underlying HTTP-mock implementation.
 */
class TestBackend(private val appId: String = "com.appstack.sample") : Closeable {

    private val server = MockWebServer()

    /** Base URL to configure the Attribution SDK with (always ends with a slash). */
    val baseUrl: String get() = server.url("/").toString()

    /** Starts the underlying [MockWebServer]. Must be called before using [baseUrl]. */
    fun start() = server.start()

    /** Stops the server and frees the TCP port. */
    override fun close() = server.shutdown()

    /** Enqueue the standard sequence: 1× /config, *n*× /event. */
    fun enqueueDefaultSequence(eventFlushResponses: Int = 1) {
        enqueueRemoteConfig()
        repeat(eventFlushResponses) { enqueueEventSuccess() }
    }

    fun enqueueRemoteConfig(json: String = defaultRemoteConfigJson()) {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(json)
        )
    }

    fun enqueueEventSuccess() {
        server.enqueue(
            MockResponse()
                .setResponseCode(202)
                .setBody("{}")
        )
    }

    // ----------------------------------------------------------
    // Assertion helpers – make integration tests more readable.
    // ----------------------------------------------------------

    /**
     * Fails the test if any request is received within [timeout].  Useful at the
     * end of a scenario to validate that **no** extra calls were performed.
     */
    fun assertNoQueuedRequests(timeout: Long = 100, unit: TimeUnit = TimeUnit.MILLISECONDS) {
        val unexpected = takeRequest(timeout, unit)
        require(unexpected == null) {
            "Expected no further requests but captured one: ${'$'}{unexpected?.requestLine}"
        }
    }

    /**
     * Retrieve the next request the SDK made (or *null* if the timeout expired).
     *
     * The previous 1-second default proved too aggressive on some CI machines where
     * thread scheduling can be slower, causing flakiness when the SDK performs its
     * initial remote-config fetch on a background coroutine.  We now default to a
     * more forgiving 10-second window while still allowing callers to override.
     */
    fun takeRequest(timeout: Long = 10, unit: TimeUnit = TimeUnit.SECONDS) =
        server.takeRequest(timeout, unit)

    private fun defaultRemoteConfigJson(): String = """
        {
          "app_id": "$appId",
          "enabled": true,
          "flush_interval_ms": 1800000,
          "config_refresh_interval_ms": 21600000,
          "max_queue_size": 1000,
          "throttle_events_per_hour": 300,
          "retry_max_attempts": 5,
          "circuit_breaker_threshold": 5,
          "log_level": "DEBUG"
        }
    """.trimIndent()
} 