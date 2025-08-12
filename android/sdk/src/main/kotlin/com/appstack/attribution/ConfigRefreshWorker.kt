package com.appstack.attribution

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class ConfigRefreshWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            AppStackAttributionSdk.refreshConfig()
            Result.success()
        } catch (e: AuthenticationException) {
            Logger.e("ConfigRefreshWorker", "Authentication failed, disabling worker: $e")
            Result.failure()
        } catch (t: Throwable) {
            Logger.w("ConfigRefreshWorker", "Failed to refresh config, will retry: $t")
            Result.retry()
        }
    }

    companion object {
        private const val UNIQUE_NAME = "AppStackConfigRefreshWorker"

        fun schedule(context: Context, refreshIntervalMs: Long = Constants.CONFIG_REFRESH_INTERVAL_MS) {
            // WorkManager enforces a 15-minute minimum for periodic work
            val safeIntervalMs = if (refreshIntervalMs < Constants.MIN_WORKER_INTERVAL_MS) {
                Constants.MIN_WORKER_INTERVAL_MS
            } else refreshIntervalMs

            val request = PeriodicWorkRequestBuilder<ConfigRefreshWorker>(
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