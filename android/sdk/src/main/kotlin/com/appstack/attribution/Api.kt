package com.appstack.attribution

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import com.squareup.moshi.Json
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import android.app.Activity
import android.view.ViewGroup

/** Listener notified of critical initialisation errors (e.g. missing network impl). */
fun interface InitListener { fun onError(t: Throwable) }

/**
 * Root entry-point for the AppStack Attribution SDK.
 *
 * The SDK is intentionally _thin_; all heavy lifting lives in pluggable
 * modules resolved via dependency injection to maximise testability.
 */
object AppStackAttributionSdk {

    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private lateinit var components: Components
    private var isDebugModeEnabled: Boolean = false

    /** Initialise the SDK in one line from `Application.onCreate`. */
    @JvmStatic
    fun configure(
        context: Context,
        apiKey: String,
        isDebug: Boolean,
        endpointBaseUrl: String = "http://10.0.2.2:8000",
        logLevel: LogLevel = LogLevel.INFO,
        listener: InitListener? = null
    ) {
        if (::components.isInitialized) return // already init
        val config = Config(
            apiKey = apiKey,
            endpointBaseUrl = endpointBaseUrl,
            logLevel = logLevel,
            debugModeEnabled=isDebug
        )

        isDebugModeEnabled = config.debugModeEnabled
        DebugStateProvider.init(isDebugModeEnabled)

        // Apply the log level supplied by the host app immediately
        Logger.setLevel(config.logLevel)

        components = Components.makeDefault(context, config, listener)

        if (isDebugModeEnabled) {
            DebugStateProvider.update("SDK Version", SdkInfo.VERSION)
            DebugStateProvider.update("Endpoint", config.endpointBaseUrl)
            DebugStateProvider.update("Installation ID", components.installationIdProvider.getInstallationId())
        }

        // Register a process-wide lifecycle observer so we flush when the app backgrounds.
        try {
            androidx.lifecycle.ProcessLifecycleOwner.get().lifecycle.addObserver(AppLifecycleObserver)
        } catch (_: Throwable) {
            // ProcessLifecycleOwner is part of the lifecycle-process artifact; if the host app
            // strips it via proguard or removes the component we just skip the optimisation.
        }

        // Finalise SDK setup once the remote config has been fetched in the background
        components.remoteConfigDeferred.invokeOnCompletion {
            scope.launch(Dispatchers.Main.immediate) {
                val rc = try {
                    components.remoteConfigDeferred.await()
                } catch (e: AuthenticationException) {
                    // Authentication failed - disable SDK permanently
                    Logger.e("AppStackSdk", "Authentication failed - SDK disabled: $e")
                    components.isDisabled = true
                    return@launch
                } catch (t: Throwable) {
                    // In case of failure we keep using the placeholder already set
                    Logger.w("AppStackSdk", "Remote config fetch failed: $t")
                    components.remoteConfig
                }

                if (isDebugModeEnabled) {
                    DebugStateProvider.update("App ID", rc.appId)
                    scope.launch(Dispatchers.IO) {
                        val referrer = components.referrerProvider.getInstallReferrer()
                        DebugStateProvider.update("Raw Referrer", referrer?.rawReferrer)
                    }
                }

                // Apply the fetched configuration to all sub-components
                components.applyRemoteConfig(rc)

                // Remote config fetched. Log level remains as initially set; remote config does not override it.

                // Schedule periodic flushes via WorkManager once we know the correct interval
                FlushWorker.schedule(
                    context,
                    Constants.FLUSH_INTERVAL_MS,
                )

                // Schedule periodic config refresh via WorkManager
                if (config.remoteConfigEnabled) {
                    ConfigRefreshWorker.schedule(
                        context,
                        Constants.CONFIG_REFRESH_INTERVAL_MS,
                    )
                }

                // Send install payload only after we have a definitive config
                sendInstallIfFirstLaunch()
            }
        }
    }

    /** Track an event (fire-and-forget). */
    @JvmStatic
    fun sendEvent(event: EventType, name: String? = null, revenue: Double? = null) {
        ensureReady()
        if (components.isDisabled || !components.remoteConfig.enabled) return
        components.eventTracker.trackEvent(type=event, name=name, value=revenue)
    }

