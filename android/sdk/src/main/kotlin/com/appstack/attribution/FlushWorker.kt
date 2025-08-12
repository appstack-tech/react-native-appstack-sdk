package com.appstack.attribution

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class FlushWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            AppStackAttributionSdk.flush()
            Result.success()
        } catch (t: Throwable) {
            Result.retry()
        }
    }

    companion object {
        private const val UNIQUE_NAME = "AppStackFlushWorker"

        fun schedule(context: Context, intervalMs: Long) {
            // WorkManager enforces a 15-minute minimum for periodic work. If a shorter
            // interval is requested we bump it to the minimum to avoid the silent
            // override that WorkManager would perform and make the behaviour explicit.
            val safeIntervalMs = if (intervalMs < Constants.MIN_WORKER_INTERVAL_MS) {
                Constants.MIN_WORKER_INTERVAL_MS
            } else intervalMs

            val request = PeriodicWorkRequestBuilder<FlushWorker>(
                safeIntervalMs, TimeUnit.MILLISECONDS,
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
        }
    }
}