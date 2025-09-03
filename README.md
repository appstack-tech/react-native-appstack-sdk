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
<summary>Security Considerations</summary>

**API Key Protection:**
- **Never commit API keys** to version control or public repositories
- Store API keys in environment variables or secure configuration files

**Best Practices:**
```typescript
// ✅ Good - Use environment variables
const apiKey = Platform.OS === 'ios' 
  ? process.env.APPSTACK_IOS_API_KEY 
  : process.env.APPSTACK_ANDROID_API_KEY;

// ❌ Avoid - Hardcoded keys in source code
const apiKey = 'ak_live_1234567890abcdef'; // DON'T DO THIS
```

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
- Revenue values needs to be converted to USD
- For now, we can't configure the endpoint to send the events for iOS, this will be patched in a future release.

**Technical Limitations:**
- SDK must be initialized before any tracking calls
- enableAppleAdsAttribution only works on iOS and will do nothing on Android.
- Network connectivity required for event transmission (events are queued offline)
- Some attribution features require app to be distributed through official stores
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
