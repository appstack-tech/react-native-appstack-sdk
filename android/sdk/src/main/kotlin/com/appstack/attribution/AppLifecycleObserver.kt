package com.appstack.attribution

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/**
 * Process-wide lifecycle observer that flushes the event queue when the host app
 * moves to background (i.e. when the last visible Activity is stopped).
 *
 * This relies on AndroidX `ProcessLifecycleOwner` which is pulled in via the
 * `lifecycle-process` dependency declared in the Gradle build script.
 */
internal object AppLifecycleObserver : DefaultLifecycleObserver {

    override fun onStop(owner: LifecycleOwner) {
        // App entered background – trigger a best-effort flush of pending events.
        try {
            AppStackAttributionSdk.flush()
        } catch (_: Throwable) {
            // Never let an SDK exception crash the host application.
        }
    }
} 