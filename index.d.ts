declare module 'react-native-appstack-sdk' {
  export interface AppstackSDKInterface {
    configure(apiKey: string): Promise<boolean>;
    sendEvent(eventName: string, revenue: number | string): Promise<boolean>;
    enableAppleAdsAttribution(): Promise<boolean>;
  }

  export interface AppstackEventParams {
    revenue?: number | string;
  }

  export interface AppstackConfig {
    apiKey: string;
    enableDebugMode?: boolean;
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
    configure(apiKey: string): Promise<boolean>;
    sendEvent(eventName: string, revenue?: number | string): Promise<boolean>;
    enableAppleAdsAttribution(): Promise<boolean>;
  }

  const appstackSDK: AppstackSDK;
  export default appstackSDK;
}