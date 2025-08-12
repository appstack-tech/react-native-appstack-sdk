package com.appstack.sample

import com.appstack.attribution.RetrofitClient
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.runBlocking
import org.junit.Test

class NetworkFetchTest {
    @Test
    fun `retrofit client can fetch remote config`() = runBlocking {
        val backend = TestBackend().apply {
            start()
            enqueueRemoteConfig()
        }
        val client = RetrofitClient(backend.baseUrl, "api-key")
        val rc = client.fetchRemoteConfig()
        assertThat(rc.appId).isEqualTo("com.appstack.sample")
        backend.close()
    }
} 