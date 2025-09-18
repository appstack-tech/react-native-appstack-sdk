# Appstack SDK Demo App 📱

This is a demo React Native app showcasing the Appstack Attribution SDK integration. Built with [Expo](https://expo.dev) and [`create-expo-app`](https://www.npmjs.com/package/create-expo-app).

## Features

This demo app demonstrates:
- ✅ **Full SDK Configuration** - All available parameters including debug mode, custom endpoints, and log levels
- ✅ **Basic Configuration** - Backward-compatible simple setup
- ✅ **Event Tracking** - Standard events, custom events, and revenue tracking
- ✅ **Error Handling** - Comprehensive error handling and user feedback
- ✅ **Cross-Platform** - Works on both iOS and Android

## Get started

1. Install dependencies

   ```bash
   npm install
   ```

2. Start the app

   ```bash
   npx expo start
   ```

In the output, you'll find options to open the app in a

- [development build](https://docs.expo.dev/develop/development-builds/introduction/)
- [Android emulator](https://docs.expo.dev/workflow/android-studio-emulator/)
- [iOS simulator](https://docs.expo.dev/workflow/ios-simulator/)
- [Expo Go](https://expo.dev/go), a limited sandbox for trying out app development with Expo

You can start developing by editing the files inside the **app** directory. This project uses [file-based routing](https://docs.expo.dev/router/introduction).

## Appstack SDK Usage

### Configuration Options

The SDK supports multiple configuration approaches:

#### Full Configuration (Recommended for Development)
```typescript
import AppstackSDK from 'react-native-appstack-sdk';

await AppstackSDK.configure(
  'your-api-key',
  true, // isDebug - enable debug mode
  'https://api.event.dev.appstack.tech/android/', // endpointBaseUrl - custom endpoint
  0 // logLevel - 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
);
```

#### Basic Configuration (Production)
```typescript
// Backward compatible - uses default values
await AppstackSDK.configure('your-api-key');
```

#### Parameter Details

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `apiKey` | `string` | **Required** | Your Appstack API key from the dashboard |
| `isDebug` | `boolean` | `false` | Enable debug mode for detailed logging |
| `endpointBaseUrl` | `string?` | Platform default | Custom API endpoint URL |
| `logLevel` | `number` | `1` (INFO) | Log level: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR |

### Event Tracking

#### Standard Events
```typescript
// Event without revenue
await AppstackSDK.sendEvent(null, 'SIGN_UP');

// Event with revenue
await AppstackSDK.sendEvent(null, 'PURCHASE', 29.99);

// Revenue as string
await AppstackSDK.sendEvent(null, 'PURCHASE', '29.99');
```

#### Custom Events
```typescript
// Custom event names are automatically handled
await AppstackSDK.sendEvent('CUSTOM_EVENT_NAME', 'CUSTOM', 15.50);
```

#### Supported Event Types
- `INSTALL` (automatic)
- `SIGN_UP`
- `PURCHASE`
- `SUBSCRIPTION`
- `AD_CLICK`
- `LEVEL_COMPLETE`
- Custom event names (any string)

### Error Handling

```typescript
try {
  await AppstackSDK.configure('your-api-key');
  await AppstackSDK.sendEvent('PURCHASE', 29.99);
} catch (error) {
  console.error('SDK Error:', error.message);
  // Handle error appropriately
}
```

### Platform-Specific Features

#### iOS Only
```typescript
import { Platform } from 'react-native';

if (Platform.OS === 'ios') {
  await AppstackSDK.enableAppleAdsAttribution();
}
```

## Demo App Features

This app demonstrates all SDK capabilities:

1. **Configuration Testing** - Switch between full and basic configuration
2. **Event Tracking** - Test different event types with and without revenue
3. **Error Handling** - See how errors are handled and displayed
4. **Real-time Feedback** - Visual confirmation of successful operations

## Development Tips

1. **Use Debug Mode** - Enable `isDebug: true` during development for detailed logs
2. **Test Both Platforms** - Verify functionality on both iOS and Android
3. **Handle Errors** - Always wrap SDK calls in try-catch blocks
4. **Validate Revenue** - Ensure revenue values are valid numbers

## Get a fresh project

When you're ready, run:

```bash
npm run reset-project
```

This command will move the starter code to the **app-example** directory and create a blank **app** directory where you can start developing.

## Learn more

To learn more about developing your project with Expo, look at the following resources:

- [Expo documentation](https://docs.expo.dev/): Learn fundamentals, or go into advanced topics with our [guides](https://docs.expo.dev/guides).
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/): Follow a step-by-step tutorial where you'll create a project that runs on Android, iOS, and the web.

## Join the community

Join our community of developers creating universal apps.

- [Expo on GitHub](https://github.com/expo/expo): View our open source platform and contribute.
- [Discord community](https://chat.expo.dev): Chat with Expo users and ask questions.
