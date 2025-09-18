# React Native Appstack SDK - Usage Guide

Track events and revenue with Apple Search Ads attribution in your React Native app.

## Installation

```bash
npm install react-native-appstack-sdk
cd ios && pod install  # iOS only
```

## Quick Start

```typescript
import { useEffect } from 'react';
import { Platform } from 'react-native';
import AppstackSDK from 'react-native-appstack-sdk';

const App = () => {
  useEffect(() => {
    const initSDK = async () => {
      const apiKey = Platform.OS === 'ios' 
        ? 'your-ios-api-key' 
        : 'your-android-api-key';
      
      await AppstackSDK.configure(apiKey);
      
      if (Platform.OS === 'ios') {
        await AppstackSDK.enableAppleAdsAttribution();
      }
    };
    
    initSDK();
  }, []);

  const trackPurchase = () => {
    AppstackSDK.sendEvent(null, 'PURCHASE', 29.99);
  };

  // ... your app
};
```

## iOS Configuration (Required)

Add to your `ios/YourApp/Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://ios-appstack.com/</string>
```

---

### Troubleshooting

<details>
<summary>Common Issues</summary>

**Package not linked:**
```bash
cd ios && pod install
npx react-native clean
```

**Events not tracking:**
- Check if `configure()` was called with correct API key
- Verify iOS Info.plist configuration

**Apple Search Ads not working:**
- Requires iOS 14.3+
- App must be from App Store/TestFlight
- Attribution data appears after 24-48 hours

**Wrong revenue values:**
```typescript
// ✅ Use decimal dollars
AppstackSDK.sendEvent(null, 'PURCHASE', 29.99);

// ✅ Convert cents to dollars  
const cents = 2999;
AppstackSDK.sendEvent(null, 'PURCHASE', cents / 100);
```
</details>

---

Need help? Check the [GitHub repository](https://github.com/appstack-tech/react-native-appstack-sdk) or contact support.
