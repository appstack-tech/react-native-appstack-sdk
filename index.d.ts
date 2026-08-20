declare module 'react-native-appstack-sdk' {
  export interface AppstackConfigureOptions {
    /** Log level: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR (optional, default 1) */
    logLevel?: number;
    /** Optional customer user ID to associate with the device/session */
    customerUserId?: string | null;
  }

  /** Any value that survives the React Native bridge intact. */
  export type JsonValue =
    | string
    | number
    | boolean
    | null
    | JsonValue[]
    | { [key: string]: JsonValue };

  /**
   * Parameters accepted by `sendEvent`. Keys valued `null` or `undefined` are
   * stripped before the call reaches native.
   */
  export type AppstackEventParameters = Record<string, JsonValue | undefined>;

  export interface AppstackSDKInterface {
    configure(apiKey: string, options?: AppstackConfigureOptions | null): Promise<boolean>;
    setCustomerUserId(customerUserId?: string | null): Promise<void>;
    sendEvent(
      event: EventType | string,
      parameters?: AppstackEventParameters | null
    ): Promise<void>;
    enableAppleAdsAttribution(): Promise<boolean>;
    getAppstackId(): Promise<string>;
    isSdkDisabled(): Promise<boolean>;
  }

  export enum EventType {
    INSTALL = 'INSTALL',
    LOGIN = 'LOGIN',
    SIGN_UP = 'SIGN_UP',
    REGISTER = 'REGISTER',
    PURCHASE = 'PURCHASE',
    ADD_TO_CART = 'ADD_TO_CART',
    ADD_TO_WISHLIST = 'ADD_TO_WISHLIST',
    INITIATE_CHECKOUT = 'INITIATE_CHECKOUT',
    START_TRIAL = 'START_TRIAL',
    SUBSCRIBE = 'SUBSCRIBE',
    LEVEL_START = 'LEVEL_START',
    LEVEL_COMPLETE = 'LEVEL_COMPLETE',
    TUTORIAL_COMPLETE = 'TUTORIAL_COMPLETE',
    SEARCH = 'SEARCH',
    VIEW_ITEM = 'VIEW_ITEM',
    VIEW_CONTENT = 'VIEW_CONTENT',
    SHARE = 'SHARE',
  }

  export interface AppstackEventParams {
    revenue?: number | string;
  }

  export interface AppstackConfig {
    apiKey: string;
    logLevel?: number;
    customerUserId?: string;
  }

  export class AppstackError extends Error {
    code: string;
    originalError?: Error;
    constructor(message: string, code: string, originalError?: Error);
  }

  export enum AppstackErrorCode {
    INVALID_API_KEY = 'INVALID_API_KEY',
    INVALID_EVENT_NAME = 'INVALID_EVENT_NAME',
    INVALID_REVENUE = 'INVALID_REVENUE',
    CONFIGURATION_ERROR = 'CONFIGURATION_ERROR',
    EVENT_SEND_ERROR = 'EVENT_SEND_ERROR',
    ASA_ATTRIBUTION_ERROR = 'ASA_ATTRIBUTION_ERROR',
    UNSUPPORTED_IOS_VERSION = 'UNSUPPORTED_IOS_VERSION',
    PLATFORM_NOT_SUPPORTED = 'PLATFORM_NOT_SUPPORTED',
  }

  export class AppstackSDK implements AppstackSDKInterface {
    static getInstance(): AppstackSDK;
    configure(apiKey: string, options?: AppstackConfigureOptions | null): Promise<boolean>;
    setCustomerUserId(customerUserId?: string | null): Promise<void>;
    sendEvent(
      event: EventType | string,
      parameters?: AppstackEventParameters | null
    ): Promise<void>;
    enableAppleAdsAttribution(): Promise<boolean>;
    getAppstackId(): Promise<string>;
    isSdkDisabled(): Promise<boolean>;
  }

  const appstackSDK: AppstackSDK;
  export default appstackSDK;
}
