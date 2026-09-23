<p align="center">
  <a href="https://www.appstack.tech">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://docs.appstack.tech/images/appstack_logo_white_wordmark.png">
      <img alt="Appstack" src="https://docs.appstack.tech/images/appstack_logo_black_wordmark.png" width="280">
    </picture>
  </a>
</p>

<p align="center">
  Mobile attribution and ad-network optimization for React Native apps.
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/react-native-appstack-sdk"><img alt="npm" src="https://img.shields.io/npm/v/react-native-appstack-sdk.svg"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%2015%2B%20%7C%20Android%205.0%2B-blue.svg">
  <a href="https://github.com/appstack-tech/react-native-appstack-sdk/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-lightgrey.svg"></a>
</p>

<p align="center">
  <a href="https://docs.appstack.tech/SDKs/react-native"><b>Documentation</b></a>
  &nbsp;·&nbsp;
  <a href="https://docs.appstack.tech/reference/react-native">API reference</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/appstack-tech/react-native-appstack-sdk/blob/main/CHANGELOG.md">Changelog</a>
  &nbsp;·&nbsp;
  <a href="https://www.appstack.tech/contact">Support</a>
</p>

---

The Appstack React Native SDK tracks installs and in-app events, attributes them to your ad campaigns, and sends conversions back to Meta, Google, TikTok, Apple Ads and other networks. It wraps the native Appstack iOS and Android SDKs.

## Installation

```sh
npm install react-native-appstack-sdk
cd ios && pod install  # CocoaPods apps only
```

Swift Package Manager (React Native 0.87+) and Android setup are covered in the [documentation](https://docs.appstack.tech/SDKs/react-native).

## Quick start

```javascript
import { Platform } from 'react-native';
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

await AppstackSDK.configure(Platform.OS === 'ios' ? 'your_ios_api_key' : 'your_android_api_key');

AppstackSDK.sendEvent(EventType.PURCHASE, { revenue: 29.99, currency: 'USD' });
```

Setup, event types, Apple Ads attribution, integrations (RevenueCat, Superwall) and troubleshooting are covered in the **[official documentation](https://docs.appstack.tech/SDKs/react-native)**.

## Documentation

- **[React Native SDK guide](https://docs.appstack.tech/SDKs/react-native)**: installation, configuration and event tracking
- **[API reference](https://docs.appstack.tech/reference/react-native)**: every public method and type
- **[Apple Ads](https://docs.appstack.tech/Integrations/apple-ads)**: Apple Ads attribution setup
- **[RevenueCat](https://docs.appstack.tech/Integrations/revenuecat)** and **[Superwall](https://docs.appstack.tech/Integrations/superwall)**: subscription platform integrations
- **[Changelog](https://github.com/appstack-tech/react-native-appstack-sdk/blob/main/CHANGELOG.md)**: release notes for every version

## Other platforms

[iOS](https://docs.appstack.tech/SDKs/swift) · [Android](https://docs.appstack.tech/SDKs/kotlin) · [Flutter](https://docs.appstack.tech/SDKs/flutter) · [Unity](https://docs.appstack.tech/SDKs/unity)

## Support

Questions or issues? [Open an issue](https://github.com/appstack-tech/react-native-appstack-sdk/issues) or [contact us](https://www.appstack.tech/contact).

## License

Released under the [MIT License](https://github.com/appstack-tech/react-native-appstack-sdk/blob/main/LICENSE).
