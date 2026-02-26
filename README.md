# React Native Appstack SDK

Track events and revenue with this SDK. You will also be able to activate Apple Search Ads attribution for your iOS applications and retrieve detailed attribution parameters from both iOS and Android.

[![npm version](https://badge.fury.io/js/react-native-appstack-sdk.svg)](https://badge.fury.io/js/react-native-appstack-sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

### **npmjs.org repository**

Here, you will find the [npmjs.org](http://npmjs.org)[ react-native-appstack-sdk documentation](https://www.npmjs.com/package/react-native-appstack-sdk). Please use the latest available version of the SDK.

## **Requirements**

### **iOS**

- **iOS version:** 13.0+ (14.3+ recommended for Apple Ads)
- **Xcode:** 14.0+
- **React Native:** 0.72.0+

### **Android**

- **Minimum SDK:** Android 5.0 (API level 21)
- **Target SDK:** 34+
- **Java Version:** 17+

### **General**

- **Node.js:** 16.0+

## **Initial setup**

<Steps>
  <Step title="Installation">
    ```
    npm install react-native-appstack-sdk@1.2.0
    cd ios && pod install  # Only needed for iOS
    ```

    **iOS - Configuring the SKAdNetwork attribution endpoint (optional)**

    Add to `ios/YourApp/Info.plist`:

    ```kotlin
    <key>NSAdvertisingAttributionReportEndpoint</key>
    <string>https://ios-appstack.com/</string>
    ```

    **Android Configuration**

    No additional configuration is needed for Android; the SDK will work automatically after installation.
  </Step>
  <Step title="Quickstart">
    ```javascript
    import { useEffect } from 'react';
    import { Platform } from 'react-native';
    import AppstackSDK from 'react-native-appstack-sdk';
    
    const App = () => {
      useEffect(() => {
        const init = async () => {
          const apiKey = Platform.OS === 'ios' 
            ? process.env.APPSTACK_IOS_API_KEY 
            : process.env.APPSTACK_ANDROID_API_KEY;
          
          await AppstackSDK.configure(apiKey);
          
          // Request tracking permission and enable Appple Ads Attribution
          if (Platform.OS === 'ios') {
            await AppstackSDK.enableAppleAdsAttribution();
          }
        };
        
        init();
      }, []);
    
      const trackPurchase = () => {
        AppstackSDK.sendEvent('PURCHASE', null, { revenue: 29.99, currency: 'USD' });
      };
    
      // ... your app
    };
    ```
  </Step>
  <Step stepNumber={3} title="Configuration parameters">
    Initializes the SDK with your API key. Must be called before any other SDK methods.

    Parameters:

    - `apiKey` - Your platform-specific API key from the Appstack dashboard

    Returns: A promise that resolves to `true` if configuration was successful

    Example:

    ```javascript
    const success = await AppstackSDK.configure('your-api-key-here');
    if (!success) {
      console.error('SDK configuration failed');
    }
    ```
  </Step>
  <Step stepNumber={4} title="Sending events">
    Track user actions and revenue in your activities:

    ```javascript
    // Track events without parameters
    await AppstackSDK.sendEvent('LOGIN');
    await AppstackSDK.sendEvent('SIGN_UP');
    
    // Track events with parameters (including revenue)
    await AppstackSDK.sendEvent(
    	'PURCHASE', null, { revenue: 29.99, currency: 'USD' }
    );
    await AppstackSDK.sendEvent(
    	'SUBSCRIBE', null, { revenue: 9.99, plan: 'monthly' }
    );
    
    // Custom events
    await AppstackSDK.sendEvent(
    	'CUSTOM',
    	'user_attributes',
    	{
    		email: "test@example.com", 
    		name: "John Doe", 
    		phone_number: "+33060000000", 
    		date_of_birth: "2026-02-01" 
    	}
    );
    ```

    **Available EventType values**

    It is recommended to use standard events for a smoother experience.

    - `INSTALL` - App installation (tracked automatically)
    - `LOGIN`, `SIGN_UP`, `REGISTER` - Authentication
    - `PURCHASE`, `ADD_TO_CART`, `ADD_TO_WISHLIST`, `INITIATE_CHECKOUT`, `START_TRIAL`, `SUBSCRIBE` - Monetization
    - `LEVEL_START`, `LEVEL_COMPLETE` - Game progression
    - `TUTORIAL_COMPLETE`, `SEARCH`, `VIEW_ITEM`, `VIEW_CONTENT`, `SHARE` - Engagement
    - `CUSTOM` - For application-specific eventsTracks custom events with optional parameters

    Tracks custom events with optional parameters:

    - `eventType` - Event type from EventType enum or string (e.g., 'PURCHASE', 'LOGIN')
    - `eventName` - Event name for custom events (optional)
    - `parameters` - Optional parameters object (e.g., `{ revenue: 29.99, currency: 'USD' }`)

    Returns: A promise that resolves to `true` if event was sent successfully

    **Enhanced app campaigns**

    <Tip>
      When running enhanced app campaigns (EACs), it is highly recommended to send multiple parameters with the in-app event to improve matching quality.
    </Tip>
    For any event that represents revenue, we recommend sending:

    1. `revenue` or `price` (number)
    2. `currency`(string, e.g. `EUR`, `USD`)

    ```kotlin
    AppStackAttributionSdk.sendEvent(
        EventType.PURCHASE,
        parameters = mapOf("revenue" to 4.99, "currency" to "EUR")
    )
    ```

    To improve matching quality on Meta, send events including the following parameters if you can fulfill them:

    1. `email`
    2. `name` (first + last name in the same field).
    3. `phone_number`
    4. `date_of_birth` (recommended format: `YYYY-MM-DD`).
  </Step>
</Steps>

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

- **iOS:** Requires iOS 13.0+, Apple Ads attribution needs iOS 14.3+
- **Android:** Minimum API level 21 (Android 5.0)
- **React Native:** 0.72.0+
- Some Apple Ads features may not work in development/simulator environments

### **Event tracking**

- Event types are case-sensitive (use uppercase like 'PURCHASE', 'LOGIN')
- Parameters are passed as an object and can include any key-value pairs
- For revenue events, always pass a `revenue` (or `price`) and a `currency` parameter
- The SDK must be initialized before any tracking calls
- Network connectivis ity required for event transmission (events are queued offline)

### **Technical limitations**

- `enableAppleAdsAttribution()` only works on iOS and will do nothing on Android
- For now, iOS endpoint configuration cannot be customized (will be patched in future release)
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
- Check that `NSAdvertisingAttributionReportEndpoint` it is configured in Info.plist
- Allow 24-48 hours for attribution data to appear

## **Support**

For questions or issues:

1. Check the [GitHub Repository](https://github.com/appstack-tech/appstack-android-sdk)
2. Contact our support team at [support@appstack.tech](mailto:support@appstack.tech)
3. Open an issue in the repository