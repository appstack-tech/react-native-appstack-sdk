import { NativeModules, Platform } from 'react-native';
import { EventType } from './types';

// Lazy evaluation of LINKING_ERROR to avoid calling Platform.select during module initialization
const getLinkingError = () => {
  return `The package 'react-native-appstack-sdk' doesn't seem to be linked. Make sure: \n\n` +
    Platform.select({ ios: "- You have run 'cd ios && pod install'\n", default: '' }) +
    '- You rebuilt the app after installing the package\n' +
    '- You are not using Expo Go\n';
};

const AppstackReactNative = NativeModules.AppstackReactNative
  ? NativeModules.AppstackReactNative
  : new Proxy(
      {} as any,
      {
        get() {
          throw new Error(getLinkingError());
        },
      }
    ) as any;

export interface AppstackSDKInterface {
  /**
   * Configure Appstack SDK with your API key and optional parameters
   * @param apiKey - Your Appstack API key obtained from the dashboard
   * @param isDebug - Enable debug mode (optional, default false)
   * @param endpointBaseUrl - Custom endpoint base URL (optional)
   * @param logLevel - Log level: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR (optional, default 1)
   * @returns Promise that resolves when configuration is successful
   */
  configure(apiKey: string, isDebug?: boolean, endpointBaseUrl?: string, logLevel?: number): Promise<boolean>;

  /**
   * Send an event with optional parameters
   * @param eventName - Event name (must match those configured in Appstack dashboard) - for backward compatibility
   * @param eventType - Event type from EventType enum (preferred method)
   * @param parameters - Optional parameters object (e.g., { revenue: 29.99, currency: 'USD' })
   * @returns Promise that resolves when the event is sent successfully
   */
  sendEvent(eventType?: EventType | string, eventName?: string, parameters?: Record<string, any>): Promise<boolean>;

  /**
   * Enable Apple Search Ads Attribution tracking
   * Requires iOS 15.0+
   * @returns Promise that resolves when configuration is successful
   * @deprecated Use enableAppleAdsAttribution() instead
   */
  enableAppleAdsAttribution(): Promise<boolean>;

  /**
   * Get the Appstack ID for the current user/device
   * @returns Promise that resolves with the Appstack ID string
   */
  getAppstackId(): Promise<string>;

  /**
   * Check if the SDK is disabled
   * @returns Promise that resolves to true if the SDK is disabled, false otherwise
   */
  isSdkDisabled(): Promise<boolean>;
}

/**
 * Main Appstack SDK class for React Native
 * 
 * Usage example:
 * ```typescript
 * import AppstackSDK from 'react-native-appstack-sdk';
 * 
 * // Configure the SDK (basic)
 * await AppstackSDK.configure('your-api-key');
 * 
 * // Configure the SDK (with all parameters)
 * await AppstackSDK.configure(
 *   'your-api-key',
 *   true, // isDebug
 *   'https://api.event.dev.appstack.tech/android/', // endpointBaseUrl
 *   0 // logLevel (DEBUG)
 * );
 * 
 * // Send events
 * await AppstackSDK.sendEvent('PURCHASE'); // Without parameters
 * await AppstackSDK.sendEvent('PURCHASE', null, { revenue: 29.99, currency: 'USD' }); // With parameters
 * 
 * // Enable Apple Ads Attribution (iOS only)
 * if (Platform.OS === 'ios') {
 *   await AppstackSDK.enableAppleAdsAttribution();
 * }
 * ```
 */
class AppstackSDK implements AppstackSDKInterface {
  private static instance: AppstackSDK;

  private constructor() {}

  /**
   * Get the singleton instance of the SDK
   */
  public static getInstance(): AppstackSDK {
    if (!AppstackSDK.instance) {
      AppstackSDK.instance = new AppstackSDK();
    }
    return AppstackSDK.instance;
  }

  /**
   * Configure Appstack SDK with your API key and optional parameters
   */
  async configure(apiKey: string, isDebug: boolean = false, endpointBaseUrl?: string, logLevel: number = 1): Promise<boolean> {
    if (!apiKey || typeof apiKey !== 'string' || apiKey.trim() === '') {
      throw new Error('API key must be a non-empty string');
    }

    if (typeof isDebug !== 'boolean') {
      throw new Error('isDebug must be a boolean');
    }

    if (endpointBaseUrl !== undefined && (typeof endpointBaseUrl !== 'string' || endpointBaseUrl.trim() === '')) {
      throw new Error('endpointBaseUrl must be a non-empty string or undefined');
    }

    if (typeof logLevel !== 'number' || logLevel < 0 || logLevel > 3) {
      throw new Error('logLevel must be a number between 0 and 3');
    }

    try {
      const result = await AppstackReactNative.configure(
        apiKey.trim(), 
        isDebug, 
        endpointBaseUrl?.trim() || null, 
        logLevel
      );
      return result;
    } catch (error) {
      console.error('Failed to configure Appstack SDK:', error);
      throw error;
    }
  }

  /**
   * Send an event with optional parameters
   */
  async sendEvent(eventType?: EventType | string, eventName?: string, parameters?: Record<string, any>): Promise<boolean> {
    // Validate that at least one of eventName or eventType is provided
    if ((!eventName || eventName.trim() === '') && (!eventType || eventType.toString().trim() === '')) {
      throw new Error('Either eventName or eventType must be provided');
    }

    try {
      // Convert eventType to string if it's an enum
      const eventTypeString = eventType ? eventType.toString() : null;
      
      return await AppstackReactNative.sendEvent(
        eventTypeString?.trim() || null, 
        eventName?.trim() || null, 
        parameters || null
      );
    } catch (error) {
      console.error(`Failed to send event (eventType: '${eventType}', eventName: '${eventName}'):`, error);
      throw error;
    }
  }
  /**
   * Enable Apple Ads Attribution tracking
   */
  async enableAppleAdsAttribution(): Promise<boolean> {
    if (Platform.OS !== 'ios') {
      console.warn('Apple Ads Attribution is only available on iOS');
      return false;
    }

    try {
      return await AppstackReactNative.enableAppleAdsAttribution();
    } catch (error) {
      console.error('Failed to enable Apple Ads Attribution:', error);
      throw error;
    }
  }

  /**
   * Get the Appstack ID for the current user/device
   */
  async getAppstackId(): Promise<string> {
    try {
      return await AppstackReactNative.getAppstackId();
    } catch (error) {
      console.error('Failed to get Appstack ID:', error);
      throw error;
    }
  }

  /**
   * Check if the SDK is disabled
   */
  async isSdkDisabled(): Promise<boolean> {
    try {
      const isDisabled = await AppstackReactNative.isSdkDisabled();
      if (isDisabled) {
        console.warn('⚠️ Appstack SDK is currently disabled. All SDK operations will be skipped. Please check your API key and try again.');
      }
      return isDisabled;
    } catch (error) {
      console.error('Failed to check if SDK is disabled:', error);
      throw error;
    }
  }
}

// Export the singleton instance
const appstackSDK = AppstackSDK.getInstance();

export default appstackSDK;

// Also export the class for advanced use cases
export { AppstackSDK };

// Export the EventType enum
export { EventType };

// Types are already exported automatically with interfaces