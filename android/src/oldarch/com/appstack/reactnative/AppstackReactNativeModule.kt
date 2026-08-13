package com.appstack.reactnative

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule

/**
 * Legacy-architecture module. Compiled only when newArchEnabled is false
 * (see the sourceSets block in android/build.gradle).
 *
 * Signatures deliberately match the codegen spec so both architectures expose an
 * identical surface to JavaScript. `logLevel: Double` is safe on the legacy
 * bridge: JavaMethodWrapper maps both boxed and primitive Double to the same
 * argument extractor.
 */
@ReactModule(name = AppstackReactNativeModuleImpl.NAME)
class AppstackReactNativeModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val impl = AppstackReactNativeModuleImpl(reactContext)

    override fun getName(): String = AppstackReactNativeModuleImpl.NAME

    @ReactMethod
    fun configure(apiKey: String, logLevel: Double, customerUserId: String?, promise: Promise) {
        impl.configure(apiKey, logLevel, customerUserId, promise)
    }

    @ReactMethod
    fun sendEvent(eventType: String?, eventName: String?, parameters: ReadableMap?, promise: Promise) {
        impl.sendEvent(eventType, eventName, parameters, promise)
    }

    @ReactMethod
    fun enableAppleAdsAttribution(promise: Promise) {
        impl.enableAppleAdsAttribution(promise)
    }

    @ReactMethod
    fun disableASAAttributionTracking(promise: Promise) {
        impl.disableASAAttributionTracking(promise)
    }

    @ReactMethod
    fun clearData(promise: Promise) {
        impl.clearData(promise)
    }

    @ReactMethod
    fun isEnabled(promise: Promise) {
        impl.isEnabled(promise)
    }

    @ReactMethod
    fun getAppstackId(promise: Promise) {
        impl.getAppstackId(promise)
    }

    @ReactMethod
    fun isSdkDisabled(promise: Promise) {
        impl.isSdkDisabled(promise)
    }

    @ReactMethod
    fun getAttributionParams(promise: Promise) {
        impl.getAttributionParams(promise)
    }
}