    /** Instruct the queue to flush immediately. */
    @JvmStatic
    fun flush() {
        ensureReady()
        if (components.isDisabled || !components.remoteConfig.enabled) return

        // Delay explicit flush until remote configuration is ready to avoid missing critical
        // settings such as endpoints and throttling parameters.
        if (components.remoteConfigDeferred.isCompleted) {
            components.flushScheduler.flushNow()
        }
    }

    /** Shows a debug overlay on top of the current activity. Requires `debugModeEnabled=true` in Config. */
    @JvmStatic
    fun showDebugOverlay(activity: Activity) {
        if (!isDebugModeEnabled) {
            Logger.w("AppStackSdk", "showDebugOverlay() called but debugModeEnabled is false.")
            return
        }

        val rootView = activity.findViewById<ViewGroup>(android.R.id.content)
        if (rootView.findViewWithTag<DebugOverlayView>(DebugOverlayView.TAG) != null) {
            return // already attached
        }

        val overlay = DebugOverlayView(activity)
        rootView.addView(overlay)
    }

    @JvmStatic
    fun isEnabled(): Boolean = components.remoteConfig.enabled

    @JvmStatic
    fun clearData() {
        ensureReady()
        components.storage.clear()
    }

    /** 
     * Refresh the remote configuration and update dependent components if config has changed.
     * This is called periodically by ConfigRefreshWorker.
     */
    @JvmStatic
    suspend fun refreshConfig() {
        ensureReady()
        if (components.isDisabled) return

        try {
            val newConfig = components.network.fetchRemoteConfig()
            components.updateRemoteConfigIfChanged(newConfig)
        } catch (e: AuthenticationException) {
            Logger.e("AppStackSdk", "Authentication failed during config refresh - SDK disabled: $e")
            components.isDisabled = true
            throw e
        } catch (t: Throwable) {
            Logger.w("AppStackSdk", "Failed to refresh remote config: $t")
            throw t
        }
    }

    private fun ensureReady() {
        check(::components.isInitialized) { "AppStackAttributionSdk.configure() must be called first." }
    }

    private fun sendInstallIfFirstLaunch() {
        val storage = components.storage
        if (storage.getString(Constants.KEY_SENT_INSTALL) != null) return

        if (components.isDisabled || !components.remoteConfig.enabled) return

        scope.launch(kotlinx.coroutines.Dispatchers.IO) {
            val referrer = components.referrerProvider.getInstallReferrer()

            // Create a synthetic "INSTALL" event, which is tracked automatically by the SDK.
            val installEvent = TrackedEvent(
                type = EventType.INSTALL.name,
                name = null,
                ts = System.currentTimeMillis() / 1000,
                value = null,
                rawReferrer = referrer?.rawReferrer,
                referrerClickTimestampSec = referrer?.referrerClickTimestampSec,
                appInstallTimestampSec = referrer?.appInstallTimestampSec,
            )

            val batch = EventsBatchPayload(
                appId = components.remoteConfig.appId,
                installationId = components.installationIdProvider.getInstallationId(),
                sdkVersion = SdkInfo.VERSION,
                utmSource = referrer?.utmSource,
                utmMedium = referrer?.utmMedium,
                utmCampaign = referrer?.utmCampaign,
                utmTerm = referrer?.utmTerm,
                utmContent = referrer?.utmContent,
                gclid = referrer?.gclid,
                rawReferrer = referrer?.rawReferrer,
                referrerClickTimestampSec = referrer?.referrerClickTimestampSec,
                appInstallTimestampSec = referrer?.appInstallTimestampSec,
                events = listOf(installEvent),
            )

            try {
                components.network.postEvents(batch)
                storage.putString(Constants.KEY_SENT_INSTALL, "1")
                Logger.i("AppStackSdk", "Install event sent via /event endpoint")
                DebugStateProvider.update("Install Event Sent", "Success (${DebugStateProvider.now()})")
            } catch (e: AuthenticationException) {
                Logger.e("AppStackSdk", "Authentication failed while sending install event: $e")
                // Mark as sent to avoid retrying with invalid credentials
                storage.putString(Constants.KEY_SENT_INSTALL, "1")
                DebugStateProvider.update("Install Event Sent", "Auth Failure (${DebugStateProvider.now()})")
            } catch (t: Throwable) {
                Logger.w("AppStackSdk", "Failed to send install event: $t")
                DebugStateProvider.update("Install Event Sent", "Network Failure (${DebugStateProvider.now()})")
            }
        }
    }
}

