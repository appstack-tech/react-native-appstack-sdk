import { Platform } from 'react-native';
import NativeAppstackReactNative from './NativeAppstackReactNative';
import { EventType } from './types';

// Lazy evaluation of LINKING_ERROR to avoid calling Platform.select during module initialization
const getLinkingError = () => {
  return (
    `The package 'react-native-appstack-sdk' doesn't seem to be linked. Make sure: \n\n` +
    Platform.select({ ios: "- You have run 'cd ios && pod install'\n", default: '' }) +
    '- You rebuilt the app after installing the package\n' +
    '- You are not using Expo Go\n'
  );
};

// Resolved through TurboModuleRegistry so the same call site works on the new
// architecture (real TurboModule) and the legacy one (NativeModules entry).
const AppstackReactNative = NativeAppstackReactNative
  ? (NativeAppstackReactNative as any)
  : (new Proxy({} as any, {
      get() {
        throw new Error(getLinkingError());
      },
    }) as any);

/**
 * Options accepted by the recommended `configure(apiKey, options)` form.
 */
export interface AppstackConfigureOptions {
  /** Log level: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR (optional, default 1) */
  logLevel?: number;
  /** Optional customer user ID to associate with the device/session */
  customerUserId?: string | null;
}

export interface AppstackSDKInterface {
  /**
   * Configure Appstack SDK with your API key and optional parameters
   * @param apiKey - Your Appstack API key obtained from the dashboard
   * @param options - Optional configuration: `logLevel` and `customerUserId`
   * @returns Promise that resolves when configuration is successful
   */
  configure(apiKey: string, options?: AppstackConfigureOptions | null): Promise<boolean>;

  /**
   * Set — or clear — the customer user ID after configure(), e.g. once a login reveals it.
   * A repeat configure() is a no-op, so it cannot be used to change the ID.
   * @param customerUserId - Your identifier for the signed-in user; `null`/`undefined`/`''` clears it (do this on logout)
   * @returns Promise that resolves once native has stored (or cleared) the ID
   */
  setCustomerUserId(customerUserId?: string | null): Promise<void>;

  /**
   * Send an event with optional parameters
   * @param eventName - Event name (must match those configured in Appstack dashboard) - for backward compatibility
   * @param eventType - Event type from EventType enum (preferred method)
   * @param parameters - Optional parameters object (e.g., { revenue: 29.99, currency: 'USD' })
   * @returns Promise that resolves when the event is sent successfully
   */
  sendEvent(
    eventType?: EventType | string,
    eventName?: string,
    parameters?: Record<string, any>
  ): Promise<boolean>;

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

