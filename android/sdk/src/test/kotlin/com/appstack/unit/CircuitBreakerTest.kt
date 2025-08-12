package com.appstack.attribution

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class CircuitBreakerTest {
    @Test
    fun `opens after threshold then closes after cooldown`() {
        var now = 0L
        val clock = { now }
        val breaker = CircuitBreaker(maxFailures = 2, coolDownMillis = 1000, now = clock)
        assertThat(breaker.isOpen).isFalse()
        breaker.onFailure()
        assertThat(breaker.isOpen).isFalse()
        breaker.onFailure()
        assertThat(breaker.isOpen).isTrue()
        // Advance time less than cooldown
        now += 500
        assertThat(breaker.isOpen).isTrue()
        // Advance past cooldown
        now += 600
        assertThat(breaker.isOpen).isFalse()
    }
}