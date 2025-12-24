# React Native Appstack SDK - Usage Guide

Track events and revenue with Apple Search Ads attribution in your React Native app.

## Overview

This guide follows the same structure across Appstack SDKs:

- Installation & platform configuration
- Quick start
- EAC recommendations

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
    AppstackSDK.sendEvent('PURCHASE', null, { revenue: 29.99, currency: 'USD' });
  };

  const appstacKId = AppstackSDK.getAppstackId()

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

## EAC recommendations

### Revenue events (all ad networks)

For any event that represents revenue, we recommend sending:

- `revenue` **or** `price` (number)
- `currency` (string, e.g. `EUR`, `USD`)

```typescript
import AppstackSDK from 'react-native-appstack-sdk';

await AppstackSDK.sendEvent('PURCHASE', null, { revenue: 4.99, currency: 'EUR' });
```

### Meta matching (send once per installation, as early as possible)

To improve matching quality on Meta, send events including the following parameters if you can fullfill them:

- `email`
- `name` (first + last name in the same field)
- `phone_number`
- `date_of_birth` (recommended format: `YYYY-MM-DD`)
```

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
// ✅ Use decimal dollars in parameters
AppstackSDK.sendEvent('PURCHASE', null, { revenue: 29.99, currency: 'USD' });

// ✅ Convert cents to dollars  
const cents = 2999;
AppstackSDK.sendEvent('PURCHASE', null, { revenue: cents / 100, currency: 'USD' });
```
</details>

---

Need help? Check the [GitHub repository](https://github.com/appstack-tech/react-native-appstack-sdk) or contact support.
