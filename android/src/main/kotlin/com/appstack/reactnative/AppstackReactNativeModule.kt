package com.appstack.reactnative

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
// Import the SDK from the Maven dependency
import com.appstack.attribution.AppstackAttributionSdk
import com.appstack.attribution.EventType
import com.appstack.attribution.InitListener

@ReactModule(name = AppstackReactNativeModule.NAME)
class AppstackReactNativeModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    companion object {
        const val NAME = "AppstackReactNative"
        private const val TAG = "AppstackReactNativeModule"
    }

    override fun getName(): String {
        return NAME
    }

    @ReactMethod
    fun configure(apiKey: String, isDebug: Boolean, endpointBaseUrl: String?, logLevel: Int, promise: Promise) {
        try {
            Log.d(TAG, "Configuring Appstack SDK with API key: ${apiKey.take(8)}...")
            
            if (apiKey.isBlank()) {
                promise.reject("INVALID_API_KEY", "API key cannot be null or empty")
                return
            }

            val context = reactApplicationContext
            if (context == null) {
                promise.reject("CONTEXT_ERROR", "React application context is null")
                return
            }

            // Convert Int logLevel to LogLevel enum
            val logLevelEnum = when (logLevel) {
                0 -> com.appstack.attribution.LogLevel.DEBUG
                1 -> com.appstack.attribution.LogLevel.INFO
                2 -> com.appstack.attribution.LogLevel.WARN
                3 -> com.appstack.attribution.LogLevel.ERROR
                else -> com.appstack.attribution.LogLevel.INFO
            }

            // Validate that SDK classes are available
            try {
                Log.d(TAG, "Checking SDK class availability...")
                val sdkClass = AppstackAttributionSdk::class.java
                Log.d(TAG, "All SDK classes are available")
            } catch (e: Exception) {
                Log.e(TAG, "SDK classes not available", e)
                promise.reject("SDK_CLASSES_ERROR", "SDK classes not available: ${e.message}", e)
                return
            }
            // Track if promise has been resolved/rejected
            var promiseHandled = false
            
            // Create InitListener with better error handling
            val initListener = object : InitListener {
                override fun onError(throwable: Throwable) {
                    Log.e(TAG, "SDK initialization failed", throwable)
                    // Log full stack trace for debugging
                    Log.e(TAG, "Full stack trace: ", throwable)
                    if (!promiseHandled) {
                        promiseHandled = true
                        val errorMessage = throwable.message ?: "Unknown initialization error"
                        val errorCause = throwable.cause?.message ?: "No cause available"
                        promise.reject("CONFIGURATION_ERROR", "SDK initialization failed: $errorMessage. Cause: $errorCause", throwable)
                    }
                }
            }
            
            // Check if SDK is already initialized
            try {
                val isAlreadyEnabled = AppstackAttributionSdk.isEnabled()
                Log.d(TAG, "SDK current status before init: isEnabled=$isAlreadyEnabled")
            } catch (e: Exception) {
                Log.d(TAG, "Could not check SDK status before init: ${e.message}")
            }
            
            Log.d(TAG, "Calling AppstackAttributionSdk.configure...")
            
            AppstackAttributionSdk.configure(
                context = context,
                apiKey = apiKey.trim(),
                isDebug = isDebug,
                endpointBaseUrl = endpointBaseUrl ?: "https://api.event.dev.appstack.tech/android/",
                logLevel = logLevelEnum,
                listener = initListener
            )
            
            Log.d(TAG, "SDK configure method called successfully")
            
            // Since InitListener only has onError callback, we need to wait a bit to see if initialization succeeds
            // If no error occurs within 3 seconds, we assume success
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            handler.postDelayed({
                if (!promiseHandled) {
                    promiseHandled = true
                    Log.d(TAG, "SDK initialization completed successfully (no error received)")
                    promise.resolve(true)
                }
            }, 3000) // 3 second timeout
        } catch (exception: Exception) {
            Log.e(TAG, "Exception during SDK configuration", exception)
            promise.reject("CONFIGURATION_ERROR", "Failed to configure SDK: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun sendEvent(eventName: String?, eventType: String?, revenue: Double?, promise: Promise) {
        try {
            // At least one of eventName or eventType should be provided
            if ((eventName.isNullOrBlank()) && (eventType.isNullOrBlank())) {
                promise.reject("INVALID_EVENT_NAME", "Either eventName or eventType must be provided")
                return
            }

            // Determine the EventType enum to use
            val finalEventType: EventType
            val finalEventName: String?
            
            if (!eventType.isNullOrBlank()) {
                // Use provided event_type parameter
                finalEventType = try {
                    EventType.valueOf(eventType.trim().uppercase())
                } catch (e: IllegalArgumentException) {
                    EventType.CUSTOM
                }
                finalEventName = if (finalEventType == EventType.CUSTOM) eventName?.trim() else null
            } else if (!eventName.isNullOrBlank()) {
                // Fallback to legacy behavior - try to parse eventName as EventType
                finalEventType = try {
                    EventType.valueOf(eventName.trim().uppercase())
                } catch (e: IllegalArgumentException) {
                    EventType.CUSTOM
                }
                finalEventName = if (finalEventType == EventType.CUSTOM) eventName.trim() else null
            } else {
                // This shouldn't happen due to validation above, but just in case
                finalEventType = EventType.CUSTOM
                finalEventName = "UNKNOWN_EVENT"
            }

            AppstackAttributionSdk.sendEvent(
                event = finalEventType,
                name = finalEventName,
                revenue = revenue
            )
            
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("EVENT_SEND_ERROR", "Failed to send event (eventName: '$eventName', eventType: '$eventType'): ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun enableAppleAdsAttribution(promise: Promise) {
        // Apple Ads Attribution is iOS-only, so we return false on Android
        promise.resolve(false)
    }

    @ReactMethod
    fun flush(promise: Promise) {
        try {
            AppstackAttributionSdk.flush()
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("FLUSH_ERROR", "Failed to flush events: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun clearData(promise: Promise) {
        try {
            AppstackAttributionSdk.clearData()
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("CLEAR_DATA_ERROR", "Failed to clear data: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun isEnabled(promise: Promise) {
        try {
            val enabled = AppstackAttributionSdk.isEnabled()
            promise.resolve(enabled)
        } catch (exception: Exception) {
            promise.reject("STATUS_ERROR", "Failed to get SDK status: ${exception.message}", exception)
        }
    }
}
