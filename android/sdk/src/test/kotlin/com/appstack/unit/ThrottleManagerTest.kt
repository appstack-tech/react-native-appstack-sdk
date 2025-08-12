package com.appstack.attribution

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class ThrottleManagerTest {

    @Test
    fun `allows up to max events within window`() {
        var now = 0L
        val clock = { now }
        val throttle = ThrottleManager(3, clock)
        repeat(3) {
            assertThat(throttle.tryAcquire()).isTrue()
        }
        // 4th should be rejected
        assertThat(throttle.tryAcquire()).isFalse()
        // Advance 1 hour + 1 ms
        now += 3_600_001
        assertThat(throttle.tryAcquire()).isTrue()
    }
}