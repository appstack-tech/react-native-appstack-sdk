import { Platform } from 'react-native';
import NativeAppstackReactNative from './NativeAppstackReactNative';
import { EventType } from './types';
import type { AppstackEventParameters, JsonValue } from './types';

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
 * The wire-level category the native SDKs use for anything that is not a standard
 * event type. It is not a value callers ever pass: in the two-argument API you pass
 * your custom event's name directly and the wrapper supplies this category for you.
 */
const CUSTOM_EVENT_CATEGORY = 'CUSTOM';

/**
 * Standard event types the native SDKs record on their own.
 *
 * A manual send is dropped by the wrapper rather than forwarded. iOS already
 * discards these natively, because a hand-sent `INSTALL` inflates install counts.
 * `FIRST_OPEN`, `FIRST_OPEN_GUARDED` and `ASA_ATTRIBUTION` exist only in iOS's enum,
 * so forwarding them would additionally manufacture a bogus *custom* event named
 * "FIRST_OPEN" on Android alone — the exact cross-platform divergence this API removes.
 *
 * `ASA_ATTRIBUTION` was added to iOS's enum in 4.6.0 (via 4.5.2), which emits it
 * automatically once AdServices token resolution completes.
 */
const AUTOMATIC_ONLY_EVENTS: ReadonlySet<string> = new Set([
  'INSTALL',
  'FIRST_OPEN',
  'FIRST_OPEN_GUARDED',
  'ASA_ATTRIBUTION',
]);

/**
 * Every standard type resolvable in JS. This matches Android's native enum exactly;
 * iOS's three extras are all automatic-only and handled above, so nothing real is
 * missing from this set.
 */
const STANDARD_EVENT_TYPES: ReadonlySet<string> = new Set<string>(Object.values(EventType));

/**
 * Drop `null` / `undefined` valued keys and collapse an empty result to `null`.
 *
 * Android filtered these out before handing the map to native
 * (`filterValues { it != null }`) while iOS forwarded `NSNull`, so identical JS
 * produced a different payload per platform. Normalising once here means both
 * platforms observe the same map.
 */
