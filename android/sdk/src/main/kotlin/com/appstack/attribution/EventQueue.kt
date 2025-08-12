package com.appstack.attribution

import com.squareup.moshi.JsonAdapter
import com.squareup.moshi.Types
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Persistent FIFO queue backed by [StorageProvider].
 */
class EventQueue(
    private val storage: StorageProvider,
    private val maxQueueSize: Int,
) {
    private val lock = ReentrantLock()
    private val adapter: JsonAdapter<List<TrackedEvent>> by lazy {
        val type = Types.newParameterizedType(List::class.java, TrackedEvent::class.java)
        com.squareup.moshi.Moshi.Builder()
            .addLast(com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory())
            .build()
            .adapter(type)
    }

    fun add(event: TrackedEvent) {
        lock.withLock {
            val list = loadMutable()
            if (list.size >= maxQueueSize) list.removeFirst()
            list.add(event)
            persist(list)
            DebugStateProvider.update("Event Queue Size", list.size)
        }
    }

    fun popBatch(maxBatch: Int): List<TrackedEvent> = lock.withLock {
        val list = loadMutable()
        if (list.isEmpty()) return emptyList()
        val batch = list.take(maxBatch)
        val remaining = list.drop(maxBatch)
        persist(remaining)
        DebugStateProvider.update("Event Queue Size", remaining.size)
        batch
    }

    fun size(): Int = lock.withLock { loadMutable().size }

    private fun loadMutable(): MutableList<TrackedEvent> {
        val raw = storage.getString(Constants.KEY_QUEUE_JSON) ?: return mutableListOf()
        if (raw.isBlank()) return mutableListOf()
        return try {
            adapter.fromJson(raw)?.toMutableList() ?: mutableListOf()
        } catch (t: Exception) {
            Logger.e("EventQueue", "Corrupt JSON in event queue – clearing queue", t)
            storage.remove(Constants.KEY_QUEUE_JSON)
            mutableListOf()
        }
    }

    private fun persist(list: List<TrackedEvent>) {
        storage.putString(Constants.KEY_QUEUE_JSON, adapter.toJson(list))
    }
} 