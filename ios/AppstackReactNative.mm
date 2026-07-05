#import "AppstackReactNative.h"
#import "AppstackBridge.h"

@implementation AppstackReactNative

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[];
}

#pragma mark - SDK Configuration

RCT_EXPORT_METHOD(configure:(NSString *)apiKey
                 isDebug:(BOOL)isDebug
                 endpointBaseUrl:(NSString * _Nullable)endpointBaseUrl
                 logLevel:(NSInteger)logLevel
                 customerUserId:(NSString * _Nullable)customerUserId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] configure called with apiKey: %@, isDebug: %@, endpointBaseUrl: %@, logLevel: %ld, customerUserId: %@", apiKey, isDebug ? @"YES" : @"NO", endpointBaseUrl ?: @"nil", (long)logLevel, customerUserId ?: @"nil");
    
    if (!apiKey || [apiKey length] == 0) {
        NSLog(@"[AppstackReactNative] configure failed: Invalid API key");
        reject(@"INVALID_API_KEY", @"API key cannot be null or empty", nil);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Call the Swift bridge method directly
            [AppstackBridge configureWithApiKey:apiKey isDebug:isDebug endpointBaseUrl:endpointBaseUrl logLevel:logLevel customerUserId:customerUserId];

            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] configure failed with exception: %@", exception.reason);
            reject(@"CONFIGURATION_ERROR", exception.reason, nil);
        }
    });
}

#pragma mark - Event Tracking

RCT_EXPORT_METHOD(sendEvent:(NSString *)eventType
                 eventName:(NSString *)eventName
                 parameters:(id _Nullable)parameters
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] sendEvent called with eventType: %@, eventName: %@, parameters: %@", eventType, eventName, parameters);
    
    // At least one of eventName or eventType should be provided
    if ((!eventName || [eventName length] == 0) && (!eventType || [eventType length] == 0)) {
        NSLog(@"[AppstackReactNative] sendEvent failed: Both eventName and eventType are empty");
        reject(@"INVALID_EVENT_NAME", @"Either eventName or eventType must be provided", nil);
        return;
    }
    
    // If eventType is CUSTOM, eventName is required
    if (eventType && [eventType length] > 0 && [eventType.uppercaseString isEqualToString:@"CUSTOM"]) {
        if (!eventName || [eventName length] == 0) {
            NSLog(@"[AppstackReactNative] sendEvent failed: eventName is required when eventType is CUSTOM");
            reject(@"INVALID_EVENT_NAME", @"eventName is required when eventType is CUSTOM", nil);
            return;
        }
    }
    
    @try {
        // Convert parameters: handle NSNull by converting to nil
        NSDictionary *parametersDict = nil;
        if (parameters != nil && parameters != [NSNull null]) {
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                parametersDict = (NSDictionary *)parameters;
            } else {
                NSLog(@"[AppstackReactNative] Warning: parameters is not a dictionary, ignoring");
            }
        }
        
        // Call the Swift bridge method directly with parameters
        [AppstackBridge sendEvent:eventType eventName:eventName parameters:parametersDict];

        resolve(@(YES));
    } @catch (NSException *exception) {
        NSLog(@"[AppstackReactNative] sendEvent failed with exception: %@", exception.reason);
        reject(@"EVENT_SEND_ERROR", exception.reason, nil);
    }
}

#pragma mark - Apple Search Ads Attribution

RCT_EXPORT_METHOD(enableAppleAdsAttribution:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 15.0, *)) {
        @try {
            // Call the Swift bridge method directly
            [AppstackBridge enableAppleAdsAttribution];

            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] enableAppleAdsAttribution failed with exception: %@", exception.reason);
            reject(@"ASA_ATTRIBUTION_ERROR", exception.reason, nil);
        }
    } else {
        NSLog(@"[AppstackReactNative] ERROR: iOS version < 15.0, Apple Ads Attribution not supported");
        reject(@"UNSUPPORTED_IOS_VERSION", @"Apple Ads Attribution requires iOS 15.0 or later", nil);
    }
}

#pragma mark - Additional SDK Methods

RCT_EXPORT_METHOD(disableASAAttributionTracking:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 15.0, *)) {
        @try {
            // Call the Swift bridge method directly
            [AppstackBridge disableASAAttributionTracking];

            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] disableASAAttributionTracking failed with exception: %@", exception.reason);
            reject(@"ASA_DISABLE_ERROR", exception.reason, nil);
        }
    } else {
        NSLog(@"[AppstackReactNative] ERROR: iOS version < 15.0, Apple Ads Attribution not supported");
        reject(@"UNSUPPORTED_IOS_VERSION", @"Apple Ads Attribution requires iOS 15.0 or later", nil);
    }
}

RCT_EXPORT_METHOD(getAppstackId:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Call the Swift bridge method directly
        NSString *appstackId = [AppstackBridge getAppstackId];

        NSLog(@"[AppstackReactNative] getAppstackId method called successfully via bridge, ID: %@", appstackId);

        resolve(appstackId);
    } @catch (NSException *exception) {
        NSLog(@"[AppstackReactNative] getAppstackId failed with exception: %@", exception.reason);
        reject(@"GET_APPSTACK_ID_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(isSdkDisabled:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Call the Swift bridge method directly
        BOOL isDisabled = [AppstackBridge isSdkDisabled];

        resolve(@(isDisabled));
    } @catch (NSException *exception) {
        NSLog(@"[AppstackReactNative] isDisabled failed with exception: %@", exception.reason);
        reject(@"STATUS_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(getAttributionParams:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [AppstackBridge getAttributionParamsWithCompletion:^(NSDictionary * _Nullable params, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error != nil) {
                    NSLog(@"[AppstackReactNative] getAttributionParams failed with error: %@", error.localizedDescription);
                    reject(@"ATTRIBUTION_PARAMS_ERROR", error.localizedDescription, error);
                    return;
                }

                NSDictionary *safeParams = params ?: @{};
                NSLog(@"[AppstackReactNative] getAttributionParams completed successfully via bridge, params: %@", safeParams);
                resolve(safeParams);
            });
        }];
    } @catch (NSException *exception) {
        NSLog(@"[AppstackReactNative] getAttributionParams failed with exception: %@", exception.reason);
        reject(@"ATTRIBUTION_PARAMS_ERROR", exception.reason, nil);
    }
}

@end