  /**
   * Get attribution parameters from the SDK
   * @returns Promise that resolves with the attribution parameters object
   */
  getAttributionParams(): Promise<Record<string, any>>;
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
 * // Configure the SDK (with options)
 * await AppstackSDK.configure('your-api-key', {
 *   logLevel: 0, // 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
 *   customerUserId: 'user-123', // optional
 * });
 *
 * // Set the customer user ID later (e.g. on login), or clear it on logout
 * await AppstackSDK.setCustomerUserId('user-123');
 * await AppstackSDK.setCustomerUserId(null);
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
   * @param apiKey - Your Appstack API key obtained from the dashboard
   * @param options - Optional configuration: `logLevel` and `customerUserId`
   */
  configure(apiKey: string, options?: AppstackConfigureOptions | null): Promise<boolean>;
  // The rest parameter exists only to detect 2.x positional calls; it is deliberately
  // absent from the overload above so TypeScript still reports the arity error. It is
  // NOT `arguments.length`: this method is async, and Babel's async-to-generator
  // transform hoists the body into an inner function, so `arguments` is not reliably
  // the caller's argument list once bundled.
  async configure(
    apiKey: string,
    options?: AppstackConfigureOptions | null,
    ...removedPositionalArgs: unknown[]
  ): Promise<boolean> {
    if (!apiKey || typeof apiKey !== 'string' || apiKey.trim() === '') {
      throw new Error('API key must be a non-empty string');
    }

    // 2.x accepted configure(apiKey, isDebug, endpointBaseUrl, logLevel, customerUserId).
    // Detect that by argument count, not by inspecting the second argument: isDebug was
    // almost always `false` and endpointBaseUrl almost always `undefined`, so their values
    // carry no signal. Silently ignoring the call would drop the logLevel and
    // customerUserId that trail them, which for an attribution SDK means events going out
    // with no customer user ID and nothing logged. `null` is tolerated as "no options".
    if (
      removedPositionalArgs.length > 0 ||
      (options !== undefined && options !== null && typeof options !== 'object')
    ) {
      throw new Error(
        'configure(apiKey, isDebug, endpointBaseUrl, logLevel, customerUserId) was removed in 3.0. ' +
          'Use configure(apiKey, { logLevel, customerUserId }) instead; isDebug and ' +
          'endpointBaseUrl are gone and were never forwarded to the native SDKs.'
      );
    }

    const logLevel = options?.logLevel === undefined ? 1 : options.logLevel;
    const customerUserId = options?.customerUserId;

    // Number.isFinite also rejects NaN, which would otherwise pass: typeof NaN is
    // 'number' and both NaN < 0 and NaN > 3 are false.
    if (
      typeof logLevel !== 'number' ||
      !Number.isFinite(logLevel) ||
      logLevel < 0 ||
      logLevel > 3
    ) {
      throw new Error('logLevel must be a number between 0 and 3');
    }

    if (
      customerUserId !== undefined &&
      customerUserId !== null &&
      (typeof customerUserId !== 'string' || customerUserId.trim() === '')
    ) {
      throw new Error('customerUserId must be a non-empty string, null, or undefined');
    }

    try {
      return await AppstackReactNative.configure(
        apiKey.trim(),
        logLevel,
        customerUserId != null ? customerUserId.trim() || null : null
      );
    } catch (error) {
      console.error('Failed to configure Appstack SDK:', error);
      throw error;
    }
  }

  /**
   * Set — or clear — the customer user ID after the SDK has been configured
   */
  async setCustomerUserId(customerUserId?: string | null): Promise<void> {
    if (
      customerUserId !== undefined &&
      customerUserId !== null &&
      typeof customerUserId !== 'string'
    ) {
      throw new Error('customerUserId must be a string, null, or undefined');
    }

    // Not configure()'s validation: a blank value here is a legitimate clear, so
    // null/undefined/'' normalize to an explicit null the native setter reads as such.
    const normalized = typeof customerUserId === 'string' ? customerUserId.trim() || null : null;

    try {
      await AppstackReactNative.setCustomerUserId(normalized);
    } catch (error) {
      console.error('Failed to set Appstack customer user ID:', error);
      throw error;
    }
  }

  /**
   * Send an event with optional parameters
   */
  async sendEvent(
    eventType?: EventType | string,
    eventName?: string,
    parameters?: Record<string, any>
  ): Promise<boolean> {
    // Validate that at least one of eventName or eventType is provided
    if (
      (!eventName || eventName.trim() === '') &&
      (!eventType || eventType.toString().trim() === '')
    ) {
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
      console.error(
        `Failed to send event (eventType: '${eventType}', eventName: '${eventName}'):`,
        error
      );
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
        console.warn(
          '⚠️ Appstack SDK is currently disabled. All SDK operations will be skipped. Please check your API key and try again.'
        );
      }
      return isDisabled;
    } catch (error) {
      console.error('Failed to check if SDK is disabled:', error);
      throw error;
    }
  }

  /**
   * Get attribution parameters from the SDK
   */
  async getAttributionParams(): Promise<Record<string, any>> {
    try {
      return await AppstackReactNative.getAttributionParams();
    } catch (error) {
      console.error('Failed to get attribution parameters:', error);
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
