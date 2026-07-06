const {
  withInfoPlist,
  withAndroidManifest,
  AndroidConfig,
} = require('@expo/config-plugins');

// Repo-only Expo config plugin. Injects the Appstack dev proxy URL as a native
// manifest key on both platforms so THIS test app targets the dev environment via
// the SDK bridge's internal setProxyUrl hook (see AppstackBridge.swift /
// AppstackReactNativeModule.kt, which read APPSTACK_DEV_PROXY_URL).
//
// It is NOT part of the published react-native-appstack-sdk package: only the
// homepage-app's app.json references this plugin, so integrators' apps never ship
// the key and always hit production. This mirrors the Flutter sample_app's
// Info.plist / AndroidManifest APPSTACK_DEV_PROXY_URL hook.
const KEY = 'APPSTACK_DEV_PROXY_URL';
const IOS_DEV_PROXY = 'https://api.event.dev.appstack.tech';
const ANDROID_DEV_PROXY = 'https://api.event.dev.appstack.tech/android/';

module.exports = function withAppstackDevProxy(config) {
  config = withInfoPlist(config, (cfg) => {
    cfg.modResults[KEY] = IOS_DEV_PROXY;
    return cfg;
  });

  config = withAndroidManifest(config, (cfg) => {
    const app = AndroidConfig.Manifest.getMainApplicationOrThrow(cfg.modResults);
    AndroidConfig.Manifest.addMetaDataItemToMainApplication(
      app,
      KEY,
      ANDROID_DEV_PROXY
    );
    return cfg;
  });

  return config;
};
