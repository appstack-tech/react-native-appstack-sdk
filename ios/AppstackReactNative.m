#import "AppstackReactNative.h"
#import <AppstackSDK/AppstackSDK-Swift.h>

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
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (!apiKey || [apiKey length] == 0) {
        reject(@"INVALID_API_KEY", @"API key cannot be null or empty", nil);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [Appstack.shared configure:apiKey];
            resolve(@(YES));
        } @catch (NSException *exception) {
            reject(@"CONFIGURATION_ERROR", exception.reason, nil);
        }
    });
}

#pragma mark - Event Tracking

RCT_EXPORT_METHOD(sendEvent:(NSString *)eventName
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (!eventName || [eventName length] == 0) {
        reject(@"INVALID_EVENT_NAME", @"Event name cannot be null or empty", nil);
        return;
    }
    
    @try {
        [Appstack.shared sendEventWithEvent:eventName];
        resolve(@(YES));
    } @catch (NSException *exception) {
        reject(@"EVENT_SEND_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(sendEventWithRevenue:(NSString *)eventName
                 revenue:(id)revenue
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (!eventName || [eventName length] == 0) {
        reject(@"INVALID_EVENT_NAME", @"Event name cannot be null or empty", nil);
        return;
    }
    
    if (!revenue) {
        reject(@"INVALID_REVENUE", @"Revenue cannot be null", nil);
        return;
    }
    
    @try {
        [Appstack.shared sendEventWithEvent:eventName revenue:revenue];
        resolve(@(YES));
    } @catch (NSException *exception) {
        reject(@"EVENT_SEND_ERROR", exception.reason, nil);
    }
}

#pragma mark - Apple Search Ads Attribution

RCT_EXPORT_METHOD(enableASAAttribution:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 14.3, *)) {
        @try {
            [AppstackASAAttribution.shared enableASAAttributionTracking];
            resolve(@(YES));
        } @catch (NSException *exception) {
            reject(@"ASA_ATTRIBUTION_ERROR", exception.reason, nil);
        }
    } else {
        reject(@"UNSUPPORTED_IOS_VERSION", @"ASA Attribution requires iOS 14.3 or later", nil);
    }
}

@end