# react-native-appstack-sdk

React Native bridge for Appstack iOS SDK - Event and revenue tracking with SKAdNetwork integration.

[![npm version](https://badge.fury.io/js/react-native-appstack-sdk.svg)](https://badge.fury.io/js/react-native-appstack-sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## 📋 Requirements

- **React Native** 0.60+
- **iOS** 13.0+
- **Xcode** 14.0+
- **Node.js** 16.0+

## 📦 Installation

### 1. Install the package

```bash
npm install react-native-appstack-sdk
# or
yarn add react-native-appstack-sdk
```

### 2. iOS Installation (CocoaPods)

```bash
cd ios && pod install
```

### 3. Info.plist Configuration

Add the following entry to your `ios/YourApp/Info.plist` file:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://ios-appstack.com/</string>
```

## 🚀 Basic Usage

### Import and Configure

```typescript
import AppstackSDK from 'react-native-appstack-sdk';

// Configure the SDK when starting the app
const initializeAppstack = async () => {
  try {
    await AppstackSDK.configure('your-api-key');
    console.log('Appstack SDK configured successfully');
  } catch (error) {
    console.error('Error configuring Appstack SDK:', error);
  }
};

// Call in App.js or your main component
useEffect(() => {
  initializeAppstack();
}, []);
```

### Send Events

```typescript
// Basic event
await AppstackSDK.sendEvent('user_registered');

// Event with revenue
await AppstackSDK.sendEventWithRevenue('purchase', 29.99);

// Event with revenue as string
await AppstackSDK.sendEventWithRevenue('subscription', '9.99');
```

### Enable Apple Search Ads Attribution

```typescript
// Enable ASA Attribution (requires iOS 14.3+)
try {
  await AppstackSDK.enableASAAttribution();
  console.log('ASA Attribution enabled');
} catch (error) {
  console.error('Error enabling ASA Attribution:', error);
}
```

## 🔧 Complete API

### `configure(apiKey: string): Promise<boolean>`

Configure the SDK with your Appstack API key.

```typescript
await AppstackSDK.configure('your-api-key');
```

### `sendEvent(eventName: string): Promise<boolean>`

Send a basic event without parameters.

```typescript
await AppstackSDK.sendEvent('custom_event');
```

### `sendEventWithRevenue(eventName: string, revenue: number | string): Promise<boolean>`

Send an event with revenue parameter.

```typescript
await AppstackSDK.sendEventWithRevenue('purchase', 29.99);
```

### `enableASAAttribution(): Promise<boolean>`

Enable Apple Search Ads Attribution tracking (iOS 14.3+).

```typescript
await AppstackSDK.enableASAAttribution();
```

## 🎯 Complete Example

```typescript
import React, { useEffect, useState } from 'react';
import { View, Button, Alert } from 'react-native';
import AppstackSDK from 'react-native-appstack-sdk';

const App = () => {
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    initializeSDK();
  }, []);

  const initializeSDK = async () => {
    try {
      // Configure SDK
      await AppstackSDK.configure('your-api-key');
      
      // Enable ASA Attribution
      await AppstackSDK.enableASAAttribution();
      
      setIsInitialized(true);
      console.log('Appstack SDK initialized successfully');
    } catch (error) {
      console.error('Error initializing SDK:', error);
      Alert.alert('Error', 'Could not initialize SDK');
    }
  };

  const handleSignup = async () => {
    try {
      await AppstackSDK.sendEvent('signup');
      Alert.alert('Success', 'Signup event sent');
    } catch (error) {
      console.error('Error sending event:', error);
    }
  };

  const handlePurchase = async () => {
    try {
      await AppstackSDK.sendEventWithRevenue('purchase', 99.99);
      Alert.alert('Success', 'Purchase event sent');
    } catch (error) {
      console.error('Error sending event:', error);
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', padding: 20 }}>
      <Button
        title="Send Signup Event"
        onPress={handleSignup}
        disabled={!isInitialized}
      />
      <Button
        title="Send Purchase Event"
        onPress={handlePurchase}
        disabled={!isInitialized}
      />
    </View>
  );
};

export default App;
```

## ⚠️ Important Considerations

### 1. **Initialization**
- Always configure the SDK before sending events
- Configuration must be done on the main thread
- Recommended to do it in the root component of the app

### 2. **Event Names**
- Event names must match exactly those configured in the Appstack dashboard
- They are case-sensitive
- You can use any string as event name

### 3. **Revenue**
- The SDK accepts revenue values as `number` or `string`
- Strings are automatically converted to numbers
- Invalid values (like `NaN`) will generate errors

### 4. **Apple Search Ads Attribution**
- Requires iOS 14.3 or higher
- Works both with and without ATT consent
- Data may take up to 24 hours to appear

### 5. **Supported Platforms**
- Currently only supports iOS
- On Android, methods return `false` and show warnings in console

## 🐛 Error Handling

```typescript
import AppstackSDK, { AppstackError, AppstackErrorCode } from 'react-native-appstack-sdk';

try {
  await AppstackSDK.configure('');
} catch (error) {
  if (error instanceof AppstackError) {
    switch (error.code) {
      case AppstackErrorCode.INVALID_API_KEY:
        console.error('Invalid API key');
        break;
      case AppstackErrorCode.CONFIGURATION_ERROR:
        console.error('Configuration error');
        break;
      default:
        console.error('Unknown error:', error.message);
    }
  }
}
```

## 📚 Additional Resources

- [Appstack Dashboard](https://dashboard.appstack.com/)
- [iOS SDK Documentation](https://github.com/appstack/ios-appstack-sdk)
- [SKAdNetwork Guide](https://developer.apple.com/documentation/storekit/skadnetwork)

## 🤝 Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a branch for your feature (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## 📄 License

This project is under the MIT license. See the [LICENSE](LICENSE) file for more details.

## 📞 Support

For questions or issues:

- **GitHub Issues**: [Create an issue](https://github.com/your-org/react-native-appstack-sdk/issues)
- **Email**: support@appstack.com

---

**Note**: This is an unofficial bridge for the Appstack iOS SDK. For the official SDK, visit [appstack.com](https://appstack.com).