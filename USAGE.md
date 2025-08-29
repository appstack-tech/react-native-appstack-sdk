# React Native Appstack SDK - Usage Guide

This guide provides detailed instructions and examples for using the React Native Appstack SDK to track events, revenue, and enable Apple Search Ads attribution in your mobile apps.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Event Tracking](#event-tracking)
- [Apple Search Ads Attribution](#apple-search-ads-attribution)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Quick Start

```typescript
import React, { useEffect } from 'react';
import AppstackSDK from 'react-native-appstack-sdk';

const App = () => {
  useEffect(() => {
    // Initialize SDK
    const initializeAppstack = async () => {
      try {
        await AppstackSDK.configure('your-api-key');
        await AppstackSDK.enableAppleAdsAttribution();
        console.log('Appstack SDK ready!');
      } catch (error) {
        console.error('SDK initialization failed:', error);
      }
    };
    
    initializeAppstack();
  }, []);

  const trackPurchase = async () => {
    try {
      await AppstackSDK.sendEvent('purchase', 29.99);
      console.log('Purchase tracked successfully');
    } catch (error) {
      console.error('Failed to track purchase:', error);
    }
  };

  // ... rest of your app
};
```

## Installation

### 1. Install the Package

```bash
# Using npm
npm install react-native-appstack-sdk

# Using yarn
yarn add react-native-appstack-sdk
```

### 2. iOS Setup

```bash
cd ios && pod install
```

### 3. Configure Info.plist

Add this to your `ios/YourApp/Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://ios-appstack.com/</string>
```

## Configuration

### Basic Configuration

The SDK must be configured with your API key before any other operations:

```typescript
import AppstackSDK from 'react-native-appstack-sdk';

const configureSDK = async () => {
  try {
    const success = await AppstackSDK.configure('your-api-key-here');
    if (success) {
      console.log('SDK configured successfully');
    }
  } catch (error) {
    console.error('Configuration failed:', error);
  }
};
```

### Configuration in App Component

```typescript
import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';
import AppstackSDK from 'react-native-appstack-sdk';

const App = () => {
  const [sdkReady, setSdkReady] = useState(false);

  useEffect(() => {
    const initializeAppstack = async () => {
      try {
        // Configure the SDK
        await AppstackSDK.configure('your-api-key');
        
        // Enable Apple Search Ads Attribution (iOS only)
        if (Platform.OS === 'ios') {
          await AppstackSDK.enableAppleAdsAttribution();
        }
        
        setSdkReady(true);
        console.log('Appstack SDK initialized successfully');
      } catch (error) {
        console.error('Failed to initialize Appstack SDK:', error);
      }
    };

    initializeAppstack();
  }, []);

  return (
    <View>
      <Text>SDK Status: {sdkReady ? 'Ready' : 'Loading...'}</Text>
    </View>
  );
};
```

## Event Tracking

### Basic Events

Track simple events without revenue:

```typescript
// User registration
await AppstackSDK.sendEvent('user_registered');

// Level completion
await AppstackSDK.sendEvent('level_completed');

// Tutorial finished
await AppstackSDK.sendEvent('tutorial_finished');

// App opened
await AppstackSDK.sendEvent('app_opened');
```

### Events with Revenue

Track events that generate revenue:

```typescript
// In-app purchase
await AppstackSDK.sendEvent('purchase', 4.99);

// Subscription
await AppstackSDK.sendEvent('subscription', 9.99);

// Premium upgrade
await AppstackSDK.sendEvent('upgrade_premium', 19.99);

// Revenue as string (automatically converted to number)
await AppstackSDK.sendEvent('donation', '2.99');
```

### E-commerce Event Examples

```typescript
const EcommerceExample = () => {
  const trackProductView = async (productId: string) => {
    await AppstackSDK.sendEvent(`product_view_${productId}`);
  };

  const trackAddToCart = async (productId: string, price: number) => {
    await AppstackSDK.sendEvent(`add_to_cart_${productId}`, price);
  };

  const trackPurchase = async (orderId: string, totalValue: number) => {
    await AppstackSDK.sendEvent(`purchase_${orderId}`, totalValue);
  };

  const trackRefund = async (orderId: string, refundAmount: number) => {
    await AppstackSDK.sendEvent(`refund_${orderId}`, -refundAmount);
  };

  return (
    // Your component JSX
  );
};
```

### Gaming Event Examples

```typescript
const GamingExample = () => {
  const trackLevelStart = async (level: number) => {
    await AppstackSDK.sendEvent(`level_${level}_start`);
  };

  const trackLevelComplete = async (level: number, score: number) => {
    await AppstackSDK.sendEvent(`level_${level}_complete`);
    // Track high scores as revenue-like events
    if (score > 1000) {
      await AppstackSDK.sendEvent('high_score_achieved', score / 100);
    }
  };

  const trackInAppPurchase = async (itemId: string, price: number) => {
    await AppstackSDK.sendEvent(`iap_${itemId}`, price);
  };

  const trackAdWatched = async () => {
    await AppstackSDK.sendEvent('ad_watched');
  };

  return (
    // Your component JSX
  );
};
```

## Apple Search Ads Attribution

### Enable Attribution Tracking

Apple Search Ads Attribution helps track app installs that came from Apple Search Ads:

```typescript
import { Platform } from 'react-native';

const enableAttribution = async () => {
  // Only available on iOS
  if (Platform.OS === 'ios') {
    try {
      const success = await AppstackSDK.enableAppleAdsAttribution();
      if (success) {
        console.log('Apple Ads Attribution enabled successfully');
      } else {
        console.log('Apple Ads Attribution not available on this device');
      }
    } catch (error) {
      console.error('Failed to enable Apple Ads Attribution:', error);
    }
  } else {
    console.log('Apple Ads Attribution is iOS only');
  }
};
```

### Attribution Best Practices

```typescript
const AppWithAttribution = () => {
  useEffect(() => {
    const setupAttribution = async () => {
      try {
        // Configure SDK first
        await AppstackSDK.configure('your-api-key');
        
        // Enable attribution on iOS
        if (Platform.OS === 'ios') {
          await AppstackSDK.enableAppleAdsAttribution();
        }
        
        // Send app launch event after attribution is set up
        await AppstackSDK.sendEvent('app_launch');
        
      } catch (error) {
        console.error('Attribution setup failed:', error);
      }
    };

    setupAttribution();
  }, []);
  
  // ... rest of component
};
```

## Error Handling

### Basic Error Handling

```typescript
const handleEventWithErrorHandling = async (eventName: string, revenue?: number) => {
  try {
    await AppstackSDK.sendEvent(eventName, revenue);
    console.log(`Event "${eventName}" sent successfully`);
  } catch (error) {
    console.error(`Failed to send event "${eventName}":`, error);
    
    // Handle different types of errors
    if (error.message.includes('API key')) {
      console.error('Invalid API key - please check your configuration');
    } else if (error.message.includes('Event name')) {
      console.error('Invalid event name provided');
    } else if (error.message.includes('Revenue')) {
      console.error('Invalid revenue value provided');
    }
  }
};
```

### Advanced Error Handling with Custom Types

```typescript
import { AppstackError, AppstackErrorCode } from 'react-native-appstack-sdk';

const advancedErrorHandling = async () => {
  try {
    await AppstackSDK.configure('invalid-key');
  } catch (error) {
    if (error instanceof AppstackError) {
      switch (error.code) {
        case AppstackErrorCode.INVALID_API_KEY:
          console.error('Please provide a valid API key');
          break;
        case AppstackErrorCode.CONFIGURATION_ERROR:
          console.error('SDK configuration failed');
          break;
        case AppstackErrorCode.EVENT_SEND_ERROR:
          console.error('Failed to send event');
          break;
        case AppstackErrorCode.ASA_ATTRIBUTION_ERROR:
          console.error('Apple Search Ads Attribution error');
          break;
        default:
          console.error('Unknown error:', error.message);
      }
    } else {
      console.error('Unexpected error:', error);
    }
  }
};
```

### Retry Logic for Failed Events

```typescript
const sendEventWithRetry = async (eventName: string, revenue?: number, maxRetries = 3) => {
  let attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      await AppstackSDK.sendEvent(eventName, revenue);
      console.log(`Event "${eventName}" sent successfully`);
      return; // Success, exit retry loop
    } catch (error) {
      attempts++;
      console.warn(`Attempt ${attempts} failed for event "${eventName}":`, error);
      
      if (attempts >= maxRetries) {
        console.error(`All ${maxRetries} attempts failed for event "${eventName}"`);
        throw error; // Re-throw after max retries
      }
      
      // Wait before retrying (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempts) * 1000));
    }
  }
};
```

## Best Practices

### 1. SDK Initialization

```typescript
// ✅ Good: Initialize in App component
const App = () => {
  useEffect(() => {
    AppstackSDK.configure('your-api-key');
  }, []);
  
  // ... rest of app
};

// ❌ Avoid: Initializing in every component
const SomeComponent = () => {
  useEffect(() => {
    AppstackSDK.configure('your-api-key'); // Don't do this
  }, []);
};
```

### 2. Event Naming Conventions

```typescript
// ✅ Good: Descriptive, consistent naming
await AppstackSDK.sendEvent('user_registration_completed');
await AppstackSDK.sendEvent('purchase_premium_plan');
await AppstackSDK.sendEvent('level_5_completed');

// ❌ Avoid: Generic or inconsistent names
await AppstackSDK.sendEvent('event1');
await AppstackSDK.sendEvent('stuff_happened');
await AppstackSDK.sendEvent('LevelComplete'); // Inconsistent casing
```

### 3. Revenue Tracking

```typescript
// ✅ Good: Always use proper decimal values
await AppstackSDK.sendEvent('purchase', 29.99);
await AppstackSDK.sendEvent('subscription', 9.99);

// ✅ Good: Handle dynamic pricing
const trackPurchase = async (productId: string, price: number) => {
  await AppstackSDK.sendEvent(`purchase_${productId}`, price);
};

// ❌ Avoid: Inconsistent revenue units
await AppstackSDK.sendEvent('purchase', 2999); // Cents? Dollars?
```

### 4. Platform-Specific Features

```typescript
import { Platform } from 'react-native';

// ✅ Good: Check platform before iOS-specific features
const enableIOSFeatures = async () => {
  if (Platform.OS === 'ios') {
    await AppstackSDK.enableAppleAdsAttribution();
  }
};

// ✅ Good: Graceful degradation for Android
const trackEvent = async (eventName: string, revenue?: number) => {
  if (Platform.OS === 'ios') {
    await AppstackSDK.sendEvent(eventName, revenue);
  } else {
    console.log(`Event "${eventName}" would be tracked on iOS`);
    // Potentially use other analytics for Android
  }
};
```

## Advanced Usage

### Custom Hook for SDK Management

```typescript
import { useState, useEffect } from 'react';
import AppstackSDK from 'react-native-appstack-sdk';

const useAppstackSDK = (apiKey: string) => {
  const [isInitialized, setIsInitialized] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const initialize = async () => {
      try {
        await AppstackSDK.configure(apiKey);
        await AppstackSDK.enableAppleAdsAttribution();
        setIsInitialized(true);
      } catch (err) {
        setError(err as Error);
      }
    };

    initialize();
  }, [apiKey]);

  const trackEvent = async (eventName: string, revenue?: number) => {
    if (!isInitialized) {
      console.warn('SDK not initialized yet');
      return false;
    }

    try {
      return await AppstackSDK.sendEvent(eventName, revenue);
    } catch (err) {
      console.error('Failed to track event:', err);
      return false;
    }
  };

  return { isInitialized, error, trackEvent };
};

// Usage
const App = () => {
  const { isInitialized, error, trackEvent } = useAppstackSDK('your-api-key');

  const handlePurchase = () => {
    trackEvent('purchase', 29.99);
  };

  if (error) {
    return <Text>SDK Error: {error.message}</Text>;
  }

  return (
    <View>
      <Text>SDK Status: {isInitialized ? 'Ready' : 'Loading...'}</Text>
      <Button title="Track Purchase" onPress={handlePurchase} />
    </View>
  );
};
```

### Context Provider for SDK

```typescript
import React, { createContext, useContext, useEffect, useState } from 'react';

interface AppstackContextType {
  isReady: boolean;
  trackEvent: (eventName: string, revenue?: number) => Promise<boolean>;
}

const AppstackContext = createContext<AppstackContextType | null>(null);

export const AppstackProvider: React.FC<{ apiKey: string; children: React.ReactNode }> = ({ 
  apiKey, 
  children 
}) => {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    const initializeSDK = async () => {
      try {
        await AppstackSDK.configure(apiKey);
        await AppstackSDK.enableAppleAdsAttribution();
        setIsReady(true);
      } catch (error) {
        console.error('Failed to initialize Appstack SDK:', error);
      }
    };

    initializeSDK();
  }, [apiKey]);

  const trackEvent = async (eventName: string, revenue?: number): Promise<boolean> => {
    if (!isReady) {
      console.warn('Appstack SDK not ready yet');
      return false;
    }

    try {
      return await AppstackSDK.sendEvent(eventName, revenue);
    } catch (error) {
      console.error('Failed to track event:', error);
      return false;
    }
  };

  return (
    <AppstackContext.Provider value={{ isReady, trackEvent }}>
      {children}
    </AppstackContext.Provider>
  );
};

export const useAppstack = () => {
  const context = useContext(AppstackContext);
  if (!context) {
    throw new Error('useAppstack must be used within an AppstackProvider');
  }
  return context;
};

// Usage
const App = () => (
  <AppstackProvider apiKey="your-api-key">
    <MainApp />
  </AppstackProvider>
);

const MainApp = () => {
  const { isReady, trackEvent } = useAppstack();

  return (
    <View>
      <Button 
        title="Track Event" 
        onPress={() => trackEvent('button_click')}
        disabled={!isReady}
      />
    </View>
  );
};
```

## Troubleshooting

### Common Issues

#### 1. "Package doesn't seem to be linked"

**Error:**
```
The package 'react-native-appstack-sdk' doesn't seem to be linked
```

**Solution:**
```bash
# Run pod install
cd ios && pod install

# Clean and rebuild
cd .. && npx react-native clean
npx react-native run-ios
```

#### 2. SDK not initializing

**Issue:** Events not being tracked

**Solutions:**
```typescript
// Check if configure was called
const checkSDKStatus = async () => {
  try {
    // Try sending a test event
    await AppstackSDK.sendEvent('test_event');
    console.log('SDK is working');
  } catch (error) {
    console.error('SDK not configured:', error);
    // Re-initialize
    await AppstackSDK.configure('your-api-key');
  }
};
```

#### 3. Apple Search Ads not working

**Issue:** Attribution data not appearing

**Checklist:**
- iOS 14.3+ required
- Info.plist correctly configured
- App downloaded from App Store or TestFlight
- May take 24-48 hours to appear in dashboard

#### 4. Revenue values not tracking correctly

**Issue:** Revenue showing as 0 or incorrect

**Solutions:**
```typescript
// ✅ Correct: Use decimal numbers
await AppstackSDK.sendEvent('purchase', 29.99);

// ✅ Correct: Convert cents to dollars
const priceInCents = 2999;
await AppstackSDK.sendEvent('purchase', priceInCents / 100);

// ❌ Wrong: Don't pass cents as dollars
await AppstackSDK.sendEvent('purchase', 2999); // This would be $2,999!
```

### Debug Mode

While the SDK doesn't have a built-in debug mode, you can create your own:

```typescript
const DEBUG_MODE = __DEV__;

const debugTrackEvent = async (eventName: string, revenue?: number) => {
  if (DEBUG_MODE) {
    console.log(`[Appstack Debug] Tracking event: ${eventName}`, { revenue });
  }
  
  try {
    const result = await AppstackSDK.sendEvent(eventName, revenue);
    if (DEBUG_MODE) {
      console.log(`[Appstack Debug] Event sent successfully: ${eventName}`);
    }
    return result;
  } catch (error) {
    if (DEBUG_MODE) {
      console.error(`[Appstack Debug] Failed to send event: ${eventName}`, error);
    }
    throw error;
  }
};
```

### Testing

```typescript
// Test SDK integration in development
const testSDKIntegration = async () => {
  if (!__DEV__) return; // Only run in development

  console.log('Testing Appstack SDK integration...');
  
  try {
    // Test configuration
    await AppstackSDK.configure('test-api-key');
    console.log('✅ SDK configured successfully');
    
    // Test basic event
    await AppstackSDK.sendEvent('test_event');
    console.log('✅ Basic event sent successfully');
    
    // Test event with revenue
    await AppstackSDK.sendEvent('test_purchase', 9.99);
    console.log('✅ Revenue event sent successfully');
    
    // Test Apple Ads Attribution
    if (Platform.OS === 'ios') {
      await AppstackSDK.enableAppleAdsAttribution();
      console.log('✅ Apple Ads Attribution enabled');
    }
    
    console.log('🎉 All tests passed!');
  } catch (error) {
    console.error('❌ SDK test failed:', error);
  }
};
```

## Conclusion

The React Native Appstack SDK provides a simple yet powerful way to track events and revenue in your mobile apps while maintaining Apple Search Ads attribution. By following the patterns and best practices outlined in this guide, you'll be able to effectively integrate analytics into your React Native application.

Remember to:
- Initialize the SDK early in your app lifecycle
- Use consistent event naming conventions
- Handle errors gracefully
- Test your integration thoroughly
- Follow platform-specific guidelines for iOS features

For additional support, refer to the [GitHub repository](https://github.com/appstack-tech/react-native-appstack-sdk) or contact support.
