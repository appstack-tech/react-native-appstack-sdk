#ifdef RCT_NEW_ARCH_ENABLED
// RNAppstackSdkSpec is codegenConfig.name from package.json; the protocol name
// NativeAppstackReactNativeSpec is derived from the spec filename
// (src/NativeAppstackReactNative.ts). This header is generated into the app's
// codegen output and is reachable because the podspec depends on ReactCodegen.
#import <RNAppstackSdkSpec/RNAppstackSdkSpec.h>
#else
#import <React/RCTBridgeModule.h>
#endif

// Deliberately NOT listed in the podspec's public_header_files: under
// `use_frameworks!` public headers are added to the generated umbrella header,
// and the codegen import above does not exist on the legacy architecture.
@interface AppstackReactNative : NSObject <
#ifdef RCT_NEW_ARCH_ENABLED
                                    NativeAppstackReactNativeSpec
#else
                                    RCTBridgeModule
#endif
                                    >

@end
