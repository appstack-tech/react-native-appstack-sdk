package com.appstack.attribution

/**
 * Simple circuit breaker tracking consecutive failures and pausing network calls.
 */
class CircuitBreaker(
    private val maxFailures: Int,
    private val coolDownMillis: Long = Constants.CIRCUIT_BREAKER_COOLDOWN_MS,
    private val now: () -> Long = { System.currentTimeMillis() },
) {
    private var failureCount: Int = 0
    private var openUntil: Long = 0L

    fun onSuccess() {
        failureCount = 0
        openUntil = 0
        DebugStateProvider.update("Circuit Breaker", "CLOSED")
    }

    fun onFailure() {
        failureCount++
        if (failureCount >= maxFailures) {
            openUntil = now() + coolDownMillis
            DebugStateProvider.update("Circuit Breaker", "OPEN until ${DebugStateProvider.now()}")
        }
    }

    val isOpen: Boolean
        get() = openUntil > now()
} 