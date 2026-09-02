// swift-tools-version: 6.0

import PackageDescription

// React Native 0.87 resolves self-managed community packages through
// build/generated/autolinking/libs/<SwiftName>. These paths are therefore
// relative to that stable alias, not to node_modules or this checkout.
let reactNativePackagePath = "../../../../xcframeworks"
let reactGeneratedCodePackagePath = "../../../ios"

let package = Package(
    name: "ReactNativeAppstackSdk",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ReactNativeAppstackSdk",
            targets: ["ReactNativeAppstackSdk"]
        ),
    ],
    dependencies: [
        // Keep this exact version aligned with update-ios-xcframework.sh. The
        // bridge uses AppstackSDK SPI, so an unreviewed native upgrade is unsafe.
        .package(
            url: "https://github.com/appstack-tech/ios-appstack-sdk.git",
            exact: "4.5.0"
        ),
        .package(name: "ReactNative", path: reactNativePackagePath),
        .package(
            name: "React-GeneratedCode",
            path: reactGeneratedCodePackagePath
        ),
    ],
    targets: [
        // SwiftPM cannot compile Swift and Objective-C++ in one target. The
        // dependency is one-way (Objective-C++ calls the Swift bridge), so the
        // CocoaPods target can be represented by these two targets without a
        // circular dependency.
        .target(
            name: "AppstackBridgeSwift",
            dependencies: [
                .product(name: "AppstackSDK", package: "ios-appstack-sdk"),
            ],
            path: ".",
            sources: ["AppstackBridge.swift"]
        ),
        .target(
            name: "ReactNativeAppstackSdk",
            dependencies: [
                "AppstackBridgeSwift",
                .product(name: "ReactHeaders", package: "ReactNative"),
                .product(name: "ReactNativeHeaders", package: "ReactNative"),
                .product(
                    name: "ReactNativeDependenciesHeaders",
                    package: "ReactNative"
                ),
                .product(
                    name: "ReactAppHeaders",
                    package: "React-GeneratedCode"
                ),
            ],
            path: ".",
            sources: ["AppstackReactNative.mm"],
            publicHeadersPath: "include",
            cSettings: [
                .define("RCT_NEW_ARCH_ENABLED", to: "1"),
            ],
            cxxSettings: [
                .define("RCT_NEW_ARCH_ENABLED", to: "1"),
                .define("FOLLY_NO_CONFIG"),
                .define("FOLLY_MOBILE", to: "1"),
                .define("FOLLY_USE_LIBCPP", to: "1"),
                .define("DEBUG", .when(configuration: .debug)),
                .define("NDEBUG", .when(configuration: .release)),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
