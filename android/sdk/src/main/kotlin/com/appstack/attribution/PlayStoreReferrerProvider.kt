package com.appstack.attribution

import android.content.Context
import android.net.Uri
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume

/**
 * Fetches the Play Store install referrer and parses UTM parameters.
 */
open class PlayStoreReferrerProvider(
    private val context: Context,
    /** Storage used for persisting the cached referrer. */
    private val storage: StorageProvider,
    private val timeoutMs: Long = Constants.REFERRER_FETCH_TIMEOUT_MS,
) : ReferrerProvider {

    @Volatile
    private var cachedParams: UTMParameters? = null

    private val cacheLock = kotlinx.coroutines.sync.Mutex()

    private fun loadFromCache(): UTMParameters? {
        if (cachedParams != null) return cachedParams
        return ReferrerCache.load(storage)?.also { cachedParams = it }
    }

    override suspend fun getInstallReferrer(): UTMParameters? {
        // Fast path – return cached value if already available
        loadFromCache()?.let { return it }

        // Ensure only one coroutine fetches the referrer concurrently
        return cacheLock.withLock {
            // Re-check after acquiring lock to avoid duplicate fetches
            loadFromCache()?.let { return@withLock it }

            val fetched = fetchFromPlay()

            // If we did not retrieve any UTM params from Play Store we still want to remember
            // that the acquisition source is "organic" so that all subsequent payloads send
            // a stable value instead of alternating between <null> and a concrete object.
            val result = fetched ?: UTMParameters(utmMedium = Constants.ORGANIC_UTM_MEDIUM)

            // Persist the resolved parameters (either real campaign or organic) exactly once
            ReferrerCache.save(storage, result)

            cachedParams = result
            result
        }
    }

    /** Fetch referrer data from the Play Store service. */
    private suspend fun fetchFromPlay(): UTMParameters? {
        return withTimeoutOrNull(timeoutMs) {
            suspendCancellableCoroutine { continuation ->
                val client = InstallReferrerClient.newBuilder(context).build()
                Logger.d(TAG, "Connecting to Play Store for install referrer…")
                client.startConnection(object : InstallReferrerStateListener {
                    override fun onInstallReferrerSetupFinished(responseCode: Int) {
                        try {
                            if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                                val details: ReferrerDetails = client.installReferrer
                                // The Play Store may return the referrer string URL-encoded (e.g.
                                // "utm_source%3Dgoogle-play%26utm_medium%3Dorganic"). If we
                                // directly feed that into Uri.parse, the whole encoded string is
                                // treated as *one* query parameter and the individual UTM params
                                // become inaccessible. Decode first so that the URI parser sees the
                                // actual key/value pairs.
                                val decodedReferrer = Uri.decode(details.installReferrer)
                                val uri = Uri.parse("scheme://?$decodedReferrer")
                                val params = UTMParameters(
                                    utmSource = uri.getQueryParameter("utm_source"),
                                    utmMedium = uri.getQueryParameter("utm_medium"),
                                    utmCampaign = uri.getQueryParameter("utm_campaign"),
                                    utmTerm = uri.getQueryParameter("utm_term"),
                                    utmContent = uri.getQueryParameter("utm_content"),
                                    gclid = uri.getQueryParameter("gclid"),
                                    rawReferrer = details.installReferrer,
                                    referrerClickTimestampSec = details.referrerClickTimestampSeconds,
                                    appInstallTimestampSec = details.installBeginTimestampSeconds,
                                )
                                Logger.d(TAG, "Install referrer retrieved: ${'$'}params")
                                continuation.resume(params)
                            } else {
                                Logger.w(TAG, "Install referrer not available. Code=${'$'}responseCode")
                                continuation.resume(null)
                            }
                        } finally {
                            client.endConnection()
                        }
                    }

                    override fun onInstallReferrerServiceDisconnected() {
                        Logger.w(TAG, "Install referrer service disconnected before response")
                        continuation.resume(null)
                    }
                })
            }
        }
    }

    companion object {
        private const val TAG = "PlayStoreReferrerProvider"
    }
} 