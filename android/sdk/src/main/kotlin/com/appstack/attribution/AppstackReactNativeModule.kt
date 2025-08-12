package com.appstack.attribution

import android.content.Context
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = AppstackReactNativeModule.NAME)
class AppstackReactNativeModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    companion object {
        const val NAME = "AppstackReactNative"
    }

    override fun getName(): String {
        return NAME
    }

    @ReactMethod
    fun configure(apiKey: String, promise: Promise) {
        try {
            if (apiKey.isBlank()) {
                promise.reject("INVALID_API_KEY", "API key cannot be null or empty")
                return
            }

            val context = reactApplicationContext
            
            // Configure the SDK with default settings
            AppStackAttributionSdk.configure(
                context = context,
                apiKey = apiKey.trim(),
                isDebug = false, // Can be made configurable later
                listener = { error ->
                    // Handle initialization errors
                    promise.reject("CONFIGURATION_ERROR", "SDK initialization failed: ${error.message}", error)
                }
            )
            
            promise.resolve(true)
        } catch (exception: Exception) {
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
                event = eventType,
                name = if (eventType == EventType.CUSTOM) eventName.trim() else null
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
                event = eventType,
                name = if (eventType == EventType.CUSTOM) eventName.trim() else null,
                revenue = revenueValue
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
