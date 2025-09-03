# React Native Appstack SDK

Track events and revenue with this SDK. You will also be able to activate Apple Search Ads attribution for your iOS applications.

[![npm version](https://badge.fury.io/js/react-native-appstack-sdk.svg)](https://badge.fury.io/js/react-native-appstack-sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Installation

```bash
npm install react-native-appstack-sdk
cd ios && pod install  # Only needed for iOS
```

### Platform Configuration

**iOS Configuration:**

- **iOS version** 14.3+ recommended to use Apple Search Ads 

Add to `ios/YourApp/Info.plist`:
```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://ios-appstack.com/</string>
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
import AppstackSDK from 'react-native-appstack-sdk';

const App = () => {
  useEffect(() => {
    const init = async () => {
      const apiKey = Platform.OS === 'ios' 
        ? 'your-ios-api-key' 
        : 'your-android-api-key';
      
      await AppstackSDK.configure(apiKey);
      
      if (Platform.OS === 'ios') {
        await AppstackSDK.enableAppleAdsAttribution();
      }
    };
    
    init();
  }, []);

  const trackPurchase = () => {
    AppstackSDK.sendEvent('purchase', 29.99);
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

### `sendEvent(name: string, revenue?: number): Promise<boolean>`
Tracks custom events with optional revenue data. Use this for all user actions you want to measure.

**Parameters:**
- `name` - Event name (must match your Appstack dashboard configuration)
- `revenue` - Optional revenue amount in dollars (e.g., 29.99 for $29.99)

**Returns:** Promise that resolves to `true` if event was sent successfully

**Examples:**
```typescript
// Track events without revenue
await AppstackSDK.sendEvent('user_registration');
await AppstackSDK.sendEvent('level_completed');

// Track events with revenue
await AppstackSDK.sendEvent('purchase', 29.99);
await AppstackSDK.sendEvent('subscription', 9.99);
```

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

---

## Advanced

<details>
<summary>Requirements</summary>

- **React Native** 0.72.0+
- **iOS** 13.0+ 
- **Android** 5.0+ (API level 21)
- **Xcode** 14.0+
- **Java** 17+
- **Node.js** 16.0+
</details>

<details>
<summary>Important Notes</summary>

**Initialization:**
- Always configure SDK before sending events
- Do it in your root component

**Event Names:**
- Should always match on both platform usage
- Case-sensitive

**Revenue:**
- Accepts `number` or `string`
- Strings automatically converted to numbers

**Apple Search Ads:**
- iOS 14.3+ required
- Attribution data appears within 24-48 hours

**Platform Support:**
- iOS: Full support
- Android: Full support
</details>

## Documentation

- [Complete Usage Guide](./USAGE.md)
- [GitHub Repository](https://github.com/appstack-tech/react-native-appstack-sdk)
