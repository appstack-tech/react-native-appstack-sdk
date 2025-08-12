package com.appstack.attribution

import com.squareup.moshi.Moshi

/**
 * Centralised helper responsible for persisting and retrieving cached install-referrer
 * parameters.  
 * Implemented once so that `PlayStoreReferrerProvider`, background workers, or any
 * other component can read / write the attribution source without duplicating JSON
 * parsing logic.
 */
internal object ReferrerCache {

    private const val KEY_CACHE = Constants.KEY_CACHED_REFERRER

    private val adapter by lazy {
        Moshi.Builder().build().adapter(UTMParameters::class.java)
    }

    /** Load previously persisted referrer parameters (campaign or organic). */
    fun load(storage: StorageProvider): UTMParameters? {
        val json = storage.getString(KEY_CACHE) ?: return null
        return try {
            adapter.fromJson(json)
        } catch (_: Throwable) {
            null
        }
    }

    /** Persist referrer parameters for future use. */
    fun save(storage: StorageProvider, params: UTMParameters) {
        try {
            storage.putString(KEY_CACHE, adapter.toJson(params))
        } catch (_: Throwable) {
            // Swallow – not critical for app behaviour
        }
    }
} 