package com.appstack.attribution

import com.google.common.truth.Truth.assertThat
import com.appstack.testutil.InMemoryStorage
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class EventQueueTest {
    private lateinit var storage: InMemoryStorage
    private lateinit var queue: EventQueue

    @Before
    fun setUp() {
        storage = InMemoryStorage()
        queue = EventQueue(storage, maxQueueSize = 1000)
    }

    @Test
    fun `queue enforces max size`() {
        repeat(1100) {
            queue.add(TrackedEvent(EventType.CUSTOM.name, "e$it", 0L, null))
        }
        assertThat(queue.size()).isEqualTo(1000)
    }

    @Test
    fun `popBatch returns and removes events`() {
        repeat(10) {
            queue.add(TrackedEvent(EventType.CUSTOM.name, "e$it", 0L, null))
        }
        val batch = queue.popBatch(5)
        assertThat(batch).hasSize(5)
        assertThat(queue.size()).isEqualTo(5)
    }
}