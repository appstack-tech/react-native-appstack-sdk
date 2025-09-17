# Changelog

All notable changes to the React Native Appstack SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
