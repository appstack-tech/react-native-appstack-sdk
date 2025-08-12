# React Native Appstack SDK - Usage Example

This SDK is now built and ready for use in React Native applications.

## Installation

### Option 1: Local Installation (For Development)
```bash
# In your React Native project
npm install file:../path/to/react-native-appstack-sdk
```

### Option 2: From Git Repository
```bash
npm install git+https://github.com/your-org/react-native-appstack-sdk.git
```

### Option 3: If Published to NPM
```bash
npm install react-native-appstack-sdk
```

## Platform Setup

### iOS Setup
1. Run `cd ios && pod install` to install the native iOS dependencies
2. The SDK includes pre-built framework files in `ios/` directory

### Android Setup
1. The Android native code is in `android/sdk/` directory
2. No additional setup required - the native module should auto-link

## Basic Usage

```typescript
import React, { useEffect } from 'react';
import { View, Button, Alert } from 'react-native';
import AppstackSDK from 'react-native-appstack-sdk';

const App = () => {
  useEffect(() => {
    // Configure the SDK when app starts
    initializeSDK();
  }, []);

  const initializeSDK = async () => {
    try {
      await AppstackSDK.configure('your-api-key-here');
      console.log('Appstack SDK configured successfully');
      
      // Enable Apple Search Ads Attribution (iOS only)
      if (Platform.OS === 'ios') {
        await AppstackSDK.enableASAAttribution();
      }
    } catch (error) {
      console.error('Failed to configure SDK:', error);
    }
  };

  const trackPurchase = async () => {
    try {
      await AppstackSDK.sendEventWithRevenue('PURCHASE', 29.99);
      Alert.alert('Success', 'Purchase event tracked!');
    } catch (error) {
      Alert.alert('Error', 'Failed to track event');
    }
  };

  const trackCustomEvent = async () => {
    try {
      await AppstackSDK.sendEvent('CUSTOM_EVENT');
      Alert.alert('Success', 'Custom event tracked!');
    } catch (error) {
      Alert.alert('Error', 'Failed to track event');
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', padding: 20 }}>
      <Button title="Track Purchase" onPress={trackPurchase} />
      <Button title="Track Custom Event" onPress={trackCustomEvent} />
    </View>
  );
};

export default App;
```

## Available Methods

- `configure(apiKey: string)` - Initialize the SDK with your API key
- `sendEvent(eventName: string)` - Send a basic event
- `sendEventWithRevenue(eventName: string, revenue: number | string)` - Send an event with revenue
- `enableASAAttribution()` - Enable Apple Search Ads Attribution (iOS only)

## TypeScript Support

The SDK includes full TypeScript definitions in `lib/typescript/index.d.ts` for excellent IDE support and type safety.

## Troubleshooting

If you encounter linking issues, make sure to:
1. Run `cd ios && pod install` for iOS
2. Rebuild your app after installing the package
3. Ensure you're not using Expo Go (use development build instead)

## Build Information

This SDK was built with:
- react-native-builder-bob for cross-platform builds
- CommonJS output in `lib/commonjs/`
- ES Modules output in `lib/module/`
- TypeScript definitions in `lib/typescript/`