const normalizeParameters = (
  parameters?: AppstackEventParameters | null
): Record<string, JsonValue> | null => {
  if (parameters == null) {
    return null;
  }

  const cleaned: Record<string, JsonValue> = {};
  for (const [key, value] of Object.entries(parameters)) {
    if (value != null) {
      cleaned[key] = value;
    }
  }

  return Object.keys(cleaned).length > 0 ? cleaned : null;
};

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
   * Send a standard or custom event, optionally with parameters.
   * @param event - A standard `EventType` (recommended; its string name also works,
   * case-insensitively), or any other string to send a custom event by that name
   * @param parameters - Optional parameters (e.g. `{ revenue: 29.99, currency: 'USD' }`).
   * Keys valued `null` or `undefined` are stripped
   * @returns Promise that resolves once the call reaches native. It does **not**
   * indicate the event was delivered: the native SDKs also drop events when
   * disabled, offline, or buffering
   */
  sendEvent(event: EventType | string, parameters?: AppstackEventParameters | null): Promise<void>;

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
 * await AppstackSDK.sendEvent(EventType.PURCHASE); // Without parameters
 * await AppstackSDK.sendEvent(EventType.PURCHASE, { revenue: 29.99, currency: 'USD' });
 * await AppstackSDK.sendEvent('user_attributes', { email: 'a@b.com' }); // Custom event
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

    // Number.isInteger, not a bare range check: it rejects NaN and Infinity (typeof NaN
    // is 'number', and both NaN < 0 and NaN > 3 are false) as well as fractions like 1.5,
    // which would otherwise pass and be silently truncated to 1 by the native casts
    // (NSInteger on iOS, Double.toInt() on Android). Only 0-3 are defined log levels.
    if (
      typeof logLevel !== 'number' ||
      !Number.isInteger(logLevel) ||
      logLevel < 0 ||
      logLevel > 3
    ) {
      throw new Error('logLevel must be one of 0, 1, 2, or 3');
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
   * Send a standard or custom event, optionally with parameters
   */
  sendEvent(event: EventType | string, parameters?: AppstackEventParameters | null): Promise<void>;
  // The rest parameter exists only to detect 2.x three-argument calls; it is
  // deliberately absent from the overload above so TypeScript still reports the arity
  // error. It is NOT `arguments.length`: this method is async, and Babel's
  // async-to-generator transform hoists the body into an inner function, so
  // `arguments` is not reliably the caller's argument list once bundled.
  async sendEvent(
    event: EventType | string,
    parameters?: AppstackEventParameters | null,
    ...removedPositionalArgs: unknown[]
  ): Promise<void> {
    if (typeof event !== 'string' || event.trim() === '') {
      throw new Error(
        'event must be a non-empty string: a standard EventType, or your own name for a ' +
          'custom event'
      );
    }

    // 2.x accepted sendEvent(eventType, eventName, parameters). Catch both the extra
    // third argument and a second argument that is not a parameters object, because
    // sendEvent('CUSTOM', 'my_event') was the *documented* way to send a custom event.
    // Silently accepting either would bind the name string to `parameters` and ship an
    // event whose payload is its own name.
    if (
      removedPositionalArgs.length > 0 ||
      (parameters !== undefined &&
        parameters !== null &&
        (typeof parameters !== 'object' || Array.isArray(parameters)))
    ) {
      throw new Error(
        'sendEvent(eventType, eventName, parameters) was removed in 3.0. Use ' +
          'sendEvent(event, parameters) instead: pass a standard EventType for a standard ' +
          'event, or your custom event name directly. ' +
          "e.g. sendEvent(EventType.PURCHASE, { revenue: 4.99, currency: 'EUR' }) or " +
          "sendEvent('user_attributes', { email })."
      );
    }

    const name = event.trim();
    const upperCased = name.toUpperCase();

    // 'CUSTOM' is the wire-level category, never a caller-supplied event. Passing it
    // would resolve as "standard type CUSTOM with no name", which iOS drops outright
    // and Android sends with a null event_name.
    if (upperCased === CUSTOM_EVENT_CATEGORY) {
      throw new Error(
        "'CUSTOM' is not a sendable event. It is the internal category for custom events, " +
          'not a name — pass the name you want to record instead, ' +
          "e.g. sendEvent('user_attributes', { email })."
      );
    }

    // Drop rather than reject. A manual INSTALL has been a silent discard since 2.5.0,
    // so throwing would break callers who send one harmlessly today. This mirrors iOS
    // native behaviour, which ignores these on the manual path.
    if (AUTOMATIC_ONLY_EVENTS.has(upperCased)) {
      console.error(
        `[AppstackSDK] '${name}' is recorded automatically by the SDK and cannot be sent ` +
          'manually; this event was dropped. Remove the call: sending it by hand would ' +
          'double-count installs.'
      );
      return;
    }

    const isStandardEvent = STANDARD_EVENT_TYPES.has(upperCased);

    // The only place a misspelled standard event is catchable. It is a heuristic — it
    // also fires on legitimate custom names like 'user_attributes' — so it stays
    // advisory and dev-only, and never gates the send.
    if (!isStandardEvent && typeof __DEV__ !== 'undefined' && __DEV__) {
      console.warn(
        `[AppstackSDK] '${name}' is not a standard EventType; sending as a custom event ` +
          `named '${name}'. If you meant a standard event, check the spelling: only standard ` +
          'events carry the semantics enhanced app campaigns optimise against.'
      );
    }

    // Always an explicit, unambiguous pair, so neither native wrapper has to resolve
    // anything: a standard type with a null name, or the CUSTOM category with a name.
    // This is what makes the natives' divergent fallback branches unreachable.
    const eventType = isStandardEvent ? upperCased : CUSTOM_EVENT_CATEGORY;
    const eventName = isStandardEvent ? null : name;

    try {
      await AppstackReactNative.sendEvent(eventType, eventName, normalizeParameters(parameters));
    } catch (error) {
      console.error(`Failed to send event '${name}':`, error);
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

// Export the event parameter types so callers can annotate their own payloads
export type { AppstackEventParameters, JsonValue };

// Types are already exported automatically with interfaces