// ------------------------------------------------------------------------------------
// Public models & enums (kept minimal – everything else lives in internal packages)
// ------------------------------------------------------------------------------------

data class Config(
    /** Public API key used to authenticate SDK network calls. */
    val apiKey: String,
    /** Base URL of the backend API (e.g. "https://api.example.com/"). */
    val endpointBaseUrl: String,
    /** Minimum log level printed by the SDK. */
    val logLevel: LogLevel = LogLevel.INFO,
    /** When `false`, the SDK will not fetch configuration from the endpoint and will use the local configuration below. Defaults to `true`. */
    val remoteConfigEnabled: Boolean = true,
    /** App-specific identifier. If `null`, the [apiKey] will be used. This value is only used when [remoteConfigEnabled] is `false`. */
    val appId: String? = null,
    /** Whether the SDK is enabled entirely. This value is only used when [remoteConfigEnabled] is `false`. */
    val sdkEnabled: Boolean = true,
    /** When `true`, enables an in-app debug overlay to inspect SDK state. Defaults to `false`. */
    val debugModeEnabled: Boolean = false,
)

enum class LogLevel { DEBUG, INFO, WARN, ERROR }


// ------------------------------------------------------------------------------------
// Interfaces – they live here so that every module can depend only on :core
// ------------------------------------------------------------------------------------

interface StorageProvider {
    fun putString(key: String, value: String)
    fun getString(key: String): String?
    fun remove(key: String)
    fun clear()
}

interface ReferrerProvider {
    suspend fun getInstallReferrer(): UTMParameters?
}

interface EventSerializer {
    fun serialize(event: TrackedEvent): String
}

interface ConfigProvider {
    suspend fun fetchRemoteConfig(): RemoteConfig
}

interface InstallationIdProvider {
    /** Returns a stable installation-scoped identifier (UUID). */
    fun getInstallationId(): String
}

interface NetworkClient {
    suspend fun postEvents(payload: EventsBatchPayload)

    /** Retrieve the latest remote configuration for this API key. */
    suspend fun fetchRemoteConfig(): RemoteConfig
}

// ------------------------------------------------------------------------------------
// Internal data classes representing network payloads.
// ------------------------------------------------------------------------------------

data class UTMParameters(
    @Json(name = "utm_source")
    val utmSource: String? = null,
    @Json(name = "utm_medium")
    val utmMedium: String? = null,
    @Json(name = "utm_campaign")
    val utmCampaign: String? = null,
    @Json(name = "utm_term")
    val utmTerm: String? = null,
    @Json(name = "utm_content")
    val utmContent: String? = null,
    @Json(name = "gclid")
    val gclid: String? = null,
    /** Raw install referrer URL as returned by the Play Store API. */
    @Json(name = "raw_referrer")
    val rawReferrer: String? = null,
    /** Timestamp (in seconds) when the user clicked on the Play Store install referrer link. */
    @Json(name = "referrer_click_ts")
    val referrerClickTimestampSec: Long? = null,
    /** Timestamp (in seconds) when the app install began according to Play Store. */
    @Json(name = "app_install_ts")
    val appInstallTimestampSec: Long? = null,
)

// InstallPayload has been deprecated – installs are now sent as a regular "INSTALL" event.

/**
 * Represents a single event sent to the backend.
 *
 * The [type] field is a **raw string** so that the SDK can emit
 * special types such as "INSTALL" that are **not** part of the
 * public [EventType] enum exposed to host applications.
 *
 * Extra fields that are only meaningful for install-type events
 * are kept optional so the same data class can be reused for any
 * user-generated event as well.
 */
