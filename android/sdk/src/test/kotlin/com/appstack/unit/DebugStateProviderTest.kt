package com.appstack.unit

import com.appstack.attribution.DebugStateProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class DebugStateProviderTest {

    @Before
    fun setUp() {
        // Reset state before each test
        DebugStateProvider.init(false)
    }

    @Test
    fun `update does nothing when disabled`() = runTest {
        DebugStateProvider.update("key", "value")
        val data = DebugStateProvider.formattedDebugString.first()
        assertTrue(data.isEmpty())
    }

    @Test
    fun `init enables updates`() = runTest {
        DebugStateProvider.init(true)
        DebugStateProvider.update("key", "value")
        val data = DebugStateProvider.formattedDebugString.first()
        assertEquals("key: value", data)
    }

    @Test
    fun `init false clears existing data`() = runTest {
        DebugStateProvider.init(true)
        DebugStateProvider.update("key", "value")
        assertEquals("key: value", DebugStateProvider.formattedDebugString.first())

        DebugStateProvider.init(false)
        assertTrue(DebugStateProvider.formattedDebugString.first().isEmpty())
    }

    @Test
    fun `update adds and modifies values`() = runTest {
        DebugStateProvider.init(true)
        DebugStateProvider.update("key1", "value1")
        DebugStateProvider.update("key2", 123)
        assertEquals("key1: value1\nkey2: 123", DebugStateProvider.formattedDebugString.first())

        DebugStateProvider.update("key1", "newValue")
        assertEquals("key1: newValue\nkey2: 123", DebugStateProvider.formattedDebugString.first())
    }

    @Test
    fun `update with null value removes key`() = runTest {
        DebugStateProvider.init(true)
        DebugStateProvider.update("key1", "value1")
        DebugStateProvider.update("key2", "value2")
        assertEquals("key1: value1\nkey2: value2", DebugStateProvider.formattedDebugString.first())

        DebugStateProvider.update("key1", null)
        assertEquals("key2: value2", DebugStateProvider.formattedDebugString.first())
    }

    @Test
    fun `formatted string is correctly generated and sorted`() = runTest {
        DebugStateProvider.init(true)
        DebugStateProvider.update("c", 3)
        DebugStateProvider.update("a", "1")
        DebugStateProvider.update("b", true)

        val expected = "a: 1\nb: true\nc: 3"
        assertEquals(expected, DebugStateProvider.formattedDebugString.first())
    }
} 