#import "AppstackReactNative.h"
#import "AppstackBridge.h"

// Method bodies below are architecture-agnostic. The promise parameters are named
// `resolve:` / `reject:` because that is what React Native's codegen emits for a
// `Promise<T>` return; on the legacy architecture RCT_EXPORT_METHOD derives the JS
// method name from the first selector component only, so the names are free.
@implementation AppstackReactNative

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

#pragma mark - SDK Configuration

RCT_EXPORT_METHOD(configure:(NSString *)apiKey
                 logLevel:(double)logLevel
                 customerUserId:(NSString * _Nullable)customerUserId
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    if (!apiKey || [apiKey length] == 0) {
        reject(@"INVALID_API_KEY", @"API key cannot be null or empty", nil);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // The codegen spec types logLevel as `double`; AppstackBridge takes NSInteger.
            [AppstackBridge configureWithApiKey:apiKey
                                      logLevel:(NSInteger)logLevel
                                customerUserId:customerUserId];

            resolve(@(YES));
        } @catch (NSException *exception) {
            reject(@"CONFIGURATION_ERROR", exception.reason, nil);
        }
    });
}

// A nil/blank customerUserId is an explicit clear here, so it is forwarded as-is.
RCT_EXPORT_METHOD(setCustomerUserId:(NSString * _Nullable)customerUserId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [AppstackBridge setCustomerUserId:customerUserId];

        resolve(nil);
    } @catch (NSException *exception) {
        reject(@"SET_CUSTOMER_USER_ID_ERROR", exception.reason, nil);
    }
}

#pragma mark - Event Tracking

RCT_EXPORT_METHOD(sendEvent:(NSString * _Nullable)eventType
                 eventName:(NSString * _Nullable)eventName
                 parameters:(NSDictionary * _Nullable)parameters
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    // At least one of eventName or eventType should be provided
    if ((!eventName || [eventName length] == 0) && (!eventType || [eventType length] == 0)) {
        reject(@"INVALID_EVENT_NAME", @"Either eventName or eventType must be provided", nil);
        return;
    }

    // If eventType is CUSTOM, eventName is required
    if (eventType && [eventType length] > 0 && [eventType.uppercaseString isEqualToString:@"CUSTOM"]) {
        if (!eventName || [eventName length] == 0) {
            reject(@"INVALID_EVENT_NAME", @"eventName is required when eventType is CUSTOM", nil);
            return;
        }
    }

    @try {
        // Convert parameters: handle NSNull by converting to nil.
        // Non-dictionary parameters are ignored.
        NSDictionary *parametersDict = nil;
        if (parameters != nil && (id)parameters != [NSNull null]) {
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                parametersDict = parameters;
            }
        }

        // Call the Swift bridge method directly with parameters
        [AppstackBridge sendEvent:eventType eventName:eventName parameters:parametersDict];

        resolve(@(YES));
    } @catch (NSException *exception) {
        reject(@"EVENT_SEND_ERROR", exception.reason, nil);
    }
}

#pragma mark - Apple Search Ads Attribution

RCT_EXPORT_METHOD(enableAppleAdsAttribution:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 15.0, *)) {
        @try {
            // Call the Swift bridge method directly
            [AppstackBridge enableAppleAdsAttribution];

            resolve(@(YES));
        } @catch (NSException *exception) {
            reject(@"ASA_ATTRIBUTION_ERROR", exception.reason, nil);
        }
    } else {
        reject(@"UNSUPPORTED_IOS_VERSION", @"Apple Ads Attribution requires iOS 15.0 or later", nil);
    }
}

#pragma mark - Additional SDK Methods

RCT_EXPORT_METHOD(disableASAAttributionTracking:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 15.0, *)) {
        @try {
            // Call the Swift bridge method directly
            [AppstackBridge disableASAAttributionTracking];

            resolve(@(YES));
        } @catch (NSException *exception) {
            reject(@"ASA_DISABLE_ERROR", exception.reason, nil);
        }
    } else {
        reject(@"UNSUPPORTED_IOS_VERSION", @"Apple Ads Attribution requires iOS 15.0 or later", nil);
    }
}

RCT_EXPORT_METHOD(clearData:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    // Not wired on iOS: the native framework exposes an async `deleteUserData()`,
    // which needs a completion-handler shim in AppstackBridge. Resolves false to
    // signal "unsupported on this platform", the same convention Android uses for
    // enableAppleAdsAttribution.
    resolve(@(NO));
}

RCT_EXPORT_METHOD(isEnabled:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        // iOS exposes the inverse of this: the SDK is enabled unless it is disabled.
        BOOL isDisabled = [AppstackBridge isSdkDisabled];

        resolve(@(!isDisabled));
    } @catch (NSException *exception) {
        reject(@"STATUS_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(getAppstackId:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Call the Swift bridge method directly
        NSString *appstackId = [AppstackBridge getAppstackId];

        resolve(appstackId);
    } @catch (NSException *exception) {
        reject(@"GET_APPSTACK_ID_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(isSdkDisabled:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Call the Swift bridge method directly
        BOOL isDisabled = [AppstackBridge isSdkDisabled];

        resolve(@(isDisabled));
    } @catch (NSException *exception) {
        reject(@"STATUS_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(getAttributionParams:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        [AppstackBridge getAttributionParamsWithCompletion:^(NSDictionary * _Nullable params, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error != nil) {
                    reject(@"ATTRIBUTION_PARAMS_ERROR", error.localizedDescription, error);
                    return;
                }

                NSDictionary *safeParams = params ?: @{};
                resolve(safeParams);
            });
        }];
    } @catch (NSException *exception) {
        reject(@"ATTRIBUTION_PARAMS_ERROR", exception.reason, nil);
    }
}

#pragma mark - TurboModule

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeAppstackReactNativeSpecJSI>(params);
}
#endif

@end
