/**
 * @jest-environment node
 */

const fs = require('fs');
const path = require('path');

const repositoryRoot = path.resolve(__dirname, '..');
const packageManifest = fs.readFileSync(path.join(repositoryRoot, 'ios', 'Package.swift'), 'utf8');
const xcframeworkUpdater = fs.readFileSync(
  path.join(repositoryRoot, 'update-ios-xcframework.sh'),
  'utf8'
);

describe('iOS Swift Package Manager manifest', () => {
  it('resolves the public native package at the CocoaPods-vendored version', () => {
    const nativeVersion = xcframeworkUpdater.match(/^VERSION="([^"]+)"$/m)?.[1];

    expect(nativeVersion).toBeDefined();
    expect(packageManifest).toContain(
      'url: "https://github.com/appstack-tech/ios-appstack-sdk.git"'
    );
    expect(packageManifest).toContain(`exact: "${nativeVersion}"`);
    expect(packageManifest).toContain('.product(name: "AppstackSDK", package: "ios-appstack-sdk")');
    expect(packageManifest).not.toContain('.binaryTarget(');
  });

  it('keeps Swift and Objective-C++ in separate targets', () => {
    expect(packageManifest).toContain('name: "AppstackBridgeSwift"');
    expect(packageManifest).toContain('sources: ["AppstackBridge.swift"]');
    expect(packageManifest).toContain('name: "ReactNativeAppstackSdk"');
    expect(packageManifest).toContain('sources: ["AppstackReactNative.mm"]');
    expect(packageManifest).toContain('"AppstackBridgeSwift",');
  });

  it('uses the React Native 0.87 self-managed package contract', () => {
    expect(packageManifest).toContain('let reactNativePackagePath = "../../../../xcframeworks"');
    expect(packageManifest).toContain('let reactGeneratedCodePackagePath = "../../../ios"');
    expect(packageManifest).toMatch(
      /\.product\(\s*name: "ReactNativeDependenciesHeaders",\s*package: "ReactNative"\s*\)/
    );
    expect(packageManifest).toMatch(
      /\.product\(\s*name: "ReactAppHeaders",\s*package: "React-GeneratedCode"\s*\)/
    );
    expect(packageManifest).toContain('.define("RCT_NEW_ARCH_ENABLED", to: "1")');
  });
});
