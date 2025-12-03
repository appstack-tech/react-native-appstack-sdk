require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "react-native-appstack-sdk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/your-org/react-native-appstack-sdk.git", :tag => "#{s.version}" }

  s.source_files = "ios/*.{h,m,mm,swift}"
  s.public_header_files = "ios/AppstackBridge.h"
  s.swift_version = '5.0'
  
  # Include Appstack XCFramework (supports all architectures)
  s.ios.vendored_frameworks = "ios/AppstackSDK.xcframework"
  
  # Ensure Swift module is properly configured
  s.module_name = "react_native_appstack_sdk"
  
  # Additional Swift configuration
  s.requires_arc = true
  
  # React Native configuration
  s.dependency "React-Core"

  # Don't install the dependencies when we run `pod install` in the old architecture.
  if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
    s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
    s.pod_target_xcconfig = {
        'DEFINES_MODULE' => 'YES',
        'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'react_native_appstack_sdk-Swift.h',
        'SWIFT_OBJC_BRIDGING_HEADER' => '',
        'SWIFT_OPTIMIZATION_LEVEL' => '-Onone',
        "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
        "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
        "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
        'IPHONEOS_DEPLOYMENT_TARGET' => '15.0'
    }
    s.dependency "React-Codegen"
    # RCT-Folly dependency for new architecture support
    # Note: RCT-Folly may not be available in all CocoaPods environments
    # For React Native 0.81.4, this dependency is causing build issues
    # TODO: Re-enable when RCT-Folly is available in CocoaPods trunk for RN 0.81.4
    # s.dependency "RCT-Folly"
    s.dependency "RCTRequired"
    s.dependency "RCTTypeSafety"
    s.dependency "ReactCommon/turbomodule/core"
  else
  # Base Swift configuration for proper bridging header generation
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'react_native_appstack_sdk-Swift.h',
    'SWIFT_OBJC_BRIDGING_HEADER' => '',
    'SWIFT_OPTIMIZATION_LEVEL' => '-Onone',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CLANG_ENABLE_MODULE_DEBUGGING' => 'YES',
    'SWIFT_INSTALL_OBJC_HEADER' => 'YES',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0'
  }
  end
end