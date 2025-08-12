package com.appstack.attribution

import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test

private class FakeStorage : StorageProvider {
    private val map = mutableMapOf<String, String>()
    override fun putString(key: String, value: String) { map[key] = value }
    override fun getString(key: String): String? = map[key]
    override fun remove(key: String) { map.remove(key) }
    override fun clear() { map.clear() }
}

class InstallationIdProviderTest {

    private lateinit var storage: FakeStorage
    private lateinit var provider: InstallationIdProviderImpl

    @Before
    fun setUp() {
        storage = FakeStorage()
        provider = InstallationIdProviderImpl(storage)
    }

    @Test
    fun `same id returned on repeated calls`() {
        val first = provider.getInstallationId()
        repeat(5) {
            assertThat(provider.getInstallationId()).isEqualTo(first)
        }
    }

    @Test
    fun `returns stored uuid if present`() {
        val raw = "00000000-0000-0000-0000-000000000001"
        storage.putString("appstack_install_id", raw)
        assertThat(provider.getInstallationId()).isEqualTo(raw)
    }
}