data class TrackedEvent(
    @Json(name = "type")
    val type: String,
    @Json(name = "name")
    val name: String? = null,
    @Json(name = "ts")
    val ts: Long,
    @Json(name = "value")
    val value: Double? = null,

    // -------- install-specific (all nullable for regular events) --------
    @Json(name = "raw_referrer")
    val rawReferrer: String? = null,
    @Json(name = "referrer_click_ts")
    val referrerClickTimestampSec: Long? = null,
    @Json(name = "app_install_ts")
    val appInstallTimestampSec: Long? = null,
)

data class EventsBatchPayload(
    @Json(name = "app_id")
    val appId: String,
    @Json(name = "installation_id")
    val installationId: String,
    @Json(name = "sdk_version")
    val sdkVersion: String,

    // Flattened UTM parameters (all optional)
    @Json(name = "utm_source")
    val utmSource: String? = null,
    @Json(name = "utm_medium")
    val utmMedium: String? = null,
    @Json(name = "utm_campaign")
    val utmCampaign: String? = null,
    @Json(name = "utm_term")
    val utmTerm: String? = null,
    @Json(name = "utm_content")
    val utmContent: String? = null,
    @Json(name = "gclid")
    val gclid: String? = null,

    // Raw Play Store referrer info
    @Json(name = "raw_referrer")
    val rawReferrer: String? = null,
    @Json(name = "referrer_click_ts")
    val referrerClickTimestampSec: Long? = null,
    @Json(name = "app_install_ts")
    val appInstallTimestampSec: Long? = null,

    @Json(name = "events")
    val events: List<TrackedEvent>,
)

data class RemoteConfig(
    @Json(name = "app_id")
    val appId: String,
    @Json(name = "enabled")
    val enabled: Boolean = true,
)

// ------------------------------------------------------------------------------------
// Lightweight component container (would normally be Dagger/Hilt/Koin)
// ------------------------------------------------------------------------------------

