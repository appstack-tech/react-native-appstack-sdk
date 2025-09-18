/**
 * Standard attribution events supported by the SDK.
 * 
 * The enum values follow the widely adopted SNAKE_CASE notation used by
 * mobile measurement partners (MMPs). The raw value sent over the wire is the
 * enum name itself (e.g. `EventType.ADD_TO_CART` → "ADD_TO_CART").
 * 
 * For events that have synonymous names (e.g. SIGN_UP/REGISTER), both variants
 * are provided to maximise compatibility with existing integrations.
 */
export enum EventType {
  // MARK: - Lifecycle
  /** User installs the app (tracked automatically by the SDK). */
  INSTALL = 'INSTALL',
  
  // MARK: - Authentication & account
  /** User logs in to an existing account. */
  LOGIN = 'LOGIN',
  /** User signs up for a new account. */
  SIGN_UP = 'SIGN_UP',
  /** Alias for SIGN_UP – kept for compatibility with some MMPs. */
  REGISTER = 'REGISTER',
  
  // MARK: - Monetisation
  /** User completes a purchase (often includes revenue & currency). */
  PURCHASE = 'PURCHASE',
  /** Item added to the shopping cart. */
  ADD_TO_CART = 'ADD_TO_CART',
  /** Item added to the wishlist. */
  ADD_TO_WISHLIST = 'ADD_TO_WISHLIST',
  /** Checkout process started. */
  INITIATE_CHECKOUT = 'INITIATE_CHECKOUT',
  /** User starts a free trial. */
  START_TRIAL = 'START_TRIAL',
  /** User subscribes to a paid plan. */
  SUBSCRIBE = 'SUBSCRIBE',
  
  // MARK: - Games / progression
  /** User starts a new level (games). */
  LEVEL_START = 'LEVEL_START',
  /** User completes a level (games). */
  LEVEL_COMPLETE = 'LEVEL_COMPLETE',
  
  // MARK: - Engagement
  /** User completes the onboarding tutorial. */
  TUTORIAL_COMPLETE = 'TUTORIAL_COMPLETE',
  /** User performs a search in the app. */
  SEARCH = 'SEARCH',
  /** User views a specific product or item. */
  VIEW_ITEM = 'VIEW_ITEM',
  /** User views generic content (e.g. article, post). */
  VIEW_CONTENT = 'VIEW_CONTENT',
  /** User shares content from the app. */
  SHARE = 'SHARE',
  
  // MARK: - Catch-all
  /** Custom application-specific event not covered above. */
  CUSTOM = 'CUSTOM',
}

/**
 * Available parameters for Appstack events
 */
export interface AppstackEventParams {
  /**
   * Revenue value associated with the event
   * Can be number or string convertible to number
   */
  revenue?: number;
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
  isDebug?: boolean;
  
  /**
   * Custom endpoint base URL (optional)
   */
  endpointBaseUrl?: string;
  
  /**
   * Log level (optional, default 1 - INFO)
   * 0 = DEBUG, 1 = INFO, 2 = WARN, 3 = ERROR
   */
  logLevel?: number;
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