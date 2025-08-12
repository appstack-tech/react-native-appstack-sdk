# Android Integration Guide

This guide explains how to integrate the Appstack SDK with your React Native Android app.

## Automatic Linking (React Native 0.60+)

The Android bridge is automatically linked with React Native's autolinking. Just run:

```bash
npx react-native run-android
```

## Manual Integration (if needed)

If autolinking doesn't work, you can manually register the package:

### 1. Add to MainApplication.java

In your `android/app/src/main/java/.../MainApplication.java` file:

```java
import com.appstack.attribution.AppstackReactNativePackage;

@Override
protected List<ReactPackage> getPackages() {
    @SuppressWarnings("UnnecessaryLocalVariable")
    List<ReactPackage> packages = new PackageList(this).getPackages();
    
    // Add this line:
    packages.add(new AppstackReactNativePackage());
    
    return packages;
}
```

### 2. Initialize SDK in Application.onCreate()

In your `MainApplication.java` file, add the SDK initialization to the `onCreate()` method:

```java
import com.appstack.attribution.AppStackAttributionSdk;

@Override
public void onCreate() {
    super.onCreate();
    
    // Initialize the Appstack SDK (optional for pre-configuration)
    // Note: You can also configure from React Native side using AppstackSDK.configure()
    // AppStackAttributionSdk.configure(this, "your-api-key", false);
}
```

## Usage in React Native

```typescript
import AppstackSDK from 'react-native-appstack-sdk';

// Configure the SDK
await AppstackSDK.configure('your-api-key');

// Send events
await AppstackSDK.sendEvent('PURCHASE');
await AppstackSDK.sendEvent('LOGIN');
await AppstackSDK.sendEvent('CUSTOM_EVENT'); // Custom events fallback to CUSTOM type

// Send events with revenue
await AppstackSDK.sendEventWithRevenue('PURCHASE', 29.99);
await AppstackSDK.sendEventWithRevenue('SUBSCRIBE', '9.99');

// Additional methods
await AppstackSDK.flush(); // Manually flush pending events
const enabled = await AppstackSDK.isEnabled(); // Check if SDK is enabled
await AppstackSDK.clearData(); // Clear all stored data
```

## Supported Event Types

The Android SDK supports these predefined event types:

- `INSTALL` (tracked automatically)
- `LOGIN`
- `SIGN_UP` / `REGISTER`
- `PURCHASE`
- `ADD_TO_CART`
- `ADD_TO_WISHLIST`
- `INITIATE_CHECKOUT`
- `START_TRIAL`
- `SUBSCRIBE`
- `LEVEL_START`
- `LEVEL_COMPLETE`
- `TUTORIAL_COMPLETE`
- `SEARCH`
- `VIEW_ITEM`
- `VIEW_CONTENT`
- `SHARE`
- `CUSTOM` (fallback for custom event names)

Any event name that doesn't match the predefined types will be sent as a `CUSTOM` event with the provided name.

## Build Configuration

Ensure your `android/app/build.gradle` has the minimum SDK requirements:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // Required minimum
        targetSdkVersion 34
    }
}
```

## Permissions

The SDK automatically handles required permissions. No additional permissions need to be declared in your AndroidManifest.xml.

## ProGuard/R8

The SDK includes consumer ProGuard rules, so no additional configuration is needed for code obfuscation.

## Error Handling

All SDK methods return promises that can reject with specific error codes:

```typescript
try {
    await AppstackSDK.configure('invalid-key');
} catch (error) {
    console.error('SDK Error:', error.code); // e.g., 'INVALID_API_KEY'
}
```

Error codes include:
- `INVALID_API_KEY`
- `INVALID_EVENT_NAME`
- `INVALID_REVENUE`
- `CONFIGURATION_ERROR`
- `EVENT_SEND_ERROR`
- `FLUSH_ERROR`
- `CLEAR_DATA_ERROR`
- `STATUS_ERROR`
