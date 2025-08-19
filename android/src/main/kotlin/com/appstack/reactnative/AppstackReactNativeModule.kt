package com.appstack.reactnative

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
// Import the SDK from the Maven dependency
import com.appstack.attribution.AppStackAttributionSdk
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
    fun configure(apiKey: String, promise: Promise) {
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

            // Validate that SDK classes are available
            try {
                Log.d(TAG, "Checking SDK class availability...")
                val sdkClass = AppStackAttributionSdk::class.java
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
                val isAlreadyEnabled = AppStackAttributionSdk.isEnabled()
                Log.d(TAG, "SDK current status before init: isEnabled=$isAlreadyEnabled")
            } catch (e: Exception) {
                Log.d(TAG, "Could not check SDK status before init: ${e.message}")
            }
            
            Log.d(TAG, "Calling AppStackAttributionSdk.configure...")
            
            AppStackAttributionSdk.configure(
                context,
                apiKey.trim(),
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
    fun sendEvent(eventName: String, promise: Promise) {
        try {
            if (eventName.isBlank()) {
                promise.reject("INVALID_EVENT_NAME", "Event name cannot be null or empty")
                return
            }

            // Try to find a matching EventType enum, fallback to CUSTOM
            val eventType = try {
                EventType.valueOf(eventName.trim().uppercase())
            } catch (e: IllegalArgumentException) {
                EventType.CUSTOM
            }

            AppStackAttributionSdk.sendEvent(
                eventType,
                if (eventType == EventType.CUSTOM) eventName.trim() else null,
                null
            )
            
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("EVENT_SEND_ERROR", "Failed to send event '$eventName': ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun sendEventWithRevenue(eventName: String, revenue: Dynamic, promise: Promise) {
        try {
            if (eventName.isBlank()) {
                promise.reject("INVALID_EVENT_NAME", "Event name cannot be null or empty")
                return
            }

            if (revenue.isNull) {
                promise.reject("INVALID_REVENUE", "Revenue cannot be null")
                return
            }

            // Convert revenue to Double
            val revenueValue = when (revenue.type) {
                ReadableType.Number -> revenue.asDouble()
                ReadableType.String -> {
                    try {
                        revenue.asString().toDouble()
                    } catch (e: NumberFormatException) {
                        promise.reject("INVALID_REVENUE", "Revenue must be a valid number or numeric string")
                        return
                    }
                }
                else -> {
                    promise.reject("INVALID_REVENUE", "Revenue must be a number or numeric string")
                    return
                }
            }

            // Try to find a matching EventType enum, fallback to CUSTOM
            val eventType = try {
                EventType.valueOf(eventName.trim().uppercase())
            } catch (e: IllegalArgumentException) {
                EventType.CUSTOM
            }

            AppStackAttributionSdk.sendEvent(
                eventType,
                if (eventType == EventType.CUSTOM) eventName.trim() else null,
                revenueValue
            )
            
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("EVENT_SEND_ERROR", "Failed to send event '$eventName' with revenue '$revenue': ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun enableASAAttribution(promise: Promise) {
        // ASA Attribution is iOS-only, so we return false on Android
        promise.resolve(false)
    }

    @ReactMethod
    fun flush(promise: Promise) {
        try {
            AppStackAttributionSdk.flush()
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("FLUSH_ERROR", "Failed to flush events: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun clearData(promise: Promise) {
        try {
            AppStackAttributionSdk.clearData()
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("CLEAR_DATA_ERROR", "Failed to clear data: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun isEnabled(promise: Promise) {
        try {
            val enabled = AppStackAttributionSdk.isEnabled()
            promise.resolve(enabled)
        } catch (exception: Exception) {
            promise.reject("STATUS_ERROR", "Failed to get SDK status: ${exception.message}", exception)
        }
    }
}
