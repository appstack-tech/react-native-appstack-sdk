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
    AppstackSDK.sendEvent('purchase', 29.99);
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

## Event Tracking

```typescript
// Events without revenue
AppstackSDK.sendEvent('user_registered');
AppstackSDK.sendEvent('level_completed');

// Events with revenue (purchases, subscriptions)
AppstackSDK.sendEvent('purchase', 29.99);
AppstackSDK.sendEvent('subscription', 9.99);
```

## Error Handling

```typescript
try {
  await AppstackSDK.sendEvent('purchase', 29.99);
} catch (error) {
  console.error('Failed to track event:', error);
}
```

---

## Advanced Topics

### Event Examples

<details>
<summary>E-commerce Events</summary>

```typescript
AppstackSDK.sendEvent('product_view_123');
AppstackSDK.sendEvent('add_to_cart', 15.99);
AppstackSDK.sendEvent('purchase_order_456', 89.97);
```
</details>

<details>
<summary>Gaming Events</summary>

```typescript
AppstackSDK.sendEvent('level_1_start');
AppstackSDK.sendEvent('level_1_complete');
AppstackSDK.sendEvent('in_app_purchase_coins', 4.99);
```
</details>

### Error Handling Options

<details>
<summary>Advanced Error Handling</summary>

```typescript
try {
  await AppstackSDK.configure('invalid-key');
} catch (error) {
  if (error.message.includes('API key')) {
    console.error('Invalid API key');
  } else if (error.message.includes('Event name')) {
    console.error('Invalid event name');
  }
}
```
</details>

<details>
<summary>Retry Logic</summary>

```typescript
const sendEventWithRetry = async (eventName: string, revenue?: number, maxRetries = 3) => {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      await AppstackSDK.sendEvent(eventName, revenue);
      return;
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
    }
  }
};
```
</details>

### Best Practices

<details>
<summary>Event Naming</summary>

```typescript
// ✅ Good
AppstackSDK.sendEvent('user_registration_completed');
AppstackSDK.sendEvent('purchase_premium_plan');

// ❌ Avoid  
AppstackSDK.sendEvent('event1');
AppstackSDK.sendEvent('stuff_happened');
```
</details>

<details>
<summary>Revenue Values</summary>

```typescript
// ✅ Use decimal dollars
AppstackSDK.sendEvent('purchase', 29.99);

// ❌ Avoid cents as dollars
AppstackSDK.sendEvent('purchase', 2999); // This would be $2,999!
```
</details>

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
AppstackSDK.sendEvent('purchase', 29.99);

// ✅ Convert cents to dollars  
const cents = 2999;
AppstackSDK.sendEvent('purchase', cents / 100);
```
</details>

### Advanced Usage Options  

<details>
<summary>Custom Hook</summary>

```typescript
const useAppstackSDK = (iosKey: string, androidKey: string) => {
  const [isReady, setIsReady] = useState(false);
  
  useEffect(() => {
    const init = async () => {
      const key = Platform.OS === 'ios' ? iosKey : androidKey;
      await AppstackSDK.configure(key);
      if (Platform.OS === 'ios') {
        await AppstackSDK.enableAppleAdsAttribution();
      }
      setIsReady(true);
    };
    init();
  }, []);

  const trackEvent = (name: string, revenue?: number) => {
    if (isReady) AppstackSDK.sendEvent(name, revenue);
  };

  return { isReady, trackEvent };
};
```
</details>

---

Need help? Check the [GitHub repository](https://github.com/appstack-tech/react-native-appstack-sdk) or contact support.
