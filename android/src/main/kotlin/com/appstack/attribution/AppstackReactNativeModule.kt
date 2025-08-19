package com.appstack.attribution

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.appstack.reactnative.AppstackReactNativeModule as RealModule

@ReactModule(name = AppstackReactNativeModule.NAME)
class AppstackReactNativeModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    
    private val delegate = RealModule(reactContext)
    
    companion object {
        const val NAME = "AppstackReactNative"
    }

    override fun getName(): String {
        return NAME
    }
    
    // Delegate all methods to the real implementation
    fun configure(apiKey: String, promise: Promise) = delegate.configure(apiKey, promise)
    fun sendEvent(eventName: String, promise: Promise) = delegate.sendEvent(eventName, promise)
    fun sendEventWithRevenue(eventName: String, revenue: Dynamic, promise: Promise) = delegate.sendEventWithRevenue(eventName, revenue, promise)
    fun enableASAAttribution(promise: Promise) = delegate.enableASAAttribution(promise)
    fun flush(promise: Promise) = delegate.flush(promise)
    fun clearData(promise: Promise) = delegate.clearData(promise)
    fun isEnabled(promise: Promise) = delegate.isEnabled(promise)
}
