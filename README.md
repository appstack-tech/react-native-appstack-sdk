# React Native Appstack SDK

Track events and revenue with this SDK. You will also be able to activate Apple Search Ads attribution for your iOS applications and retrieve detailed attribution parameters from both iOS and Android.

[![npm version](https://badge.fury.io/js/react-native-appstack-sdk.svg)](https://badge.fury.io/js/react-native-appstack-sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

### **npmjs.org repository**

Here, you will find the [npmjs.org](http://npmjs.org)[ react-native-appstack-sdk documentation](https://www.npmjs.com/package/react-native-appstack-sdk). Please use the latest available version of the SDK.

## **Requirements**

### **iOS**

- **iOS version:** 15.0+ (Apple Ads attribution requires 14.3+, always satisfied at this floor)
- **Xcode:** 16.0+ (the vendored framework is built with Swift 6)
- **React Native:** 0.72.0+

### **Android**

- **Minimum SDK:** Android 5.0 (API level 21)
- **Target SDK:** 34+
- **Java Version:** 17+

### **General**

- **Node.js:** 16.0+

## **Initial setup**

### 1. Installation

```
npm install react-native-appstack-sdk
cd ios && pod install  # Only needed for iOS
```

**Android configuration**

No additional configuration is needed for Android; the SDK will work automatically after installation.

### 2. Quickstart

```javascript
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

      // Request tracking permission and enable Apple Ads Attribution
      if (Platform.OS === 'ios') {
        await AppstackSDK.enableAppleAdsAttribution();
      }
    };

    init();
  }, []);

  const trackPurchase = () => {
    AppstackSDK.sendEvent(EventType.PURCHASE, { revenue: 29.99, currency: 'USD' });
  };

  // ... your app
};
```

### 3. Configuration parameters

Initializes the SDK with your API key. Must be called before any other SDK methods.

```javascript
configure(apiKey, options?)
```

Parameters:

- `apiKey` - Your platform-specific API key from the Appstack dashboard
- `options` - Optional configuration object:
  - `logLevel` - `0=DEBUG`, `1=INFO`, `2=WARN`, `3=ERROR` (default `1`)
  - `customerUserId` - Optional customer user identifier to associate with the device/session

Returns: A promise that resolves to `true` if configuration was successful

Example:

```javascript
const success = await AppstackSDK.configure('your-api-key-here');
if (!success) {
  console.error('SDK configuration failed');
}

// With options
await AppstackSDK.configure('your-api-key-here', {
  logLevel: 0, // verbose logging
  customerUserId: 'user_123',
});
```

**Migrating from the 2.x positional signature**

2.x also accepted `configure(apiKey, isDebug, endpointBaseUrl, logLevel, customerUserId)`.
That form was removed in 3.0, along with `isDebug` and `endpointBaseUrl` — neither was
ever forwarded to the native SDKs. Move the two parameters that do something into the
options object:

```javascript
// 2.x — removed in 3.0, now throws
await AppstackSDK.configure('your-api-key-here', false, undefined, 0, 'user_123');

// 3.0
await AppstackSDK.configure('your-api-key-here', { logLevel: 0, customerUserId: 'user_123' });
```

The call throws rather than ignoring the extra arguments, because silently accepting it
would drop the `logLevel` and `customerUserId` you passed.

### 4. Sending events

Track user actions and revenue in your app:

`sendEvent` takes the event and, optionally, its parameters:

```javascript
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

// Standard events — the recommended form
await AppstackSDK.sendEvent(EventType.LOGIN);
await AppstackSDK.sendEvent(EventType.PURCHASE, { revenue: 29.99, currency: 'USD' });
await AppstackSDK.sendEvent(EventType.SUBSCRIBE, { revenue: 9.99, plan: 'monthly' });

// The string name of a standard event works too, case-insensitively
await AppstackSDK.sendEvent('PURCHASE', { revenue: 29.99, currency: 'USD' });

// Custom events — pass your own name as the event
await AppstackSDK.sendEvent('user_attributes', {
  email: 'test@example.com',
  name: 'John Doe',
  phone_number: '+33060000000',
  date_of_birth: '2026-02-01',
});
```

Anything that is not a standard event type is sent as a custom event under that
name, so there is no separate "custom" mode to opt into. Three exceptions: an
empty or non-string event rejects, the literal `'CUSTOM'` rejects (it is the
internal category, not a name), and the automatic-only events below are dropped
rather than turned into custom events.

`sendEvent` is `async`, so an invalid call rejects the returned promise rather
than throwing synchronously. Under `await` that surfaces as a thrown error as
usual; if you call it fire-and-forget, attach a `.catch()` or it becomes an
unhandled rejection.

**Parameters**

- `event` - A standard `EventType` (recommended), the string name of one, or your own name for a custom event
- `parameters` - Optional JSON-safe parameters object (e.g. `{ revenue: 29.99, currency: 'USD' }`). Values must be JSON-representable — a `Date`, class instance or function never survives the bridge and is a type error. Top-level keys whose value is `null` or `undefined` are stripped, so both platforms receive the same map; stripping is shallow, so a `null` nested inside an object or array is preserved. `AppstackEventParameters` and `JsonValue` are exported if you want to annotate a payload

Returns: a promise that resolves `void` — **not** a delivery receipt. For a sent
event it resolves once the call reaches the native SDK, and the native SDKs also
drop events when the SDK is disabled, offline, or still buffering, none of which
is visible from JavaScript. Automatic-only events (`INSTALL`, `FIRST_OPEN`,
`FIRST_OPEN_GUARDED`) never reach native at all: they resolve after being
dropped, with an error logged.

**Available EventType values**

Standard events are strongly recommended: they carry semantics that enhanced app
campaigns optimise against, which custom events do not.

- `INSTALL` - App installation (tracked automatically; a manual send is dropped with an error logged)
- `LOGIN`, `SIGN_UP`, `REGISTER` - Authentication
- `PURCHASE`, `ADD_TO_CART`, `ADD_TO_WISHLIST`, `INITIATE_CHECKOUT`, `START_TRIAL`, `SUBSCRIBE` - Monetization
- `LEVEL_START`, `LEVEL_COMPLETE` - Game progression
- `TUTORIAL_COMPLETE`, `SEARCH`, `VIEW_ITEM`, `VIEW_CONTENT`, `SHARE` - Engagement

In development builds, passing a string that is not one of these logs a warning
naming the custom event it became, so a typo like `'PURCAHSE'` is visible instead
of silently becoming a custom event.

> **Migrating from 2.x:** `sendEvent(eventType, eventName, parameters)` was removed
> in 3.0 and now throws with a message pointing at the new form. Drop the middle
> argument:
>
> ```js
> sendEvent('PURCHASE', null, params)           // → sendEvent(EventType.PURCHASE, params)
> sendEvent('CUSTOM', 'user_attributes', params) // → sendEvent('user_attributes', params)
> sendEvent('CUSTOM', 'APP_OPENED')              // → sendEvent('APP_OPENED')
> ```
>
> The two-argument `sendEvent('CUSTOM', 'my_event')` form is rejected as well, not
> just the three-argument one: its name would otherwise bind to `parameters`.
> `EventType.CUSTOM` was removed with the signature — pass your event's name
> directly.

**Enhanced app campaigns**

> **Tip:** When running enhanced app campaigns (EACs), it is highly recommended to send multiple parameters with the in-app event to improve matching quality.

For any event that represents revenue, we recommend sending:

1. `revenue` or `price` (number)
2. `currency` (string, e.g. `EUR`, `USD`)

```javascript
await AppstackSDK.sendEvent(EventType.PURCHASE, { revenue: 4.99, currency: 'EUR' });
```

To improve matching quality on Meta, send events including the following parameters if you can fulfill them:

1. `email`
2. `name` (first + last name in the same field).
3. `phone_number`
4. `date_of_birth` (recommended format: `YYYY-MM-DD`).

### 5. Customer user ID

The customer user ID is your own identifier for the signed-in user. Appstack attaches it to events so server-to-server events — which identify the user by this ID rather than by the install — can be joined back to the install that produced them.

If you already know the ID at startup, pass it to `configure`. More often a login reveals it afterwards, so set it whenever it becomes known:

```javascript
// On login
await AppstackSDK.setCustomerUserId('user-123');

// On logout — otherwise the previous user's ID stays attached to later events
await AppstackSDK.setCustomerUserId(null);
```

- `null`, `undefined`, and an empty or whitespace-only string all clear the stored ID — the value is trimmed first. (In `configure`, a blank string is rejected instead: `configure` never clears.)
- Callable at any time, before or after `configure`, as often as you like — the last call wins.
- Applies to every event sent from here on, including ones already buffered natively. Events already sent are not backfilled and do not need to be: Appstack maps the ID to the install using any event that carries it.
- The call itself sends nothing. Make sure at least one event follows, or no mapping is ever formed.
- Calling `configure` again to change the ID does not work — a second `configure` is a no-op and its `customerUserId` is ignored.

## **Advanced usage**

### **Environment-based configuration**

Set up different API keys for different environments:

```javascript
// .env.development
APPSTACK_IOS_API_KEY=your_ios_dev_key
APPSTACK_ANDROID_API_KEY=your_android_dev_key

// .env.production
APPSTACK_IOS_API_KEY=your_ios_prod_key
APPSTACK_ANDROID_API_KEY=your_android_prod_key
```

```javascript
import Config from 'react-native-config';

const apiKey = Platform.OS === 'ios'
  ? Config.APPSTACK_IOS_API_KEY
  : Config.APPSTACK_ANDROID_API_KEY;

await AppstackSDK.configure(apiKey);
```

## **Platform-specific considerations**

### **iOS**

**Apple Ads attribution:**

- Only works on iOS 14.3+
- Requires app installation from App Store or TestFlight
- Attribution data appears within 24-48 hours
- User consent may be required for detailed attribution (iOS 14.5+)

```javascript
import { Platform } from 'react-native';

if (Platform.OS === 'ios' && Platform.Version >= '14.3') {
  await AppstackSDK.enableAppleAdsAttribution();
}
```

### **Android**

**Play Store attribution:**

- Install referrer data collected automatically
- Attribution available immediately for Play Store installs
- Works with Android 5.0+ (API level 21)

### **Cross-platform best practices**

```javascript
const initializeSDK = async () => {
  const apiKey = Platform.select({
    ios: process.env.APPSTACK_IOS_API_KEY,
    android: process.env.APPSTACK_ANDROID_API_KEY,
    default: process.env.APPSTACK_DEFAULT_API_KEY
  });

  if (!apiKey) {
    console.error('Appstack API key not configured');
    return;
  }

  const configured = await AppstackSDK.configure(apiKey);

  if (configured && Platform.OS === 'ios') {
    await AppstackSDK.enableAppleAdsAttribution();
  }
};
```

## **Security considerations**

### **API key protection**

- Never commit API keys to version control
- Use environment variables or secure configuration
- Use different keys for development and production

```javascript
// ✅ Good - Use environment variables
const apiKey = Config.APPSTACK_API_KEY;

// ❌ Avoid - Hardcoded keys
const apiKey = "ak_live_1234567890abcdef"; // DON'T DO THIS
```

### **Data privacy**

- Event names and revenue data are transmitted securely over HTTPS
- No personally identifiable information (PII) should be included in event names
- The SDK does not collect device identifiers beyond what's required for attribution

## **Limitations**

### **Attribution timing**

- **iOS:** Apple Ads attribution data appears within 24-48 hours after install
- **Android:** Install referrer data available immediately for Play Store installs
- Attribution only available for apps installed from official stores

### **Platform constraints**

- **iOS:** Requires iOS 15.0+; Apple Ads attribution needs iOS 14.3+
- **Android:** Minimum API level 21 (Android 5.0)
- **React Native:** 0.72.0+
- Some Apple Ads features may not work in development/simulator environments

### **Event tracking**

- Event types are case-sensitive (use uppercase like 'PURCHASE', 'LOGIN')
- Parameters are passed as an object and can include any key-value pairs
- For revenue events, always pass a `revenue` (or `price`) and a `currency` parameter
- The SDK must be initialized before any tracking calls
- Network connectivity required for event transmission (events are queued offline)

### **Technical limitations**

- `enableAppleAdsAttribution()` only works on iOS and will do nothing on Android
- The event endpoint is not configurable on either platform, by design (the `endpointBaseUrl` argument was removed in 3.0; it was never forwarded to the native SDKs)
- Event name standardization is done for Android, but not for iOS yet

## **Troubleshooting**

### **Common Issues**

**Configuration fails:**

```javascript
// Check if API key is valid
const success = await AppstackSDK.configure(apiKey);
if (!success) {
  console.error('Invalid API key or network issue');
}
```

**Events not appearing in dashboard:**

- Check network connectivity
- Verify the API key is correct for the platform
- Events may take a few minutes to appear in the dashboard

**iOS Attribution not working:**

- Ensure iOS version is 14.3+
- Verify the app is installed from the App Store or TestFlight
- Allow 24-48 hours for attribution data to appear

## **Support**

For questions or issues:

1. Check the [GitHub Repository](https://github.com/appstack-tech/react-native-appstack-sdk)
2. Contact our support team at [support@appstack.tech](mailto:support@appstack.tech)
3. Open an issue in the repository
