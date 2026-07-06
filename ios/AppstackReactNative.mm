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
    if (!apiKey || [apiKey length] == 0) {
        reject(@"INVALID_API_KEY", @"API key cannot be null or empty", nil);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Call the Swift bridge method directly
            [AppstackBridge configureWithApiKey:apiKey isDebug:isDebug endpointBaseUrl:endpointBaseUrl logLevel:logLevel customerUserId:customerUserId];

            resolve(@(YES));
        } @catch (NSException *exception) {
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
        if (parameters != nil && parameters != [NSNull null]) {
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                parametersDict = (NSDictionary *)parameters;
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
                 rejecter:(RCTPromiseRejectBlock)reject)
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
                 rejecter:(RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(getAppstackId:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
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
                 rejecter:(RCTPromiseRejectBlock)reject)
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
                 rejecter:(RCTPromiseRejectBlock)reject)
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

@end
