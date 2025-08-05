/**
 * Available parameters for Appstack events
 */
export interface AppstackEventParams {
  /**
   * Revenue value associated with the event
   * Can be number or string convertible to number
   */
  revenue?: number | string;
}

/**
 * Appstack SDK configuration
 */
export interface AppstackConfig {
  /**
   * API Key obtained from Appstack dashboard
   */
  apiKey: string;
  
  /**
   * Enable debug logs (optional, default false)
   */
  enableDebugMode?: boolean;
}

/**
 * Appstack SDK specific errors
 */
export class AppstackError extends Error {
  constructor(
    message: string,
    public code: string,
    public originalError?: Error
  ) {
    super(message);
    this.name = 'AppstackError';
  }
}

/**
 * SDK error codes
 */
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