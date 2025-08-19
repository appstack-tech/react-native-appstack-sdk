package com.appstack.attribution

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.appstack.reactnative.AppstackReactNativePackage as RealPackage

class AppstackReactNativePackage : ReactPackage {
  private val delegate = RealPackage()

  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
    return delegate.createNativeModules(reactContext)
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return delegate.createViewManagers(reactContext)
  }
}
