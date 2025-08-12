package com.appstack.attribution

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentSkipListMap
import java.util.concurrent.ConcurrentHashMap

/**
 * Singleton state holder for debug information.
 * All SDK components report their state to this provider, which then exposes
 * it as a Flow for the debug UI to consume.
 *
 * This object is thread-safe.
 */
object DebugStateProvider {

    @Volatile
    private var isEnabled = false
    private val _debugData = MutableStateFlow(ConcurrentSkipListMap<String, Any>())
    /** Map tracking currently known events and their status ("Pending" or "Sent"). */
    private val eventStatuses = ConcurrentHashMap<TrackedEvent, String>()

    /** A flow emitting a formatted, multi-line string of all current debug data. */
    val formattedDebugString: Flow<String> = _debugData.asStateFlow().map { data ->
        data.entries.joinToString(separator = "\n") { (key, value) ->
            "$key: $value"
        }
    }

    /** A flow emitting individual event log lines so that the overlay can render them separately. */
    val eventLines: Flow<List<String>> = _debugData.asStateFlow().map { data ->
        val raw = data["Events"] as? String ?: return@map emptyList()
        raw.lines().filter { it.isNotBlank() }
    }

    /**
     * Initializes the state provider. Must be called from `AppStackAttributionSdk.init`.
     * @param enabled Whether debug mode is active. If `false`, all calls to `update` are no-ops.
     */
    fun init(enabled: Boolean) {
        isEnabled = enabled
        if (!enabled) {
            _debugData.value.clear()
        }
    }

    /**
     * Update a key-value pair in the debug data map.
     * If debug mode is disabled, this method does nothing.
     * If the value is `null`, the key is removed.
     *
     * @param key The key for the debug entry (e.g., "SDK Version").
     * @param value The value to display (e.g., "1.0.0").
     */
    fun update(key: String, value: Any?) {
        if (!isEnabled) return

        if (value == null) {
            remove(key)
            return
        }

        // Using copy-on-write to ensure immutability and flow emission
        val newMap = ConcurrentSkipListMap(_debugData.value)
        newMap[key] = value
        _debugData.value = newMap
    }

    /** Removes a key from the debug data map. */
    private fun remove(key: String) {
        if (!isEnabled) return
        val newMap = ConcurrentSkipListMap(_debugData.value)
        newMap.remove(key)
        _debugData.value = newMap
    }

    /** Returns a timestamp string formatted as HH:mm:ss. */
    fun now(): String {
        return SimpleDateFormat("HH:mm:ss", Locale.US).format(Date())
    }

    /** Record a newly tracked event as pending so it appears in the debug overlay. */
    fun recordPendingEvent(event: TrackedEvent) {
        if (!isEnabled) return
        eventStatuses[event] = "Pending"
        updateEventsEntry()
    }

    /** Mark the supplied events as successfully flushed. */
    fun markEventsFlushed(events: List<TrackedEvent>) {
        if (!isEnabled) return
        events.forEach { eventStatuses[it] = "Sent" }
        updateEventsEntry()
    }

    /** Re-generate the aggregated "Events" entry from the current eventStatuses map. */
    private fun updateEventsEntry() {
        val formatter = SimpleDateFormat("HH:mm:ss", Locale.US)
        val eventLines = eventStatuses.entries
            .sortedBy { it.key.ts }
            .joinToString("\n") { (event, status) ->
                val time = formatter.format(Date(event.ts * 1000))
                val name = event.name?.let { " [${it}]" } ?: ""
                "$time – ${event.type}$name : $status"
            }

        val newMap = ConcurrentSkipListMap(_debugData.value)
        newMap["Events"] = eventLines
        _debugData.value = newMap
    }
}