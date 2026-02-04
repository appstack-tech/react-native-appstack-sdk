# React Native Appstack SDK

Track events and revenue with this SDK. You will also be able to activate Apple Search Ads attribution for your iOS applications and retrieve detailed attribution parameters from both iOS and Android.

[![npm version](https://badge.fury.io/js/react-native-appstack-sdk.svg)](https://badge.fury.io/js/react-native-appstack-sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Overview

The Appstack React Native SDK lets you:

- Track standardized and custom events
- Track revenue events with currency (for ROAS / optimization)
- Enable Apple Ads attribution on iOS
- Retrieve the Appstack installation ID and attribution parameters

## Features (with examples)

### SDK initialization

```typescript
import { Platform } from 'react-native';
import AppstackSDK from 'react-native-appstack-sdk';

const apiKey = Platform.OS === 'ios' ? 'your-ios-api-key' : 'your-android-api-key';
await AppstackSDK.configure(apiKey);
```

### Event tracking (standard + custom)

```typescript
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

// Standard
await AppstackSDK.sendEvent(EventType.SIGN_UP);

// Custom
await AppstackSDK.sendEvent(EventType.CUSTOM, 'level_completed', { level: 12 });
```

### Revenue tracking (recommended for all ad networks)

```typescript
await AppstackSDK.sendEvent(EventType.PURCHASE, null, { revenue: 29.99, currency: 'EUR' });
// `price` is also accepted instead of `revenue`
```

### Installation ID + attribution parameters

```typescript
const appstackId = await AppstackSDK.getAppstackId();
const attributionParams = await AppstackSDK.getAttributionParams();
```

### Apple Ads attribution (iOS)

```typescript
import { Platform } from 'react-native';

if (Platform.OS === 'ios') {
  await AppstackSDK.enableAppleAdsAttribution();
}
```

## Installation

```bash
npm install react-native-appstack-sdk
cd ios && pod install  # Only needed for iOS
```

### Platform Configuration

**iOS Configuration:**

- **iOS version** 14.3+ recommended to use Apple Search Ads
- **Xcode 16+ and Swift 6** are required to build the iOS native module. The vendored AppstackSDK framework uses Swift 6 module interfaces; building with an older Swift version can cause errors like `value of type 'AppstackAttributionSdk' has no member 'configure'`. Ensure your EAS build image or local Xcode is recent enough (e.g. Xcode 16+).

Add to `ios/YourApp/Info.plist`:
```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://ios-appstack.com/</string>
```

Please define in your `ios/Podfile.properties.json` the following mendatory elements :
```json
{
  "expo.jsEngine": "hermes",
  "EX_DEV_CLIENT_NETWORK_INSPECTOR": "true",
  "newArchEnabled": "true"
}
```

**Android configuration:**
- **Minimum SDK:** Android 5.0 (API level 21)
- **Target SDK:** 34+
- **Java Version:** 17+

No additional configuration needed for Android - the SDK will work automatically after installation.

## Quick start

```typescript
import { useEffect } from 'react';
import { Platform } from 'react-native';
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

const App = () => {
  useEffect(() => {
    const init = async () => {
      const apiKey = Platform.OS === 'ios' 
        ? process.env.APPSTACK_IOS_API_KEY 
        : process.env.APPSTACK_ANDROID_API_KEY;
      
      await AppstackSDK.configure(apiKey);
      
      if (Platform.OS === 'ios') {
        await AppstackSDK.enableAppleAdsAttribution();
      }
      
      // Get attribution parameters
      const attributionParams = await AppstackSDK.getAttributionParams();
      console.log('Attribution data:', attributionParams);
    };
    
    init();
  }, []);

  const trackPurchase = () => {
    AppstackSDK.sendEvent(EventType.PURCHASE, null, { revenue: 29.99, currency: 'USD' });
  };

  // ... your app
};
```

## API

### `configure(apiKey: string): Promise<boolean>`
Initializes the SDK with your API key. Must be called before any other SDK methods.

**Parameters:**
- `apiKey` - Your platform-specific API key from the Appstack dashboard

**Returns:** Promise that resolves to `true` if configuration was successful

**Example:**
```typescript
const success = await AppstackSDK.configure('your-api-key-here');
if (!success) {
  console.error('SDK configuration failed');
}
```

### `sendEvent(eventType?: EventType | string, eventName?: string, parameters?: Record<string, any>): Promise<boolean>`
Tracks custom events with optional parameters. Use this for all user actions you want to measure.

**Parameters:**
- `eventType` - Event type from the EventType enum (preferred method for standard events)
- `eventName` - Event name (for backward compatibility or custom event names)
- `parameters` - Optional parameters object (e.g., `{ revenue: 29.99, currency: 'USD', productId: '123' }`)

**Returns:** Promise that resolves to `true` if event was sent successfully

**Examples:**
```typescript
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

// Using EventType enum (recommended)
await AppstackSDK.sendEvent(EventType.PURCHASE, null, { revenue: 29.99, currency: 'USD' });
await AppstackSDK.sendEvent(EventType.SIGN_UP);
await AppstackSDK.sendEvent(EventType.ADD_TO_CART);

// Using string event types
await AppstackSDK.sendEvent('PURCHASE', null, { revenue: 29.99, currency: 'USD' });
await AppstackSDK.sendEvent('SIGN_UP');

// Backward compatibility - using eventName only
await AppstackSDK.sendEvent(null, 'user_registration');
await AppstackSDK.sendEvent(null, 'purchase', { revenue: 29.99 });

// Custom events with custom names and parameters
await AppstackSDK.sendEvent(EventType.CUSTOM, 'my_custom_event', { 
  revenue: 15.50, 
  productId: 'prod_123',
  category: 'electronics'
});
```

**Available EventType values:**
- `INSTALL`, `LOGIN`, `SIGN_UP`, `REGISTER`
- `PURCHASE`, `ADD_TO_CART`, `ADD_TO_WISHLIST`, `INITIATE_CHECKOUT`, `START_TRIAL`, `SUBSCRIBE`
- `LEVEL_START`, `LEVEL_COMPLETE`
- `TUTORIAL_COMPLETE`, `SEARCH`, `VIEW_ITEM`, `VIEW_CONTENT`, `SHARE`
- `CUSTOM` (for application-specific events)

### `enableAppleAdsAttribution(): Promise<boolean>` (iOS only)
Enables Apple Search Ads attribution tracking. Call this after `configure()` on iOS to track App Store install sources.

**Returns:** Promise that resolves to `true` if attribution was enabled successfully

**Requirements:**
- iOS 14.3+
- App installed from App Store or TestFlight
- Attribution data appears within 24-48 hours

**Example:**
```typescript
if (Platform.OS === 'ios') {
  await AppstackSDK.enableAppleAdsAttribution();
}
```

### `getAppstackId(): Promise<string>`
Get the Appstack ID (equivalent to an install ID).

**Returns:** Promise that will returns a string containing the Appstack ID

**Example:**
```typescript
const appstackId = AppstackSDK.getAppstackId();
```

### `isSdkDisabled(): Promise<boolean>`
Check if the SDK is disabled.

**Returns:** Promise that resolves to `true` if the SDK is disabled, `false` otherwise

**Example:**
```typescript
const isDisabled = await AppstackSDK.isSdkDisabled();
if (isDisabled) {
  console.log('SDK is disabled');
}
```

### `getAttributionParams(): Promise<Record<string, any>>`
Retrieve attribution parameters from the SDK. This returns all available attribution data that the SDK has collected.

**Returns:** Promise that resolves to an object containing attribution parameters (key-value pairs)

**Returns data on success:** Object with various attribution-related data depending on the platform and SDK configuration

**Returns empty object:** `{}` if no attribution parameters are available

**Example:**
```typescript
const attributionParams = await AppstackSDK.getAttributionParams();
console.log('Attribution parameters:', attributionParams);

// Example output (varies by platform):
// {
//   "attribution_source": "google_play",
//   "install_timestamp": "1733629800",
//   "attributed": "true",
//   ...
// }
```

**Use Cases:**
- Retrieve attribution data for analytics
- Check if the app was attributed to a specific campaign
- Log attribution parameters for debugging
- Send attribution data to your backend server
- Analyze user acquisition sources

---

## Advanced

<details>
<summary>Security Considerations</summary>

**Data Privacy:**
- Event names and revenue data are transmitted securely over HTTPS
- No personally identifiable information (PII) should be included in event names
- The SDK does not collect device identifiers beyond what's required for attribution

**Network Security:**
- All API communications use TLS 1.2+ encryption
- Certificate pinning is implemented for additional security
- Requests are authenticated using your API key
</details>

<details>
<summary>Limitations</summary>

**Attribution Timing:**
- Apple Search Ads attribution data appears within 24-48 hours after install
- Attribution is only available for apps installed from App Store or TestFlight
- Attribution requires user consent on iOS 14.5+ (handled automatically)

**Platform Constraints:**
- **iOS:** Requires iOS 13.0+, Apple Search Ads attribution needs iOS 14.3+
- **Android:** Minimum API level 21 (Android 5.0)
- **React Native:** 0.72.0+
- **Xcode:** 14.0+
- **Java:** 17.0+
- **Node.js** 16.0+
- Some Apple Search Ads features may not work in some development/simulator environments

**Event Tracking:**
- Event names are case-sensitive and must match be standardized (already done for Android but not for iOS)
- For revenue events, always pass a `revenue` (or `price`) and a `currency` parameter
- For now, we can't configure the endpoint to send the events for iOS, this will be patched in a future release.

**Technical Limitations:**
- SDK must be initialized before any tracking calls
- enableAppleAdsAttribution only works on iOS and will do nothing on Android.
- Network connectivity required for event transmission (events are queued offline)
- Some attribution features require app to be distributed through official stores
</details>

## Troubleshooting

### iOS: "value of type 'AppstackAttributionSdk' has no member 'configure'" (and sendEvent, getAppstackId, getAttributionParams)

This occurs when the iOS native SDK (xcframework) is built with Swift 6 and its public API is conditionally exposed. The React Native SDK now forces **Swift 6** for the `react-native-appstack-sdk` Pod so the compiler sees the full API.

- **EAS Build:** Use an image that includes **Xcode 16+** (e.g. `image: latest` or `macos-ventura-xcode-16`). Older Xcode images use Swift 5 and will hit this error.
- **Expo + expo-apple-targets:** The error is unrelated to having a widget or other Apple target; it comes from the main app target’s Pod build. Ensuring Swift 6 for the Pod (as in the current podspec) and using Xcode 16+ on EAS should fix it.
- **Local Xcode:** Upgrade to Xcode 16+ and run `cd ios && pod install` (or `npx expo prebuild --clean` if using Expo).

### Android build issues

See the [CHANGELOG](CHANGELOG.md) for version-specific Android fixes (e.g. Hermes, ProGuard).

## Documentation

- [Complete Usage Guide](./USAGE.md)
- [GitHub Repository](https://github.com/appstack-tech/react-native-appstack-sdk)

---

## EAC recommendations

### Revenue events (all ad networks)

For any event that represents revenue, we recommend sending:

- `revenue` **or** `price` (number)
- `currency` (string, e.g. `EUR`, `USD`)

```typescript
await AppstackSDK.sendEvent(EventType.PURCHASE, null, { revenue: 4.99, currency: 'EUR' });
```

### Meta matching (send once per installation, as early as possible)

To improve matching quality on Meta, send events including the following parameters if you can fullfill them:

- `email`
- `name` (first + last name in the same field)
- `phone_number`
- `date_of_birth` (recommended format: `YYYY-MM-DD`)
```