internal class Components(
    val storage: StorageProvider,
    val network: NetworkClient,
    val referrerProvider: ReferrerProvider,
    val installationIdProvider: InstallationIdProvider,
    val remoteConfigDeferred: Deferred<RemoteConfig>,
    initialRemoteConfig: RemoteConfig,
) {
    @Volatile
    var remoteConfig: RemoteConfig = initialRemoteConfig
        private set

    @Volatile
    lateinit var eventTracker: EventTracker
        private set

    @Volatile
    lateinit var flushScheduler: FlushScheduler
        private set

    @Volatile
    var isDisabled: Boolean = false

    init {
        // Initialize with the initial config
        updateRemoteConfigInternal(initialRemoteConfig)
    }

    /** Replace placeholder configuration with the real one and recreate dependent components. */
    fun applyRemoteConfig(config: RemoteConfig) {
        updateRemoteConfigInternal(config)
    }

    /** 
     * Update remote config if it has changed and notify dependent components.
     * This is called by the periodic config refresh worker.
     */
    fun updateRemoteConfigIfChanged(newConfig: RemoteConfig) {
        if (newConfig != remoteConfig) {
            Logger.i("Components", "Remote config changed, updating components")
            DebugStateProvider.update("Remote Config Enabled", newConfig.enabled)
            DebugStateProvider.update("Remote Config App ID", newConfig.appId)
            updateRemoteConfigInternal(newConfig)
            
            // Config updates are applied internally; no external broadcast required.
        }
    }

    private fun updateRemoteConfigInternal(config: RemoteConfig) {
        remoteConfig = config
        
        if (!::eventTracker.isInitialized) {
            // Initial creation
            eventTracker = EventTracker(storage, network, config, config.appId, installationIdProvider, referrerProvider)
            flushScheduler = FlushScheduler(eventTracker, config)
        } else {
            // For updates, update existing instances to preserve state where possible
            eventTracker.updateConfig(config)
            flushScheduler = FlushScheduler(eventTracker, config)
        }
    }

    companion object {
        fun makeDefault(context: Context, config: Config, listener: InitListener?): Components {
            // Dynamically load default implementations from optional :storage and :network modules
            val storage: StorageProvider = run {
                try {
                    val cls = Class.forName("com.appstack.attribution.SharedPrefsStorage")
                    val ctor = cls.getConstructor(android.content.Context::class.java)
                    ctor.newInstance(context) as StorageProvider
                } catch (t: Throwable) {
                    // Fallback to an in-memory implementation so the SDK remains functional in unit tests
                    object : StorageProvider {
                        private val map = java.util.concurrent.ConcurrentHashMap<String, String>()
                        override fun putString(key: String, value: String) { map[key] = value }
                        override fun getString(key: String): String? = map[key]
                        override fun remove(key: String) { map.remove(key) }
                        override fun clear() { map.clear() }
                    }
                }
            }

            val network: NetworkClient = run {
                try {
                    // REFLECTION-BASED OPTIONAL DEPENDENCY LOADING
                    // 
                    // The :core module cannot directly depend on :network module to avoid circular
                    // dependencies and to keep the SDK modular. Instead, we use reflection to
                    // dynamically load RetrofitClient if the :network module is present.
                    //
                    // This pattern allows:
                    // 1. Core SDK functionality even if network module is missing
                    // 2. Clean separation of concerns between modules  
                    // 3. Optional network implementations (could be OkHttp, Volley, etc.)
                    //
                    // CRITICAL: RetrofitClient MUST provide an explicit 2-parameter constructor
                    // for this reflection to work. See RetrofitClient class documentation.
                    val cls = Class.forName("com.appstack.attribution.RetrofitClient")
                    // The Kotlin primary constructor has defaults, so we reflect the synthetic constructor with 2 params
                    // (String baseUrl, String apiKey) and rely on default for OkHttpClient.
                    val ctorCandidate = cls.constructors.firstOrNull { it.parameterTypes.size == 2 }
                        ?: cls.constructors.firstOrNull { it.parameterTypes.size >= 2 }
                        ?: throw IllegalStateException("RetrofitClient constructor not found")
                    val ctor = ctorCandidate
                    ctor.newInstance(config.endpointBaseUrl, config.apiKey) as NetworkClient
                } catch (t: Throwable) {
                    // Critical failure – notify listener, mark disabled, and return a throwing stub
                    listener?.onError(t)
                    Logger.e("Components", "Failed to load RetrofitClient – SDK disabled: ${'$'}t")

                    // Stub that throws to make misuse obvious
                    object : NetworkClient, DisabledNetworkClient {
                        override suspend fun postEvents(payload: EventsBatchPayload): Nothing = throw IllegalStateException("AppStackAttributionSdk disabled – network layer unavailable")
                        override suspend fun fetchRemoteConfig(): RemoteConfig = throw IllegalStateException("AppStackAttributionSdk disabled – network layer unavailable")
                    }
                }
            }

            val installationIdProvider = InstallationIdProviderImpl(storage)
            val referrerProvider = PlayStoreReferrerProvider(context, storage)

            // Fetch the remote configuration asynchronously to avoid blocking the main thread
            val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
            val remoteConfigDeferred: Deferred<RemoteConfig> = if (config.remoteConfigEnabled) {
                scope.async {
                    try {
                        network.fetchRemoteConfig()
                    } catch (e: AuthenticationException) {
                        // Authentication failed - invalid API key. This is a permanent error.
                        Logger.e("Components", "Authentication failed with API key - SDK will be disabled: $e")
                        listener?.onError(e)
                        throw e
                    } catch (t: Throwable) {
                        Logger.w("Components", "Failed to fetch remote config: $t – falling back to defaults")
                        RemoteConfig(appId = config.apiKey)
                    }
                }
            } else {
                // Remote config disabled, create a completed deferred with local config
                scope.async {
                    RemoteConfig(
                        appId = config.appId ?: config.apiKey,
                        enabled = config.sdkEnabled
                    )
                }
            }

            // Placeholder configuration used until the remote one is resolved
            val placeholderConfig = RemoteConfig(
                appId = config.appId ?: config.apiKey,
                enabled = config.sdkEnabled,
            )

            val comps = Components(
                storage = storage,
                network = network,
                referrerProvider = referrerProvider,
                installationIdProvider = installationIdProvider,
                remoteConfigDeferred = remoteConfigDeferred,
                initialRemoteConfig = placeholderConfig,
            )

            // Mark disabled if listener already received error (network is stub that throws)
            if (network is DisabledNetworkClient) {
                comps.isDisabled = true
            }

            return comps
        }
    }
}

