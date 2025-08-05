// @ts-ignore
import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-appstack-sdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'cd ios && pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const AppstackReactNative = NativeModules.AppstackReactNative
  ? NativeModules.AppstackReactNative
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export interface AppstackSDKInterface {
  /**
   * Configure Appstack SDK with your API key
   * @param apiKey - Your Appstack API key obtained from the dashboard
   * @returns Promise that resolves when configuration is successful
   */
  configure(apiKey: string): Promise<boolean>;

  /**
   * Send a basic event without parameters
   * @param eventName - Event name (must match those configured in Appstack dashboard)
   * @returns Promise that resolves when the event is sent successfully
   */
  sendEvent(eventName: string): Promise<boolean>;

  /**
   * Send an event with revenue parameter
   * @param eventName - Event name
   * @param revenue - Revenue value (can be number or string)
   * @returns Promise that resolves when the event is sent successfully
   */
  sendEventWithRevenue(eventName: string, revenue: number | string): Promise<boolean>;

  /**
   * Enable Apple Search Ads Attribution tracking
   * Requires iOS 14.3+
   * @returns Promise that resolves when configuration is successful
   */
  enableASAAttribution(): Promise<boolean>;


}

/**
 * Main Appstack SDK class for React Native
 * 
 * Usage example:
 * ```typescript
 * import AppstackSDK from 'react-native-appstack-sdk';
 * 
 * // Configure the SDK
 * await AppstackSDK.configure('your-api-key');
 * 
 * // Send events
 * await AppstackSDK.sendEvent('user_registered');
 * await AppstackSDK.sendEventWithRevenue('purchase', 29.99);
 * 
 * // Enable Apple Search Ads Attribution
 * await AppstackSDK.enableASAAttribution();
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
   * Configure Appstack SDK with your API key
   */
  async configure(apiKey: string): Promise<boolean> {
    if (!apiKey || typeof apiKey !== 'string' || apiKey.trim() === '') {
      throw new Error('API key must be a non-empty string');
    }

    if (Platform.OS !== 'ios') {
      console.warn('Appstack SDK is currently only supported on iOS');
      return false;
    }

    try {
      const result = await AppstackReactNative.configure(apiKey.trim());
      return result;
    } catch (error) {
      console.error('Failed to configure Appstack SDK:', error);
      throw error;
    }
  }

  /**
   * Send a basic event without parameters
   */
  async sendEvent(eventName: string): Promise<boolean> {
    if (!eventName || typeof eventName !== 'string' || eventName.trim() === '') {
      throw new Error('Event name must be a non-empty string');
    }

    if (Platform.OS !== 'ios') {
      console.warn('Appstack SDK is currently only supported on iOS');
      return false;
    }

    try {
      return await AppstackReactNative.sendEvent(eventName.trim());
    } catch (error) {
      console.error(`Failed to send event '${eventName}':`, error);
      throw error;
    }
  }

  /**
   * Send an event with revenue parameter
   */
  async sendEventWithRevenue(eventName: string, revenue: number | string): Promise<boolean> {
    if (!eventName || typeof eventName !== 'string' || eventName.trim() === '') {
      throw new Error('Event name must be a non-empty string');
    }

    if (revenue === null || revenue === undefined) {
      throw new Error('Revenue must be provided');
    }

    // Validate that revenue is a valid number or string convertible to number
    const numericRevenue = typeof revenue === 'string' ? parseFloat(revenue) : revenue;
    if (isNaN(numericRevenue)) {
      throw new Error('Revenue must be a valid number or numeric string');
    }

    if (Platform.OS !== 'ios') {
      console.warn('Appstack SDK is currently only supported on iOS');
      return false;
    }

    try {
      return await AppstackReactNative.sendEventWithRevenue(eventName.trim(), revenue);
    } catch (error) {
      console.error(`Failed to send event '${eventName}' with revenue '${revenue}':`, error);
      throw error;
    }
  }

  /**
   * Enable Apple Search Ads Attribution tracking
   */
  async enableASAAttribution(): Promise<boolean> {
    if (Platform.OS !== 'ios') {
      console.warn('Apple Search Ads Attribution is only available on iOS');
      return false;
    }

    try {
      return await AppstackReactNative.enableASAAttribution();
    } catch (error) {
      console.error('Failed to enable ASA Attribution:', error);
      throw error;
    }
  }


}

// Export the singleton instance
const appstackSDK = AppstackSDK.getInstance();

export default appstackSDK;

// Also export the class for advanced use cases
export { AppstackSDK };

// Types are already exported automatically with interfaces