package com.appstack.reactnative

import android.content.pm.PackageManager
import com.facebook.react.bridge.*
// Import the SDK from the Maven dependency
import com.appstack.attribution.AppstackAttributionSdk
import com.appstack.attribution.EventType

/**
 * All Appstack bridge logic, shared by both architectures.
 *
 * The React Native base class differs per architecture (see src/oldarch and
 * src/newarch): on the legacy architecture the module extends
 * ReactContextBaseJavaModule and declares @ReactMethod, while on the new
 * architecture it extends the codegen-generated NativeAppstackReactNativeSpec and
 * overrides its abstract methods. Both are thin adapters that delegate here, so
 * this file stays the single source of truth for behaviour.
 *
 * Method signatures mirror the codegen spec, which is why logLevel is a Double:
 * a required `number` parameter is generated as a primitive `double`.
 */
class AppstackReactNativeModuleImpl(
    private val reactApplicationContext: ReactApplicationContext
) {

    companion object {
        const val NAME = "AppstackReactNative"
        private const val WRAPPER_VERSION = "react-native-1.0.0"
    }

    // setProxyUrl + configureWrapper are gated behind @RequiresOptIn(InternalAppstackApi).
    @OptIn(com.appstack.attribution.InternalAppstackApi::class)
    fun configure(apiKey: String, logLevel: Double, customerUserId: String?, promise: Promise) {
        try {
            if (apiKey.isBlank()) {
                promise.reject("INVALID_API_KEY", "API key cannot be null or empty")
                return
            }

            val context = reactApplicationContext

            // Convert the logLevel number to the LogLevel enum
            val logLevelEnum = when (logLevel.toInt()) {
                0 -> com.appstack.attribution.LogLevel.DEBUG
                1 -> com.appstack.attribution.LogLevel.INFO
                2 -> com.appstack.attribution.LogLevel.WARN
                3 -> com.appstack.attribution.LogLevel.ERROR
                else -> com.appstack.attribution.LogLevel.INFO
            }

            // Validate that SDK classes are available
            try {
                AppstackAttributionSdk::class.java
            } catch (e: Exception) {
                promise.reject("SDK_CLASSES_ERROR", "SDK classes not available: ${e.message}", e)
                return
            }

            // Testing-only proxy override, read from the app's manifest metadata. This is
            // NOT exposed through the public configure() API: a proxy URL is applied only if
            // the host app deliberately ships an APPSTACK_DEV_PROXY_URL <meta-data> entry
            // (this repo's demo/test hosts do; published-package consumers do not). Routed
            // through the SDK's internal setProxyUrl hook, before configure so the SDK's
            // initial requests target it.
            readDevProxyUrl()?.takeIf { it.isNotBlank() }?.let {
                AppstackAttributionSdk.setProxyUrl(it)
            }

            // configureWrapper is the internal entry point that still accepts the RN wrapper version.
            AppstackAttributionSdk.configureWrapper(
                context = context,
                apiKey = apiKey.trim(),
                wrapperVersion = WRAPPER_VERSION,
                logLevel = logLevelEnum,
                customerUserId = customerUserId?.takeIf { it.isNotBlank() }
            )

            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("CONFIGURATION_ERROR", "Failed to configure SDK: ${exception.message}", exception)
        }
    }

    /**
     * Sets — or clears — the customer user id after configure(). Forwarded verbatim,
     * without the configure path's `takeIf { it.isNotBlank() }`: null/blank is a clear here.
     */
    fun setCustomerUserId(customerUserId: String?, promise: Promise) {
        try {
            AppstackAttributionSdk.setCustomerUserId(customerUserId)
            promise.resolve(null)
        } catch (exception: Exception) {
            promise.reject(
                "SET_CUSTOMER_USER_ID_ERROR",
                "Failed to set customer user ID: ${exception.message}",
                exception
            )
        }
    }

    /**
     * Reads the repo-only APPSTACK_DEV_PROXY_URL <meta-data> value from the host app's
     * manifest, mirroring the iOS Info.plist key of the same name. Returns null when the
     * key is absent (the published-package case).
     */
    private fun readDevProxyUrl(): String? {
        return try {
            val appInfo = reactApplicationContext.packageManager.getApplicationInfo(
                reactApplicationContext.packageName,
                PackageManager.GET_META_DATA
            )
            appInfo.metaData?.getString("APPSTACK_DEV_PROXY_URL")
        } catch (e: Exception) {
            null
        }
    }

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

    fun enableAppleAdsAttribution(promise: Promise) {
        // Apple Ads Attribution is iOS-only, so we return false on Android
        promise.resolve(false)
    }

    fun disableASAAttributionTracking(promise: Promise) {
        // Apple Search Ads attribution is iOS-only, so we return false on Android
        promise.resolve(false)
    }

    fun clearData(promise: Promise) {
        try {
            AppstackAttributionSdk.clearData()
            promise.resolve(true)
        } catch (exception: Exception) {
            promise.reject("CLEAR_DATA_ERROR", "Failed to clear data: ${exception.message}", exception)
        }
    }

    fun isEnabled(promise: Promise) {
        try {
            val enabled = AppstackAttributionSdk.isEnabled()
            promise.resolve(enabled)
        } catch (exception: Exception) {
            promise.reject("STATUS_ERROR", "Failed to get SDK status: ${exception.message}", exception)
        }
    }

    fun getAppstackId(promise: Promise) {
        try {
            val appstackId = AppstackAttributionSdk.getAppstackId()
            promise.resolve(appstackId)
        } catch (exception: Exception) {
            promise.reject("GET_APPSTACK_ID_ERROR", "Failed to get Appstack ID: ${exception.message}", exception)
        }
    }

    fun isSdkDisabled(promise: Promise) {
        try {
            val disabled = AppstackAttributionSdk.isSdkDisabled()
            promise.resolve(disabled)
        } catch (exception: Exception) {
            promise.reject("STATUS_ERROR", "Failed to check if SDK is disabled: ${exception.message}", exception)
        }
    }

    fun getAttributionParams(promise: Promise) {
        try {
            val params = AppstackAttributionSdk.getAttributionParams(rawReferrer = null)

            // Convert Map<String, Any> to WritableMap using Arguments factory
            val writableMap = Arguments.createMap()

            params.forEach { (key, value) ->
                writableMap.putString(key, value)
            }

            promise.resolve(writableMap)
        } catch (exception: Exception) {
            promise.reject("ATTRIBUTION_PARAMS_ERROR", "Failed to get attribution parameters: ${exception.message}", exception)
        }
    }
}
