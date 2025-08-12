package com.appstack.attribution

import com.google.common.truth.Truth.assertThat
import com.squareup.moshi.Moshi
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config as RobolectricConfig

@RunWith(RobolectricTestRunner::class)
@RobolectricConfig(
    sdk = [34],
    manifest = RobolectricConfig.NONE
)
class SimpleConfigTest {

    @Test
    fun `test direct moshi parsing of config json`() {
        val json = """
        {
          "app_id": "com.appstack.sample",
          "enabled": true,
          "flush_interval_ms": 1800000,
          "max_queue_size": 1000,
          "throttle_events_per_hour": 300,
          "retry_max_attempts": 5,
          "circuit_breaker_threshold": 5,
          "log_level": "INFO"
        }
        """.trimIndent()

        val moshi = Moshi.Builder()
            .addLast(com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory())
            .build()

        val adapter = moshi.adapter(RemoteConfig::class.java)
        
        try {
            val config = adapter.fromJson(json)
            println("✅ Successfully parsed config: $config")
            assertThat(config).isNotNull()
            assertThat(config!!.appId).isEqualTo("com.appstack.sample")
        } catch (e: Exception) {
            println("❌ Failed to parse config: ${e.message}")
            throw e
        }
    }
} 