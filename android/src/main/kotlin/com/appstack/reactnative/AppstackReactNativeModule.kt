package com.appstack.reactnative

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
// Import the SDK from the Maven dependency
import com.appstack.attribution.AppstackAttributionSdk
import com.appstack.attribution.EventType

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
            
            // Check if SDK is already initialized
            try {
                val isAlreadyEnabled = AppstackAttributionSdk.isEnabled()
                Log.d(TAG, "SDK current status before init: isEnabled=$isAlreadyEnabled")
            } catch (e: Exception) {
                Log.d(TAG, "Could not check SDK status before init: ${e.message}")
            }
            
            Log.d(TAG, "Calling AppstackAttributionSdk.configure...")
            
            // Configure the SDK (new version doesn't require InitListener)
            if (endpointBaseUrl != null) {
                AppstackAttributionSdk.configure(
                    context = context,
                    apiKey = apiKey.trim(),
                    isDebug = isDebug,
                    endpointBaseUrl = endpointBaseUrl,
                    logLevel = logLevelEnum
                )
            } else {
                AppstackAttributionSdk.configure(
                    context = context,
                    apiKey = apiKey.trim(),
                    isDebug = isDebug,
                    logLevel = logLevelEnum
                )
            }
            
            Log.d(TAG, "SDK configure method called successfully")
            promise.resolve(true)
        } catch (exception: Exception) {
            Log.e(TAG, "Exception during SDK configuration", exception)
            promise.reject("CONFIGURATION_ERROR", "Failed to configure SDK: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun sendEvent(eventType: String?, eventName: String?, parameters: ReadableMap?, promise: Promise) {
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
                
                // For CUSTOM event type, eventName is required
                // For non-CUSTOM event types, name should be null (SDK will use the event type)
                finalEventName = if (finalEventType == EventType.CUSTOM) {
                    if (eventName.isNullOrBlank()) {
                        promise.reject("INVALID_EVENT_NAME", "eventName is required when eventType is CUSTOM")
                        return
                    }
                    eventName.trim()
                } else {
                    null
                }
            } else if (!eventName.isNullOrBlank()) {
                // Fallback to legacy behavior - try to parse eventName as EventType
                finalEventType = try {
                    EventType.valueOf(eventName.trim().uppercase())
                } catch (e: IllegalArgumentException) {
                    EventType.CUSTOM
                }
                // For CUSTOM, use the name; for others, use null
                finalEventName = if (finalEventType == EventType.CUSTOM) eventName.trim() else null
            } else {
                // This shouldn't happen due to validation above, but just in case
                finalEventType = EventType.CUSTOM
                finalEventName = "UNKNOWN_EVENT"
            }

            // Convert ReadableMap to Map<String, Any>
            // toHashMap() returns HashMap<String, Any?>, but the SDK expects Map<String, Any>?
            // Filter out null values and cast to satisfy the non-null value type.
            val parametersMap: Map<String, Any>? = parameters
                ?.toHashMap()
                ?.filterValues { it != null }
                ?.mapValues { entry -> entry.value as Any }

            AppstackAttributionSdk.sendEvent(
                event = finalEventType,
                name = finalEventName,
                parameters = parametersMap
            )
            
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("EVENT_SEND_ERROR", "Failed to send event (eventType: '$eventType', eventName: '$eventName'): ${exception.message}", exception)
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

    @ReactMethod
    fun getAppstackId(promise: Promise) {
        try {
            val appstackId = AppstackAttributionSdk.getAppstackId()
            promise.resolve(appstackId)
        } catch (exception: Exception) {
            promise.reject("GET_APPSTACK_ID_ERROR", "Failed to get Appstack ID: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun isSdkDisabled(promise: Promise) {
        try {
            val disabled = AppstackAttributionSdk.isSdkDisabled()
            promise.resolve(disabled)
        } catch (exception: Exception) {
            promise.reject("STATUS_ERROR", "Failed to check if SDK is disabled: ${exception.message}", exception)
        }
    }

    @ReactMethod
    fun getAttributionParams(promise: Promise) {
        try {
            val params = AppstackAttributionSdk.getAttributionParams()
            val writableMap = WritableNativeMap()
            
            // Convert Map<String, Any> to WritableMap
            params?.forEach { (key, value) ->
                when (value) {
                    is String -> writableMap.putString(key, value)
                    is Int -> writableMap.putInt(key, value)
                    is Double -> writableMap.putDouble(key, value)
                    is Boolean -> writableMap.putBoolean(key, value)
                    is Long -> writableMap.putDouble(key, value.toDouble())
                    null -> writableMap.putNull(key)
                    else -> writableMap.putString(key, value.toString())
                }
            }
            
            promise.resolve(writableMap)
        } catch (exception: Exception) {
            promise.reject("ATTRIBUTION_PARAMS_ERROR", "Failed to get attribution parameters: ${exception.message}", exception)
        }
    }
}
