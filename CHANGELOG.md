# Changelog

All notable changes to the React Native Appstack SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-01-02

### Added
- **Rollback some buggy features coming from 3.2.0 (upgrade iOS to 3.3.0)**

## [1.3.0] - 2026-01-02

### Added
- **New securities on iOS (upgrade to 3.2.0)**


## [1.2.0] - 2025-12-15

### Added
- **New matching method on Android (upgrade to 1.2.2)**
- **New securities on iOS (upgrade to 3.1.1)**

## [1.1.3] - 2025-12-09

### Added
- **Automatic data flushing on Android**
  - Android SDK now automatically flushes data when the app goes to background (`onHostPause`)
  - Data is also flushed when the app is destroyed (`onHostDestroy`)
  - Implements lifecycle listeners to detect app state changes
  - Matches the behavior of the native Android SDK
  - iOS continues to send data live, so no changes needed for iOS

## [1.1.2] - 2025-12-08

### Fixed
- **fix android build setup, worked**

## [1.1.1] - 2025-12-08

### Fixed
- **Tried to fix android build setup, didn't work**

## [1.1.0] - 2025-12-08

### Added
- **New `getAttributionParams()` method** across all platforms
  - Retrieve attribution parameters from both iOS and Android SDKs
  - Returns a Promise that resolves with an object containing all available attribution data
  - Fully typed with TypeScript support
  - Complete implementation across TypeScript, Objective-C, Swift, and Kotlin layers
  
### Changed
- **Updated iOS bridge files**
  - Added method declaration in `AppstackBridge.h`
  - Added static method implementation in `AppstackBridge.swift`
  - Added Objective-C export method in `AppstackReactNative.mm`
  
- **Updated Android bridge files**
  - Added `@ReactMethod` for `getAttributionParams()` with proper type conversion from Kotlin Map to React Native WritableMap
  - Supports String, Int, Double, Boolean, Long, and null value types
  
- **Updated TypeScript/JavaScript layer**
  - Added method to `AppstackSDKInterface`
  - Added implementation to main `AppstackSDK` class with error handling
  - Added method signature to TurboModule spec

