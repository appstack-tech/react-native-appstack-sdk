package com.appstack.testutil

import com.appstack.attribution.StorageProvider

/**
 * Simple thread-unsafe [StorageProvider] backed by a mutable [HashMap].  Intended
 * **only** for unit tests where concurrency guarantees are not required.
 */
class InMemoryStorage : StorageProvider {
    private val data = mutableMapOf<String, String>()

    override fun putString(key: String, value: String) {
        data[key] = value
    }

    override fun getString(key: String): String? = data[key]

    override fun remove(key: String) {
        data.remove(key)
    }

    override fun clear() {
        data.clear()
    }
} 