require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

# `install_modules_dependencies` is a top-level DSL method defined in
# react-native/scripts/react_native_pods.rb, which the app's Podfile has already
# required by the time CocoaPods resolves this podspec. It is NOT defined when the
# podspec is evaluated standalone (`pod ipc spec`, some autolinking probes), so
# require it on demand. Note `respond_to?` would be the wrong guard here: this is
# not a method on Pod::Spec. Mirrors node_modules/expo-modules-core/ExpoModulesCore.podspec.
unless defined?(install_modules_dependencies)
  react_native_path = if ENV['REACT_NATIVE_PATH']
    File.expand_path(ENV['REACT_NATIVE_PATH'], Pod::Config.instance.project_root)
  else
    File.dirname(`node --print "require.resolve('react-native/package.json')"`)
  end
  require File.join(react_native_path, "scripts/react_native_pods")
end

Pod::Spec.new do |s|
  s.name         = "react-native-appstack-sdk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/your-org/react-native-appstack-sdk.git", :tag => "#{s.version}" }

  # Single-level glob on purpose: ios/ also holds the vendored xcframework, whose
  # headers must not be compiled as library sources.
  s.source_files = "ios/*.{h,m,mm,swift}"

  # AppstackReactNative.h must stay PRIVATE. Under `use_frameworks!` CocoaPods puts
  # only public headers into the generated umbrella header, and that header imports
  # the codegen spec header, which does not exist on the legacy architecture.
  s.public_header_files = "ios/AppstackBridge.h"

  # Must match Swift 6 so the vendored AppstackSDK.xcframework API is visible (see pod_target_xcconfig comment).
  s.swift_version = '6.0'

  # Include Appstack XCFramework (supports all architectures)
  s.ios.vendored_frameworks = "ios/AppstackSDK.xcframework"

  # Ensure Swift module is properly configured
  s.module_name = "react_native_appstack_sdk"

  # Additional Swift configuration
  s.requires_arc = true

  # `compiler_flags` and `pod_target_xcconfig` MUST be assigned before
  # install_modules_dependencies(s) below: that helper reads both out of
  # spec.to_hash, merges its own values in, and REASSIGNS them. Anything set after
  # the call is silently discarded, including -DRCT_NEW_ARCH_ENABLED=1 and the
  # codegen header search paths.
  s.compiler_flags = folly_compiler_flags

  # SWIFT_VERSION 6 required: the vendored AppstackSDK.xcframework was built with Swift 6
  # and exposes configure/sendEvent/getAppstackId/getAttributionParams only when the compiler
  # has $NonescapableTypes (Swift 6). Without this, clients see "has no member 'configure'" etc.
  #
  # The React-Core public/private HEADER_SEARCH_PATHS fix "'React/RCTBridgeModule.h' file not
  # found" on React Native 0.83+ (added in 2.1.0). install_modules_dependencies appends to this
  # key rather than replacing it, so both architectures now get the fix; before the TurboModule
  # migration it was only applied on the legacy branch.
  #
  # -Werror=protocol / -Werror=incomplete-implementation: a missing or mistyped selector on a
  # codegen protocol is only a warning by default, which turns a build-time mistake into a
  # runtime "unrecognized selector". Promote those to errors for this pod.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'react_native_appstack_sdk-Swift.h',
    'SWIFT_OBJC_BRIDGING_HEADER' => '',
    'SWIFT_OPTIMIZATION_LEVEL' => '-Onone',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CLANG_ENABLE_MODULE_DEBUGGING' => 'YES',
    'SWIFT_INSTALL_OBJC_HEADER' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/Headers/Public/React-Core" "$(PODS_ROOT)/Headers/Private/React-Core"',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1',
    'OTHER_CFLAGS' => '$(inherited) -Werror=protocol -Werror=incomplete-implementation',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'SWIFT_VERSION' => '6.0',
    'SWIFT_STRICT_CONCURRENCY' => 'minimal'
  }

  # ENV['RCT_NEW_ARCH_ENABLED'] is always explicitly '1' or '0' by the time podspecs are
  # resolved: use_react_native! sets it, seeded from ios/Podfile.properties.json's
  # newArchEnabled. The '0' check (rather than a '1' check) matches React Native's own
  # default, which treats anything but '0' as the new architecture.
  if ENV['RCT_NEW_ARCH_ENABLED'] == '0'
    # Legacy architecture (Expo SDK 54 and earlier): keep the dependency graph exactly as it
    # was before the TurboModule migration. Nothing defines RCT_NEW_ARCH_ENABLED here, so
    # AppstackReactNative.h/.mm compile their RCTBridgeModule branch.
    s.dependency "React-Core"
  else
    # Adds React-Core, ReactCodegen, RCTRequired, RCTTypeSafety, ReactCommon/turbomodule/*,
    # React-NativeModulesApple, the Fabric pods and the JS engine, and defines
    # -DRCT_NEW_ARCH_ENABLED=1. The ReactCodegen dependency is what puts
    # "$(PODS_ROOT)/Headers/Public/ReactCodegen" on our HEADER_SEARCH_PATHS, which is how
    # `#import <RNAppstackSdkSpec/RNAppstackSdkSpec.h>` resolves — and, under
    # `useFrameworks: static`, it also adds the per-framework Headers paths that cannot be
    # reproduced by hand-listing dependencies.
    install_modules_dependencies(s)
  end
end