### Updated
- **Homepage app**
  - Added UI section to display attribution parameters with styled visualization
  - Added "Get Attribution Params" button (purple color, #5856D6)
  - Displays retrieved parameters in a clean, readable format with key-value pairs
  - Shows alert with JSON formatted parameters on retrieval
  - Includes error handling and user feedback

## [1.0.4] - 2025-12-04

### Fixed
- **Complete Swift compatibility fix for EAS Build and standard iOS environments**
  - Updated Appstack SDK to version without experimental Swift feature dependencies
  - Removed conditional compilation guards from `AppstackBridge.swift`
  - Cleaned up EAS Build configuration by removing experimental Swift flags
  - SDK now works in all iOS build environments without requiring `$NonescapableTypes` feature flag
- **Fixed EventType enum compatibility**
  - Replaced `EventType(rawValue:)` initializer with `allCases.first` approach
  - Ensures compatibility across different Swift compiler versions

### Changed
- **Simplified iOS bridge implementation**
  - Removed all conditional compilation directives
  - Direct method calls to SDK without feature guards
- **Cleaned up build configuration**
  - Removed experimental Swift compiler flags from `eas.json`
  - Standard iOS build compatibility restored

## [1.0.3] - 2025-12-03

### Fixed
- **Fix iOS deployment target mismatch causing compilation errors**
  - Updated podspec to specify iOS 15.0 minimum deployment target to match AppstackSDK framework requirements
  - Previous iOS 13.0 specification caused compiler to strip SDK methods on conditional compilation directives
  - This was causing "missing member 'sendEvent', 'getAppstackId'" errors during pod install

## [1.0.2] - 2025-11-26

- **Fix a compatibility bug with older Swift version on iOS for sendEvent**

## [1.0.1] - 2025-11-14

- **Fix a bug of compilation on the android bridge**


## [1.0.0] - 2025-11-14

- **Update Appstack iOS SDK to version 3.0.0**
- **Update Appstack Android SDK to version 1.0.0 (from 0.0.15)**
- **BREAKING CHANGE: `sendEvent` method now accepts `parameters` object instead of `revenue` parameter**
  - Old: `sendEvent(eventType, eventName, revenue)`
  - New: `sendEvent(eventType, eventName, parameters)` where parameters can include `{ revenue: 29.99, currency: 'USD', ... }`
- **CRITICAL FIX: Fixed iOS and Android bridges to correctly pass `null` for name parameter on non-CUSTOM event types**
  - This was preventing events from being sent to the endpoint
  - Now matches the working Flutter SDK implementation
- **CRITICAL FIX: Fixed iOS Objective-C bridge to properly handle NSNull when parameters is null**
  - React Native converts JavaScript `null` to `NSNull`, which needs to be converted to `nil` for Swift
  - This was causing "JSON value '<null>' of type NSNull cannot be converted to NSDictionary" errors
- **Android: Removed `InitListener` requirement from `configure` method (simplified initialization)**
- **iOS: Updated bridge to support new SDK parameter-based event tracking**
- **Major SDK dependency updates for improved stability and performance**

## [0.0.22] - 2025-11-06

- **Add a isSdkDisabled() method to know if the SDK is disabled in one of the bridges**
- **Appstack iOS SDK new dependency: 2.6.3**
- **Appstack Android SDK new dependency: 0.0.15**

## [0.0.21] - 2025-10-29

- **Patch the getAppstackId() method to retrieve the install ID of a user without errors**

## [0.0.20] - 2025-10-29

- **DEPRECATED**
- **Patch the getAppstackId() method to retrieve the install ID of a user without errors**

## [0.0.19] - 2025-10-29

- **DEPRECATED**
- **Add the IDFA retrieval on iOS**
- **Add a getAppstackId() method to retrieve the install ID of a user**

## [0.0.18] - 2025-10-17

- **Update the documentation to remove useless warning, no modifications of code in this release**

## [0.0.17] - 2025-10-16

- **Update iOS SDK to 2.5.0 (using the new iOS SDK automatic release publication on public repo)**

## [0.0.16] - 2025-09-26

- **Update the podspec to support newArchBuild**
- **Update Android SDK version to 0.0.12**

## [0.0.15] - 2025-09-26

- **Make the React Native SDK supports 16KB pages without needing any modifications on app's side**
- **Update iOS SDK (still flagged as 2.2.0)**

## [0.0.14] - 2025-09-26

- **Release the probabilistic matching attribution on iOS (update iOS SDK version to 2.2.0)**

## [0.0.13] - 2025-09-23

- **Update the iOS bridge configuration to ensure that every command eas build works correctly**
- **Previously testing only with "npm run ios"**
- **now eas build --platform ios works too**

## [0.0.12] - 2025-09-22

## Changed
- **Update to last version the dependecy to android SDK**

## [0.0.11] - 2025-09-19

## Changed
- **Modified the regex defined in `react-native-appstack-sdk.podspec`**

## [0.0.10] - 2025-09-18

### Changed
- **BREAKING**: Switched `sendEvent` parameter order to `(eventType, eventName, revenue)` for better developer experience
- **BREAKING**: Updated all platform implementations (iOS, Android, TypeScript) to use new parameter order
- **BREAKING**: Updated all documentation and examples to reflect new parameter order

### Added
- **Enhanced Event Handling**: Improved event name resolution logic for better consistency
  - Non-CUSTOM event types now use the eventType value as the event name automatically
  - CUSTOM event types require an explicit eventName parameter (validation added)
- **Better Error Messages**: More descriptive error messages for invalid event configurations
- **Platform Consistency**: Unified behavior across iOS and Android platforms

### Fixed
- **Null Value Elimination**: Developers can now call `sendEvent(EventType.PURCHASE)` without needing null values
- **Event Name Resolution**: Fixed inconsistent event name handling between different event types
- **Validation Logic**: Added proper validation for CUSTOM event types requiring event names

### Migration Guide
```typescript
// OLD (0.0.9 and earlier)
await AppstackSDK.sendEvent(null, EventType.PURCHASE, 29.99);
await AppstackSDK.sendEvent('user_registration');

// NEW (0.0.10+)
await AppstackSDK.sendEvent(EventType.PURCHASE, null, 29.99);
await AppstackSDK.sendEvent(EventType.CUSTOM, 'user_registration');
```

## [0.0.9] - 2025-09-18

## Changed
- Tried to fix the SDK non-null values problem

## [0.0.8] - 2025-09-18

## Changed
- Tried to fix the SDK non-null values problem

## [0.0.7] - 2025-09-18

## Changed
- Tried to fix the SDK non-null values problem

## [0.0.6] - 2025-09-18

## Changed
- Tried to fix the SDK non-null values problem

## [0.0.5] - 2025-09-18

## Changed
- Updated the infrastructure of the SDK and the bridges to match the new methods signatures.

## [0.0.4] - 2025-09-18

## Changed
- Updated the version of the iOS SDK bridge.

## [0.0.3] - 2025-09-17

## Changed
- Change the version of the appstack-android-sdk from 0.0.2 to 0.0.9

## [0.0.2] - 2025-08-27

### Changed
- Removed mavenLocal references from Android build.gradle files to improve build consistency and avoid local dependency issues
- Streamlined Android build configuration for better compatibility across different development environments

### Fixed
- Resolved Android build issues related to local Maven repository dependencies

---

## [0.0.1] - 2025-08-27

### Added

#### Core SDK Features
- **SDK Configuration**: Initialize the SDK with your Appstack API key using `configure(apiKey: string)`
- **Event Tracking**: Send custom events with `sendEvent(eventName: string)` for user actions and app interactions
- **Revenue Tracking**: Track monetary events with `sendEvent(eventName: string, revenue: number | string)` supporting both number and string formats
- **Apple Search Ads Attribution**: Enable Apple Search Ads attribution tracking with `enableAppleAdsAttribution()` for iOS apps

#### iOS Platform Support
- **iOS 13.0+ Compatibility**: Full support for iOS 13.0 and above
- **SKAdNetwork Integration**: Built-in support for Apple's SKAdNetwork framework for privacy-compliant attribution
- **Apple Search Ads Attribution**: Track app installs from Apple Search Ads (requires iOS 14.3+)
- **CocoaPods Integration**: Seamless installation via CocoaPods with `pod install`

#### React Native Integration
- **TypeScript Support**: Full TypeScript definitions included for type-safe development
- **React Native 0.60+ Support**: Compatible with React Native 0.60 and newer versions using auto-linking
- **TurboModule Architecture**: Built on React Native's TurboModule system for optimal performance
- **Cross-platform API**: Consistent JavaScript API across iOS (with Android returning warnings)

#### Error Handling & Validation
- **Input Validation**: Automatic validation of API keys, event names, and revenue values
- **Custom Error Types**: Dedicated `AppstackError` class with specific error codes for different failure scenarios
- **Error Codes**: Comprehensive error code system including:
  - `INVALID_API_KEY`: Invalid or empty API key provided
  - `INVALID_EVENT_NAME`: Invalid or empty event name
  - `INVALID_REVENUE`: Invalid revenue value (NaN, etc.)
  - `CONFIGURATION_ERROR`: SDK configuration failures
  - `EVENT_SEND_ERROR`: Event transmission failures
  - `ASA_ATTRIBUTION_ERROR`: Apple Search Ads attribution errors
  - `UNSUPPORTED_IOS_VERSION`: iOS version compatibility issues
  - `PLATFORM_NOT_SUPPORTED`: Platform-specific feature usage on unsupported platforms

#### Developer Experience
- **Singleton Pattern**: Thread-safe singleton implementation for consistent SDK state management
- **Promise-based API**: Modern async/await support with Promise-based method signatures
- **Comprehensive Documentation**: Detailed inline documentation with JSDoc comments
- **Usage Examples**: Built-in code examples in the main SDK class documentation
- **Auto-linking Support**: Automatic native module linking for React Native 0.60+

#### SDK Architecture
- **Native iOS Framework**: Integration with AppstackSDK.xcframework for iOS functionality
- **React Native Bridge**: Efficient communication between JavaScript and native code
- **Event Queue Management**: Reliable event delivery with proper error handling and retry logic
- **Revenue Processing**: Automatic conversion and validation of revenue values from strings to numbers

#### Configuration Features
- **API Key Management**: Secure API key storage and validation
- **Platform Detection**: Automatic iOS platform detection with graceful Android degradation
- **Initialization Validation**: Proper SDK lifecycle management with initialization checks
- **Attribution Endpoint Configuration**: Support for custom attribution endpoints via Info.plist

#### Build System & Distribution
- **TypeScript Build Pipeline**: Automated TypeScript compilation with source maps
- **Multiple Output Formats**: CommonJS, ES Module, and TypeScript definition outputs
- **NPM Package**: Ready for distribution via NPM registry
- **React Native Builder Bob**: Professional build tooling for consistent package generation
- **Code Generation**: TurboModule spec generation for optimal native performance

### Platform Notes
- **iOS Only**: This initial release supports iOS only. Android methods show console warnings and return `false`
- **Minimum Requirements**: iOS 13.0+, React Native 0.60+, Node.js 16+, Xcode 14.0+
- **Attribution Requirements**: Apple Search Ads Attribution requires iOS 14.3+ and proper Info.plist configuration

### Technical Implementation
- **Memory Management**: Efficient memory usage with singleton pattern and proper cleanup
- **Thread Safety**: Main thread execution for native operations with async JavaScript API
- **Performance Optimized**: Minimal overhead with TurboModule architecture
- **Privacy Compliant**: Designed to work with Apple's privacy framework and ATT requirements
