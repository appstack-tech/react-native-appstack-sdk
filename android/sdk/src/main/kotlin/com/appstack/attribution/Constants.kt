package com.appstack.attribution

/**
 * Centralised SDK-wide constant values that are **build-time** parameters rather than
 * remotely configurable ones. Moving them here makes it explicit which settings are
 * hard-coded in the SDK and which ones can be supplied by the backend at runtime.
 */
object Constants {
    /** Default interval (in ms) at which the SDK flushes queued events. */
    const val FLUSH_INTERVAL_MS: Long = 1_800_000L // 30 minutes

    /** How often (in ms) the SDK refreshes the remote configuration. */
    const val CONFIG_REFRESH_INTERVAL_MS: Long = 6 * 60 * 60 * 1000L // 6 hours

    /** Maximum number of events kept in memory / on disk before drops occur. */
    const val MAX_QUEUE_SIZE: Int = 1_000

    /** Maximum number of events the SDK will send per hour before throttling. */
    const val THROTTLE_EVENTS_PER_HOUR: Int = 300

    /** Maximum number of retry attempts for network calls before failing permanently. */
    const val RETRY_MAX_ATTEMPTS: Int = 5

    /** Number of consecutive failures after which the circuit-breaker opens. */
    const val CIRCUIT_BREAKER_THRESHOLD: Int = 5

    /** Minimum periodic interval for WorkManager periodic tasks. */
    const val MIN_WORKER_INTERVAL_MS = 15 * 60 * 1000L // 15 minutes

    /** Maximum number of events to send in a single batch. */
    const val MAX_EVENT_BATCH_SIZE = 50

    /** Cooldown period in milliseconds for the circuit breaker. */
    const val CIRCUIT_BREAKER_COOLDOWN_MS: Long = 5 * 60 * 1000L // 5 minutes

    /** Timeout in milliseconds for fetching the Play Store referrer. */
    const val REFERRER_FETCH_TIMEOUT_MS: Long = 5_000L

    /** UTM medium value for organic installs. */
    const val ORGANIC_UTM_MEDIUM = "organic"

    // --- Storage Keys ---
    const val KEY_SENT_INSTALL = "appstack_install_sent"
    const val KEY_QUEUE_JSON = "appstack_event_queue"
    const val KEY_RAW_ID = "appstack_install_id"
    const val KEY_CACHED_REFERRER = "appstack_cached_referrer"
    const val DEFAULT_PREFS_NAME: String = "appstack_attribution_sdk_prefs"
}
