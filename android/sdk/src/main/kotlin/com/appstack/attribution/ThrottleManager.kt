package com.appstack.attribution

import java.util.ArrayDeque
import java.util.concurrent.TimeUnit

class ThrottleManager(
    private val maxEventsPerHour: Int,
    private val now: () -> Long = { System.currentTimeMillis() },
) {
    private val deque = ArrayDeque<Long>()
    private val windowMillis = TimeUnit.HOURS.toMillis(1)

    fun tryAcquire(): Boolean {
        val current = now()
        while (deque.isNotEmpty() && current - deque.peekFirst()!! > windowMillis) {
            deque.removeFirst()
        }
        return if (deque.size < maxEventsPerHour) {
            deque.addLast(current)
            true
        } else false
    }
} 