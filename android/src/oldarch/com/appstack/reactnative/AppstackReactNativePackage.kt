package com.appstack.reactnative

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

/**
 * React Native package for Appstack SDK integration, legacy architecture.
 *
 * Uses the plain ReactPackage interface rather than BaseReactPackage so the
 * declared peer range (react-native >= 0.72.0) stays honest: BaseReactPackage was
 * only introduced later. The new-architecture counterpart lives in src/newarch.
 */
class AppstackReactNativePackage : ReactPackage {

    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        return listOf(AppstackReactNativeModule(reactContext))
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return emptyList()
    }
}
