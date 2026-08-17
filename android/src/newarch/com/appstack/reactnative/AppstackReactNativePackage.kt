package com.appstack.reactnative

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

/**
 * React Native package for Appstack SDK integration, new architecture.
 *
 * BaseReactPackage is required here: ReactPackageTurboModuleManagerDelegate only
 * reads getModule() and getReactModuleInfoProvider() from BaseReactPackage
 * instances, so a plain ReactPackage would never be consulted for TurboModules.
 * The legacy counterpart lives in src/oldarch.
 *
 * createViewManagers is intentionally not overridden; the base class returns an
 * empty list when there are no view managers.
 */
class AppstackReactNativePackage : BaseReactPackage() {

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        return if (name == AppstackReactNativeModuleImpl.NAME) {
            AppstackReactNativeModule(reactContext)
        } else {
            null
        }
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
        return ReactModuleInfoProvider {
            mapOf(
                AppstackReactNativeModuleImpl.NAME to
                    ReactModuleInfo(
                        AppstackReactNativeModuleImpl.NAME,
                        AppstackReactNativeModule::class.java.name,
                        false, // canOverrideExistingModule
                        false, // needsEagerInit
                        false, // isCxxModule
                        true // isTurboModule
                    )
            )
        }
    }
}