// ------------------------------------------------------------------------------------
// Simplified internal tracker & scheduler placeholders (implementation in :queue)
// ------------------------------------------------------------------------------------

internal class EventTracker(
    private val storage: StorageProvider,
    private val network: NetworkClient,
    private var remoteConfig: RemoteConfig,
    private val appId: String,
    private val installationIdProvider: InstallationIdProvider,
    private val referrerProvider: ReferrerProvider,
) {
    @Volatile
    private var queue = EventQueue(storage, Constants.MAX_QUEUE_SIZE)
    @Volatile
    private var throttle = ThrottleManager(Constants.THROTTLE_EVENTS_PER_HOUR)
    @Volatile
    private var breaker = CircuitBreaker(Constants.CIRCUIT_BREAKER_THRESHOLD)

    /** Update internal configuration. Constants are build-time so limits do not change. */
    fun updateConfig(newConfig: RemoteConfig) {
        remoteConfig = newConfig
        // No-op for limits – they are backed by build-time constants.
    }

    fun trackEvent(type: EventType, name: String?, value: Double?) {
        if (!throttle.tryAcquire()) return // drop event when throttled

        val event = TrackedEvent(
            type = type.name, // stringify enum for wire format
            name = name,
            ts = System.currentTimeMillis() / 1000,
            value = value,
        )
        queue.add(event)
        DebugStateProvider.recordPendingEvent(event)
    }

    suspend fun flushUpTo(maxBatch: Int = Constants.MAX_EVENT_BATCH_SIZE) {
        // Ensure that only one flush at a time accesses the queue & network to avoid race conditions.
        flushLock.withLock {
            if (breaker.isOpen) return

            val batch = queue.popBatch(maxBatch)
            if (batch.isEmpty()) return

            val referrer = referrerProvider.getInstallReferrer()

            val payload = EventsBatchPayload(
                appId = appId,
                installationId = installationIdProvider.getInstallationId(),
                sdkVersion = SdkInfo.VERSION,
                utmSource = referrer?.utmSource,
                utmMedium = referrer?.utmMedium,
                utmCampaign = referrer?.utmCampaign,
                utmTerm = referrer?.utmTerm,
                utmContent = referrer?.utmContent,
                gclid = referrer?.gclid,
                rawReferrer = referrer?.rawReferrer,
                referrerClickTimestampSec = referrer?.referrerClickTimestampSec,
                appInstallTimestampSec = referrer?.appInstallTimestampSec,
                events = batch,
            )
            try {
                network.postEvents(payload)
                breaker.onSuccess()
                DebugStateProvider.markEventsFlushed(batch)
                DebugStateProvider.update("Last Flush", "Success (${DebugStateProvider.now()}), ${batch.size} events")
            } catch (e: AuthenticationException) {
                // Authentication failed - this is a permanent error, don't retry events
                Logger.e("EventTracker", "Authentication failed during event flush - dropping events: $e")
                breaker.onFailure()
                DebugStateProvider.update("Last Flush", "Auth Failure (${DebugStateProvider.now()})")
                // Don't put events back in queue - they would fail again
            } catch (t: Throwable) {
                // failure, push back events to be retried later
                batch.forEach { queue.add(it) }
                breaker.onFailure()
                DebugStateProvider.update("Last Flush", "Network Failure (${DebugStateProvider.now()})")
            }
        }
    }

    companion object {
        /** Mutex protecting flush operations to avoid race conditions when multiple flushes run concurrently. */
        private val flushLock = Mutex()
    }
}

internal class FlushScheduler(
    private val tracker: EventTracker,
    private val remoteConfig: RemoteConfig,
) {
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    fun flushNow() {
        scope.launch {
            tracker.flushUpTo()
        }
    }
}

// Marker interface to identify stub network
private interface DisabledNetworkClient