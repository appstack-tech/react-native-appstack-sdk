package com.appstack.attribution

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Basic concurrency sanity-check: 100 concurrent writes then reads should be consistent.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SharedPrefsStorageTest {

    private lateinit var storage: SharedPrefsStorage

    @Before
    fun setUp() {
        val context: Context = ApplicationProvider.getApplicationContext()
        storage = SharedPrefsStorage(context)
        storage.clear()
    }

    @Test
    fun `concurrent writes do not corrupt data`() = runBlocking {
        val key = "k1"
        // Launch 100 concurrent writes
        val jobs = (1..100).map { i ->
            async(Dispatchers.Default) { storage.putString(key, i.toString()) }
        }
        jobs.forEach { it.await() }

        val finalValue = storage.getString(key)!!.toInt()
        // Result must be one of 1..100, never null or corrupted string
        assertThat(finalValue).isIn(1..100)
    }
}