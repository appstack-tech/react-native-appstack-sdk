package com.appstack.attribution

import android.content.Context
import androidx.annotation.VisibleForTesting
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Thread-safe [StorageProvider] implementation backed by Android's
 * [android.content.SharedPreferences].
 */
class SharedPrefsStorage(
    context: Context,
    prefsName: String = Constants.DEFAULT_PREFS_NAME,
) : StorageProvider {

    private val prefs = context.applicationContext.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
    private val lock = ReentrantLock()

    override fun putString(key: String, value: String) {
        lock.withLock { prefs.edit().putString(key, value).apply() }
    }

    override fun getString(key: String): String? = lock.withLock { prefs.getString(key, null) }

    override fun remove(key: String) {
        lock.withLock { prefs.edit().remove(key).apply() }
    }

    override fun clear() {
        lock.withLock { prefs.edit().clear().apply() }
    }

    companion object {
    }
}